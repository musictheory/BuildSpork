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


#import "LogView.h"
#import "Preferences.h"

@import WebKit;

@interface LogView () <WKNavigationDelegate>
@end


@implementation LogView {
    WKWebView *_webView;
    NSMutableDictionary *_issueMap;
    BOOL _didLoad;
}


- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        WKPreferences          *preferences   = [[WKPreferences alloc] init];
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        
        [preferences setJavaEnabled:NO];
        [preferences setPlugInsEnabled:NO];
        [preferences setJavaScriptEnabled:YES];
        [preferences setJavaScriptCanOpenWindowsAutomatically:NO];
        
        [configuration setPreferences:preferences];
    
        _webView = [[WKWebView alloc] initWithFrame:[self bounds] configuration:configuration];
        [_webView setAllowsMagnification:NO];
        [_webView setAllowsBackForwardNavigationGestures:NO];
        [_webView setNavigationDelegate:self];
        [_webView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
        [_webView setMenu:nil];
        
        NSString *viewerPath     = [[NSBundle mainBundle] pathForResource:@"viewer" ofType:@"html"];
        
        NSError  *error = nil;
        NSString *viewerContents = [NSString stringWithContentsOfFile:viewerPath encoding:NSUTF8StringEncoding error:&error];
        
        [_webView loadHTMLString:viewerContents baseURL:nil];
        [_webView setHidden:YES];
        [self addSubview:_webView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];
    }

    return self;
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    [self _updateConfiguration];
}


- (void) _call:(NSString *)functionName withArguments:(NSArray *)arguments
{
    NSMutableString *js = [NSMutableString string];
    
    [js appendFormat:@"%@(", functionName];

    NSInteger index = 0;
    for (id argument in arguments) {
        if ([argument isKindOfClass:[NSNumber class]]) {
            [js appendFormat:@"%s'%@'", (index > 0) ? "," : "", argument];

        } else {
            NSMutableString *escaped;

            escaped = [NSMutableString stringWithString:argument];
            [escaped replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, [escaped length])];
            [escaped replaceOccurrencesOfString:@"\'" withString:@"\\\'" options:0 range:NSMakeRange(0, [escaped length])];

            [js appendFormat:@"%s'%@'", (index > 0) ? "," : "", escaped];
        }

    
        index++;
    }

    [js appendFormat:@")"];

    [_webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        [_webView setHidden:NO];
    }];
}


- (void) _updateConfiguration
{
    Preferences *preferences = [Preferences sharedInstance];

    NSFont   *font       = [preferences font];
    NSString *fontString = font ? [NSString stringWithFormat:@"%gpx '%@'", [font pointSize], [font familyName]] : @"12px sans";

    NSString *foregroundString = GetStringForColor([preferences foregroundColor]);
    NSString *backgroundString = GetStringForColor([preferences backgroundColor]);
    NSString *errorString      = GetStringForColor([preferences errorColor]);
    NSString *linkString       = GetStringForColor([preferences linkColor]);

    if (!foregroundString) foregroundString = @"#000";
    if (!backgroundString) foregroundString = @"#fff";
    if (!errorString)      errorString      = @"#f00";
    if (!linkString)       linkString       = @"#00f";
    
    [self _call:@"sporkConfig" withArguments:@[
        fontString,
        foregroundString,
        backgroundString,
        errorString,
        linkString
    ]];
}


- (void) reset
{
    [self _call:@"sporkReset" withArguments:@[ ]];
    _issueMap = nil;
}


- (void) appendMark
{
    [self _call:@"sporkMark" withArguments:@[ ]];
}



- (void) appendMessage:(NSString *)message type:(LogViewMessageType)type
{
    NSString *typeString = @"stdout";
    if (type == LogViewMessageTypeInternal) {
        typeString = @"internal";
    } else if (type == LogViewMessageTypeInfo) {
        typeString = @"info";
    } else if (type == LogViewMessageTypeFromErrorStream) {
        typeString = @"stderr";
    }

    [self _call:@"sporkMessage" withArguments:@[ message, typeString ]];
}


- (void) appendIssueWithPath: (NSString *) filePath
                  lineNumber: (NSInteger) lineNumber
                 issueString: (NSString *) issueString
{
    if (!_issueMap) {
        _issueMap = [NSMutableDictionary dictionary];
    }

    NSInteger issue = [_issueMap count];
    [_issueMap setObject:@[ filePath, @(lineNumber)] forKey:@(issue)];
    
    if (!issueString) issueString = @"";

    [self _call:@"sporkIssue" withArguments:@[ @( issue ), [filePath lastPathComponent], @(lineNumber), issueString ]];
}


- (void) webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
{
    NSURL *URL = [[navigationAction request] URL];

    if ([[URL scheme] isEqualToString:@"issue"]) {
        NSArray  *issue      =  [_issueMap objectForKey:@( [[URL host] integerValue] )];
        NSString *filePath   =  [issue objectAtIndex:0];
        NSInteger lineNumber = [[issue objectAtIndex:1] integerValue];

        [_delegate logView:self clickedOnIssueWithPath:filePath line:lineNumber];
    }

    if (_didLoad) {
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}


- (void) webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self _updateConfiguration];
    _didLoad = YES;
}


@end
