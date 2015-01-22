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

#import "AppDelegate.h"

#import "Preferences.h"

#import "ViewerWindowController.h"
#import "ProjectsWindowController.h"
#import "PreferencesWindowController.h"


@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *statusBarMenu;
@end


@implementation AppDelegate {
    NSStatusItem *_statusItem;

    ViewerWindowController      *_viewerWindowController;
    PreferencesWindowController *_preferencesWindowController;
    ProjectsWindowController    *_projectsWindowController;
}


- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self _updateDockAndMenuBar];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];

    if ([[Preferences sharedInstance] iconMode] == IconModeDock) {
        [self showViewer:self];
    }
}


- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows
{
    if (!hasVisibleWindows) {
        [self showViewer:self];
    }

    return YES;
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    [self _updateDockAndMenuBar];
}


- (void) _updateDockAndMenuBar
{
    IconMode iconMode = [[Preferences sharedInstance] iconMode];

    NSApplicationActivationPolicy currentActivationPolicy = [NSApp activationPolicy];

    if (iconMode == IconModeDock) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    // We are moving from NSApplicationActivationPolicyRegular -> NSApplicationActivationPolicyAccessory
    // This will hide windows, so do an elaborate workaround
    } else if (currentActivationPolicy != NSApplicationActivationPolicyAccessory) {
        BOOL wasActive = [NSApp isActive];
        
        NSMutableArray *visibleWindows = [NSMutableArray array];
        NSWindow *keyWindow = nil;

        for (NSWindow *window in [NSApp windows]) {
            if ([window isVisible]) {
                [visibleWindows addObject:window];
            }
            if ([window isKeyWindow]) {
                keyWindow = window;
            }
        }
        
        NSDisableScreenUpdates();
        
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (wasActive) [NSApp activateIgnoringOtherApps:YES];

            for (NSWindow *window in visibleWindows) {
                [window orderFront:self];
            }

            [keyWindow makeKeyAndOrderFront:self];

            NSEnableScreenUpdates();
        });
    }

    if (iconMode == IconModeMenuBar) {
        if (!_statusItem) {
            _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:33.0];

            NSImage *image = [NSImage imageNamed:@"StatusBarIcon"];
            [image setTemplate:YES];

            [_statusItem setImage:image];
            [_statusItem setHighlightMode:YES];
            [_statusItem setMenu:[self statusBarMenu]];
        }
    } else {
        if (_statusItem) {
            [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
            _statusItem = nil;
        }
    }
}


- (IBAction) showViewer:(id)sender
{
    if (!_viewerWindowController) {
        _viewerWindowController = [[ViewerWindowController alloc] init];
    }

    [_viewerWindowController showWindow:self];
}


- (IBAction) showPreferences:(id)sender
{
    if (!_preferencesWindowController) {
        _preferencesWindowController = [[PreferencesWindowController alloc] init];
    }

    [_preferencesWindowController showWindow:self];
}


- (IBAction) showProjects:(id)sender
{
    if (!_projectsWindowController) {
        _projectsWindowController = [[ProjectsWindowController alloc] init];
    }

    [_projectsWindowController showWindow:self];
}


@end
