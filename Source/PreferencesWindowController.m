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

#import "PreferencesWindowController.h"

#import "Preferences.h"
#import "FontPreviewField.h"


@interface PreferencesWindowController () <FontPreviewFieldDelegate>

- (IBAction) selectFont:(id)sender;

@property (nonatomic, weak) Preferences *preferences;
@property (weak) IBOutlet FontPreviewField *fontPreviewField;

@end


@implementation PreferencesWindowController

- (id) initWithWindow:(NSWindow *)window
{
    if ((self = [super initWithWindow:window])) {
        [self setPreferences:[Preferences sharedInstance]];
    }
    
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *) windowNibName
{
    return @"PreferencesWindow";
}


- (void ) windowDidLoad
{
    [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
    [_fontPreviewField setFont:[[Preferences sharedInstance] font]];
    [_fontPreviewField setPreviewDelegate:self];
}


- (IBAction) selectFont:(id)sender
{
    [[self fontPreviewField] showFontPanel];
}


- (void) fontPreviewField:(FontPreviewField *)field didChangeSelectedFont:(NSFont *)selectedFont
{
    [[Preferences sharedInstance] setFont:selectedFont];
}


@end
