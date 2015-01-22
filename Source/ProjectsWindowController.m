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

#import "ProjectsWindowController.h"

#import "Project.h"
#import "ProjectManager.h"


static NSString * const sProjectPasteboardType = @"com.iccir.BuildSpork.Project";


@interface ProjectsWindowController () <NSOpenSavePanelDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (weak) ProjectManager *projectManager;

// Top level nib objects
@property (strong) IBOutlet NSArrayController *arrayController;

@property (weak) IBOutlet NSTableView *tableView;

@end


@implementation ProjectsWindowController {
    Project  *_draggedProject;
    NSInteger _draggedRow;
}

- (NSString *) windowNibName
{
    return @"ProjectsWindow";
}


- (void) windowDidLoad
{
    [super windowDidLoad];
    
    [self setProjectManager:[ProjectManager sharedInstance]];

    [[self tableView] registerForDraggedTypes:@[ sProjectPasteboardType ] ];
}


- (IBAction) addProject:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    [openPanel setTitle:NSLocalizedString(@"Add Project", nil)];
    [openPanel setDelegate:self];

    [openPanel setCanChooseDirectories:YES];

    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanResolveUbiquitousConflicts:NO];
    [openPanel setCanDownloadUbiquitousContents:NO];
    
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            Project *project = [[Project alloc] initWithURL:[openPanel URL]];
            [[ProjectManager sharedInstance] addProject:project];
        }
    }];
}


- (IBAction) removeProject:(id)sender
{
    NSArrayController *arrayController = [self arrayController];
    NSArray *selectedObjects = [arrayController selectedObjects];

    if ([selectedObjects count]) {
        [[ProjectManager sharedInstance] removeProject:[selectedObjects lastObject]];
    }
}


- (BOOL) tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    [pboard setData:[NSData data] forType:sProjectPasteboardType];

    _draggedRow     = [rowIndexes firstIndex];
    _draggedProject = [[[ProjectManager sharedInstance] projects] objectAtIndex:_draggedRow];

    return YES;
}



- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    if (dropOperation == NSTableViewDropAbove) {
        if ((row == _draggedRow) || (row == (_draggedRow + 1))) {
            return NSDragOperationNone;
        } else {
            return NSDragOperationMove;
        }
    }

    return NSDragOperationNone;
}


- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
{
    NSPasteboard *pboard = [info draggingPasteboard];

    if ([pboard dataForType:sProjectPasteboardType]) {
        if (_draggedRow < row) {
            row--;
        }

        if (_draggedProject) {
            [[self tableView] beginUpdates];
            [[self tableView] moveRowAtIndex:_draggedRow toIndex:row];

            [[ProjectManager sharedInstance] removeProject:_draggedProject];
            [[ProjectManager sharedInstance] insertProject:_draggedProject atIndex:row];

            [[self tableView] endUpdates];
        }
    }

    return YES;
}



@end
