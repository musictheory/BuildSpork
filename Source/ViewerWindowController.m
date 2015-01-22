/*
    Copyright (c) 2015, Ricci Adams

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following condition is met:

    1. Redistributions of source code must retain the above copyright notice, this
       list of conditions and the following disclaimer. 

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "ViewerWindowController.h"

#import "AppDelegate.h"
#import "LightView.h"
#import "Project.h"
#import "ProjectManager.h"
#import "OutputParser.h"
#import "TaskRun.h"
#import "Preferences.h"

@import WebKit;

static NSInteger ShowProjectsTag = -1000;
static NSString * const sSelectedProjectUUID = @"SelectedProjectUUID";

@interface ViewerWindowController () <NSToolbarDelegate, TaskRunDelegate>
@property (weak)   IBOutlet NSToolbar  *toolbar;
@property (strong) IBOutlet NSTextView *textView;
@end


@implementation ViewerWindowController {
    Project       *_selectedProject;

    NSToolbarItem *_projectToolbarItem;
    NSToolbarItem *_targetToolbarItem;
    NSToolbarItem *_buildToolbarItem;
    NSArray       *_actionToolbarItems;
    NSArray       *_lightToolbarItems;

    NSPopUpButton *_projectPopUpButton;
    NSPopUpButton *_targetPopUpButton;
    
    NSMutableDictionary *_identifierToItemMap;
    NSMutableDictionary *_nameToLightViewMap;
    
    TaskRun      *_currentRun;
    OutputParser *_outputParser;
    
    NSMutableArray      *_outputLines;
    NSMutableDictionary *_urlToIssueMap;
}


- (NSString *) windowNibName
{
    return @"ViewerWindow";
}


- (void) awakeFromNib
{
    NSWindow *window = [self window];

    [window setTitleVisibility:NSWindowTitleHidden];
    [[self toolbar] setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [[self toolbar] setSizeMode:NSToolbarSizeModeRegular];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleProjectDidUpdateConfiguration:)   name:ProjectDidUpdateConfigurationNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:)            name:PreferencesDidChangeNotification          object:nil];

    [[ProjectManager sharedInstance] addObserver:self forKeyPath:@"projects" options:0 context:NULL];
    
    NSString *UUIDString = [[NSUserDefaults standardUserDefaults] stringForKey:sSelectedProjectUUID];
    if (UUIDString) {
        NSUUID *UUID = [[NSUUID alloc] initWithUUIDString:UUIDString];
        _selectedProject = [[ProjectManager sharedInstance] projectWithUUID:UUID];
    }
    
    [self _updateProjectsItem];
    [self _rebuildTextView];
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Private Methods

- (void) _rebuildTextView
{
    NSColor *backgroundColor = [[Preferences sharedInstance] backgroundColor];

    [[self textView] setBackgroundColor:backgroundColor];
    
    if (IsDarkColor(backgroundColor)) {
        [[self window] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    } else {
        [[self window] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    }

    NSArray *outputLines = _outputLines;
    _urlToIssueMap = [NSMutableDictionary dictionary];
    _outputLines   = [NSMutableArray array];

    for (OutputParserLine *line in outputLines) {
        [self _appendOutputLine:line];
    }
}


- (void) _rebuildToolbar
{
    NSToolbar *toolbar = [self toolbar];

    // Generate our identifierToItemMap
    {
        NSMutableDictionary *identifierToItemMap = [NSMutableDictionary dictionary];

        void (^addItem)(NSToolbarItem *) = ^(NSToolbarItem *item) {
            NSString *identifier = [item itemIdentifier];
            if (!identifier) return;
            
            [identifierToItemMap setObject:item forKey:identifier];
        };

        addItem(_projectToolbarItem);
        addItem(_targetToolbarItem);
        addItem(_buildToolbarItem);

        for (NSToolbarItem *item in _actionToolbarItems) {
            addItem(item);
        }

        for (NSToolbarItem *item in _lightToolbarItems) {
            addItem(item);
        }

        addItem( [[NSToolbarItem alloc] initWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier] );
        
        _identifierToItemMap = identifierToItemMap;
    }


    // Now actually update the toolbar
    {
        __block NSInteger index = 0;
        void (^addItemWithIdentifier)(NSString *) = ^(NSString *identifier) {
            if (!identifier) return;
            [toolbar insertItemWithItemIdentifier:identifier atIndex:index];
            index++;
        };

        // Remove all toolbar items
        while ([[toolbar items] count]) {
            [toolbar removeItemAtIndex:0];
        }

        addItemWithIdentifier([_projectToolbarItem itemIdentifier]);
        addItemWithIdentifier([_targetToolbarItem  itemIdentifier]);
        addItemWithIdentifier([_buildToolbarItem   itemIdentifier]);

        for (NSToolbarItem *item in _actionToolbarItems) {
            addItemWithIdentifier([item itemIdentifier]);
        }

        [toolbar insertItemWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier atIndex:index++];

        for (NSToolbarItem *item in _lightToolbarItems) {
            addItemWithIdentifier([item itemIdentifier]);
        }
    }
    
    [toolbar validateVisibleItems];
}


- (void) _updateProjectsItem
{
    NSMutableArray *names = [NSMutableArray array];
    NSArray *projects = [[ProjectManager sharedInstance] projects];

    if ([projects count]) {
        for (Project *project in [[ProjectManager sharedInstance] projects]) {
            [names addObject:[project name]];
        }
    }

    NSPopUpButton *popUpButton = [self _makePopUpButtonWithTitles:names];
    
    [popUpButton setTarget:self];
    [popUpButton setAction:@selector(_handleProjectPopUpButton:)];

    [[popUpButton menu] addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *showProjects = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Projects", nil) action:nil keyEquivalent:@""];
    [showProjects setTag:ShowProjectsTag];
    [[popUpButton menu] addItem:showProjects];

    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:@"project"];
    [toolbarItem setView:popUpButton];
    
    _projectPopUpButton = popUpButton;
    _projectToolbarItem = toolbarItem;
    
    if (_selectedProject) {
        [_projectPopUpButton selectItemWithTitle:[_selectedProject name]];
    }
    
    [self _rebuildToolbar];
}


- (NSPopUpButton *) _makePopUpButtonWithTitles:(NSArray *)titles
{
    NSPopUpButton *result = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 160, 22) pullsDown:NO];
    
    [result setBezelStyle:NSTexturedRoundedBezelStyle];
    
    NSInteger index = 0;
    for (NSString *title in titles) {
        NSMenuItem *item = nil;

        if ([title isEqualToString:@"-"]) {
            item = [NSMenuItem separatorItem];
        } else {
            item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
            [item setTag:index];
            index++;
        }
        
        [[result menu] addItem:item];
    }
    
    [result sizeToFit];
    
    return result;
}


- (void) _selectProject:(Project *)project
{
    if ([[project targets] count]) {

        // Target popup item
        {
            NSInteger selectedTag = [_targetPopUpButton selectedTag];
        
            NSPopUpButton *targetPopUp = [self _makePopUpButtonWithTitles:Map([project targets], ^(ProjectTarget *item) {
                return [item title];
            })];
            
            _targetPopUpButton = targetPopUp;
            [_targetPopUpButton selectItemWithTag:selectedTag];
        
            NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:@"target"];
            [toolbarItem setView:_targetPopUpButton];

            _targetToolbarItem = toolbarItem;
        }

        // Build button
        {
            NSButton *buildButton = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 32, 22)];
            
            [buildButton setTarget:self];
            [buildButton setAction:@selector(_handleBuildButton:)];
            [buildButton setBezelStyle:NSTexturedRoundedBezelStyle];
            [buildButton setTitle:NSLocalizedString(@"Build", nil)];

            [buildButton sizeToFit];

            NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:@"build"];
            [toolbarItem setView:buildButton];
            
            _buildToolbarItem = toolbarItem;
        }

    } else {
        _targetPopUpButton = nil;
        _targetToolbarItem = nil;
        _buildToolbarItem  = nil;
    }
    

    // Build Action items
    {
        NSMutableArray *actionToolbarItems = [NSMutableArray array];

        NSInteger index = 0;

        for (ProjectAction *action in [project actions]) {
            NSButton *actionButton = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 32, 22)];
            
            [actionButton setTarget:self];
            [actionButton setAction:@selector(_handleActionButton:)];
            [actionButton setTag:index];
            [actionButton setBezelStyle:NSTexturedRoundedBezelStyle];
            [actionButton setTitle:[action title]];
            [actionButton setToolTip:[action tooltip]];

            [actionButton sizeToFit];
    
            NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:[NSString stringWithFormat:@"action-%ld", (long)index]];
            [toolbarItem setView:actionButton];
            [toolbarItem setLabel:[action title]];
            [toolbarItem setToolTip:[action tooltip]];
            
            [actionToolbarItems addObject:toolbarItem];

            index++;
        }

        _actionToolbarItems = actionToolbarItems;
    }


    // Build Light items
    {
        NSMutableArray      *lightToolbarItems  = [NSMutableArray array];
        NSMutableDictionary *nameToLightViewMap = [NSMutableDictionary dictionary];

        NSInteger index = 0;

        for (ProjectLight *light in [project lights]) {
            if (![light name]) continue;

            LightView *lightView = [[LightView alloc] initWithFrame:NSMakeRect(0, 0, 22, 22)];
            [lightView setToolTip:[light tooltip]];

            [nameToLightViewMap setObject:lightView forKey:[light name]];

            NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:[NSString stringWithFormat:@"light-%ld", (long)index]];
            [toolbarItem setView:lightView];
            [toolbarItem setLabel:[light title]];
            [toolbarItem setToolTip:[light tooltip]];
            
            [lightToolbarItems addObject:toolbarItem];

            index++;
        }

        _lightToolbarItems = lightToolbarItems;
        _nameToLightViewMap = nameToLightViewMap;
    }

    _selectedProject = project;

    NSString *UUIDString = [[project UUID] UUIDString];
    if (UUIDString) {
        [[NSUserDefaults standardUserDefaults] setObject:UUIDString forKey:sSelectedProjectUUID];
    }

    [self _rebuildToolbar];
}


- (void) _runCommand:(NSString *)command
{
    if (_currentRun) {
        [_currentRun setDelegate:nil];
        [_currentRun stop];
    }
 
    _currentRun = [[TaskRun alloc] initWithCommand:command project:_selectedProject];
    [_currentRun setDelegate:self];
    [_currentRun start];
}



#pragma mark - Actions

- (void) _handleProjectPopUpButton:(id)sender
{
    if (sender == _projectPopUpButton) {
        NSInteger selectedTag = [sender selectedTag];
        
        if (selectedTag == ShowProjectsTag) {
            [(id)[NSApp delegate] showProjects:self];
        } else {
            NSArray *projects = [[ProjectManager sharedInstance] projects];
            
            if (selectedTag >= 0 && selectedTag < [projects count]) {
                [self _selectProject:[projects objectAtIndex:selectedTag]];
            }
        }
    }
}


- (void) _handleActionButton:(id)sender
{
    NSInteger index   = [sender tag];
    NSArray  *actions = [_selectedProject actions];
    
    if (index >= 0 && index < [actions count]) {
        ProjectAction *action = [actions objectAtIndex:index];
        [self _runCommand:[action command]];
    }
}


- (void) _handleBuildButton:(id)sender
{
    NSInteger index   = [_targetPopUpButton selectedTag];
    NSArray  *targets = [_selectedProject targets];
    
    if (index >= 0 && index < [targets count]) {
        ProjectTarget *target = [targets objectAtIndex:index];
        [self _runCommand:[target command]];
    }

}


#pragma mark - Output

- (void) _appendMark
{

}


- (void) _appendLink:(NSURL *)link file:(NSString *)file lineNumber:(NSInteger)lineNumber columnNumber:(NSInteger)columnNumber issueString:(NSString *)issueString
{
    NSString *linkText = [NSString stringWithFormat:@"%@:%ld", file, (long)lineNumber];

    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] init];
    
    [as appendAttributedString:[[NSAttributedString alloc] initWithString:linkText attributes:@{
        NSForegroundColorAttributeName: [NSColor blueColor],
        NSLinkAttributeName: link,
        NSUnderlineColorAttributeName: [NSColor clearColor]
    }]];

    issueString = [NSString stringWithFormat:@" %@\n", issueString];

    [as appendAttributedString:[[NSAttributedString alloc] initWithString:issueString attributes:@{
        NSForegroundColorAttributeName: [NSColor blackColor],
    }]];

    NSTextView    *textView    = [self textView];
    NSTextStorage *textStorage = [textView textStorage];

    [textStorage appendAttributedString:as];
    [textView scrollRangeToVisible:NSMakeRange([[textView string] length], 0)];
}


- (void) _appendString:(NSString *)line color:(NSColor *)color
{
    line = [line stringByAppendingString:@"\n"];

    NSAttributedString *as = [[NSAttributedString alloc] initWithString:line attributes:@{
        NSForegroundColorAttributeName: color
    }];
    
    NSTextView    *textView    = [self textView];
    NSTextStorage *textStorage = [textView textStorage];

    [textStorage appendAttributedString:as];
    [textView scrollRangeToVisible:NSMakeRange([[textView string] length], 0)];
}


- (void) _appendOutputLine:(OutputParserLine *)line
{
    OutputParserLineType type = [line type];

    void (^appendError)(NSString *, NSString *) = ^(NSString *prefix, NSString *content) {
        NSColor *color = [[[Preferences sharedInstance] foregroundColor] colorWithAlphaComponent:0.5];
        [self _appendString:[prefix stringByAppendingString:content] color:color];
    };
    
    if (type == OutputParserLineTypeReset) {
        [[self textView] setString:@""];

    } else if (type == OutputParserLineTypeMark) {
        [self _appendMark];

    } else if (type == OutputParserLineTypeFileIssue) {
        OutputParserIssueLine *issueLine = (OutputParserIssueLine *)line;
        
        NSURL *fileURL = [_selectedProject URLWithFilePath:[issueLine path]];
        
        if (fileURL) {
            NSInteger count   = [_urlToIssueMap count];
            NSURL    *linkURL = [NSURL URLWithString:[NSString stringWithFormat:@"issue://%ld", (long)count]];
            
            [_urlToIssueMap setObject:line forKey:linkURL];
            
            [self _appendLink: linkURL
                         file: [fileURL lastPathComponent]
                   lineNumber: [issueLine lineNumber]
                 columnNumber: [issueLine columnNumber]
                  issueString: [issueLine issueString]];

        } else {
            [self _appendString:[line string] color:[[Preferences sharedInstance] foregroundColor]];
        }
    
    } else if (type == OutputParserLineTypeLight) {
        OutputParserLightLine *lightLine = (OutputParserLightLine *)line;
      
        NSColor   *lightColor = [lightLine color];
        NSString  *lightName  = [lightLine lightName];
        LightView *lightView  = [_nameToLightViewMap objectForKey:lightName];
    
        if (lightView) {
            [lightView setColor:lightColor];
        } else {
            appendError(NSLocalizedString(@"Unknown light: ", nil), [line string]);
        }
    
    } else if (type == OutputParserLineTypeParseError) {
        appendError(NSLocalizedString(@"Parse error: ", nil), [line string]);
    
    } else if (type == OutputParserLineTypeMessage) {
        [self _appendString:[line string] color:[[Preferences sharedInstance] foregroundColor]];

    } else if (type == OutputParserLineTypeError) {
        [self _appendString:[line string] color:[[Preferences sharedInstance] errorColor]];
    }
    
    [_outputLines addObject:line];
}



#pragma mark - Notifications

- (void) _handleProjectDidUpdateConfiguration:(NSNotification *)note
{
    if ([note object] == _selectedProject) {
        [self _selectProject:_selectedProject];
    }
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    [self _rebuildTextView];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == [ProjectManager sharedInstance]) {
        if ([keyPath isEqualToString:@"projects"]) {
            [self _updateProjectsItem];
        }
    }
}


#pragma mark - NSToolbar Delegate

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    return [_identifierToItemMap objectForKey:itemIdentifier];
}

    
- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    NSMutableArray *results = [NSMutableArray array];
    
    [results addObjectsFromArray:[_identifierToItemMap allKeys]];
    
    return results;
}


- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarDefaultItemIdentifiers:toolbar];
}



#pragma mark - TaskRun Delegate

- (void) taskRunStarted:(TaskRun *)taskRun
{
    _outputLines   = [NSMutableArray array];
    _urlToIssueMap = [NSMutableDictionary dictionary];
    
    OutputParserLine *reset = [[OutputParserLine alloc] init];
    [reset setType:OutputParserLineTypeReset];
    
    [self _appendOutputLine:reset];
}


- (void) taskRunStopped:(TaskRun *)taskRun
{

}


- (void) taskRun:(TaskRun *)taskRun receivedLineData:(NSData *)data fromStandardError:(BOOL)fromStandardError
{
    if (!_outputParser) {
        _outputParser = [[OutputParser alloc] init];
    }
    
    OutputParserLine    *line = [_outputParser lineForLineData:data];
    OutputParserLineType type = [line type];
    
    if (fromStandardError && (type == OutputParserLineTypeMessage)) {
        [line setType:OutputParserLineTypeError];
    }

    [self _appendOutputLine:line];
}



#pragma mark - Text View Delegate

- (BOOL) textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
    OutputParserIssueLine *issue = [_urlToIssueMap objectForKey:link];
    
    NSLog(@"%@ %ld", [issue path], (long) [issue lineNumber]);
    
    return YES;
}



@end
