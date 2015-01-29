/*
    Copyright (c) 2015, musictheory.net, LLC

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
#import "Event.h"
#import "LogView.h"
#import "Project.h"
#import "ProjectManager.h"
#import "OutputParser.h"
#import "TaskRun.h"
#import "Preferences.h"

static NSInteger ShowProjectsTag    = -1000;
static NSInteger ShowPreferencesTag = -1001;
static NSString * const sSelectedProjectUUID = @"SelectedProjectUUID";

@interface ViewerWindowController () <NSToolbarDelegate, TaskRunDelegate, LogViewDelegate>
@property (weak)   IBOutlet NSToolbar  *toolbar;
@property (strong) IBOutlet LogView *logView;
@end


@implementation ViewerWindowController {
    Project       *_selectedProject;

    NSToolbarItem *_projectToolbarItem;
    NSToolbarItem *_targetToolbarItem;
    NSToolbarItem *_buildToolbarItem;
    NSArray       *_actionToolbarItems;

    NSPopUpButton *_projectPopUpButton;
    NSPopUpButton *_targetPopUpButton;
    
    NSMutableDictionary *_identifierToItemMap;
    
    TaskRun      *_currentRun;
    OutputParser *_outputParser;
    
    BOOL _receivedInit;
    BOOL _shouldSendStop;
    NSTimeInterval _taskStartTime;
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
    
    [[self logView] setDelegate:self];
    
    [self _updateProjectsItem];
    [self _updateColors];
    
    [self _selectProject:_selectedProject];
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Private Methods

- (void) _updateColors
{
    Preferences *preferences = [Preferences sharedInstance];
    NSColor *backgroundColor = [preferences backgroundColor];
    
    if (IsDarkColor(backgroundColor)) {
        [[self window] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    } else {
        [[self window] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    }

    [[[self window] contentView] setBackgroundColor:backgroundColor];
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
    
    NSMenuItem *showProjects = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Projects\\U2026", nil) action:nil keyEquivalent:@""];
    [showProjects setTag:ShowProjectsTag];
    [[popUpButton menu] addItem:showProjects];
    
    if ([[Preferences sharedInstance] iconMode] == IconModeNone) {
        NSMenuItem *showPreferences = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Preferences\\U2026", nil) action:nil keyEquivalent:@""];
        [showPreferences setTag:ShowPreferencesTag];
        [[popUpButton menu] addItem:showPreferences];
    }

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
        }
        
        [[result menu] addItem:item];

        index++;
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


- (void) _dispatchEvent:(Event *)event
{
    NSString *type = [event type];

    void (^appendInternal)(NSString *, NSString *) = ^(NSString *prefix, NSString *content) {
        [_logView appendMessage:[event string] type:LogViewMessageTypeInternal];
    };
    
    if ([type isEqualToString:EventTypeReset]) {
        [_logView reset];

    } else if ([type isEqualToString:EventTypeMark]) {
        [_logView appendMark];

    } else if ([type isEqualToString:EventTypeIssue]) {
        IssueEvent *issueEvent = (IssueEvent *)event;
       
        [_logView appendIssueWithPath:[issueEvent path] lineNumber:[issueEvent lineNumber] issueString:[issueEvent issueString]];
    
    } else if ([type isEqualToString:EventTypeInternal]) {
        appendInternal(NSLocalizedString(@"Parse error: ", nil), [event string]);
    
    } else if ([type isEqualToString:EventTypeMessage]) {
        if ([event location] == EventLocationErrorStream) {
            [_logView appendMessage:[event string] type:LogViewMessageTypeFromErrorStream];
        } else {
            [_logView appendMessage:[event string] type:LogViewMessageTypeFromOutputStream];
        }

    } else if ([type isEqualToString:EventTypeInfo]) {
        [_logView appendMessage:[event string] type:LogViewMessageTypeInfo];

    } else if ([type isEqualToString:EventTypeInternal]) {
        [_logView appendMessage:[event string] type:LogViewMessageTypeInternal];
    }
    
    
    NSMutableDictionary *userInfo = [[event dictionaryRepresentation] mutableCopy];
    [userInfo setObject:[[_selectedProject URL] path] forKey:@"project"];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"net.musictheory.spork.event" object:nil userInfo:userInfo];
}


#pragma mark - Actions

- (void) _handleProjectPopUpButton:(id)sender
{
    if (sender == _projectPopUpButton) {
        NSInteger selectedTag = [sender selectedTag];
        
        if (selectedTag == ShowProjectsTag) {
            [(id)[NSApp delegate] showProjects:self];

        } else if (selectedTag == ShowPreferencesTag) {
            [(id)[NSApp delegate] showPreferences:self];

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


#pragma mark - Notifications

- (void) _handleProjectDidUpdateConfiguration:(NSNotification *)note
{
    if ([note object] == _selectedProject) {
        [self _selectProject:_selectedProject];
    }
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    [self _updateColors];
    [self _updateProjectsItem];
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
    _receivedInit   = NO;
    _shouldSendStop = NO;
    _taskStartTime = [NSDate timeIntervalSinceReferenceDate];
    [_logView reset];
}


- (void) taskRunStopped:(TaskRun *)taskRun
{
    if (_shouldSendStop) {
        Event *stopEvent = [[Event alloc] init];
        [stopEvent setType:EventTypeStop];
        [stopEvent setString:@"[spork] stop"];

        [self _dispatchEvent:stopEvent];

        NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - _taskStartTime;

        Event *infoEvent = [[Event alloc] init];
        [infoEvent setType:EventTypeInfo];
        [infoEvent setString:[NSString stringWithFormat:@"Task finished in %.1f seconds", elapsed]];

        [self _dispatchEvent:infoEvent];
    }
}


- (void) taskRun:(TaskRun *)taskRun receivedLineData:(NSData *)data fromStandardError:(BOOL)fromStandardError
{
    if (!_outputParser) {
        _outputParser = [[OutputParser alloc] init];
    }
    
    Event *event = [_outputParser eventForLineData:data project:_selectedProject fromStandardError:fromStandardError];
    NSString *type = [event type];
    
    if (!_receivedInit) {
        if ([type isEqualToString:EventTypeInit]) {
            _receivedInit = YES;

        } else {
            Event *initEvent  = [[Event alloc] init];
            Event *startEvent = [[Event alloc] init];
            
            [initEvent setType:EventTypeInit];
            [initEvent setString:@"[spork] init"];

            [startEvent setType:EventTypeStart];
            [startEvent setString:@"[spork] start"];

            [self _dispatchEvent:initEvent];
            [self _dispatchEvent:startEvent];

            _receivedInit   = YES;
            _shouldSendStop = YES;
        }
    }
    
    [self _dispatchEvent:event];
}


#pragma mark - Log View Delegate

- (void) logView:(LogView *)logView clickedOnIssueWithPath:(NSString *)path line:(NSInteger)lineNumber
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    
    NSString *lineString = [NSString stringWithFormat:@"%ld", (long)lineNumber];

    [userInfo setObject:[[_selectedProject URL] path] forKey:@"project"];
    [userInfo setObject:path       forKey:@"path"];
    [userInfo setObject:lineString forKey:@"line"];
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"net.musictheory.spork.open" object:nil userInfo:userInfo];
    
    // Sublime should activate itself, but I'm having problems doing that from within the plugin_host
    NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.sublimetext.3"];
    [[apps lastObject] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
}


@end
