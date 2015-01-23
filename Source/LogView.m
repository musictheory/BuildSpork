//
//  LogView.m
//  Build Spork
//
//  Created by Ricci Adams on 2015-01-22.
//  Copyright (c) 2015 Ricci Adams. All rights reserved.
//

#import "LogView.h"
#import "OutputParser.h"

@implementation LogView {
    NSScrollView *_scrollView;
    NSTextView   *_textView;
    
    NSMutableDictionary *_urlToIssueMap;
}

@import WebKit;

- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        _scrollView = [[NSScrollView alloc] initWithFrame:[self bounds]];
        [_scrollView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
        [_scrollView setBorderType:NSNoBorder];
        [_scrollView setHasVerticalScroller:YES];

        _textView = [[NSTextView alloc] initWithFrame:[_scrollView bounds]];
        [_scrollView setDocumentView:_textView];
        
        [self addSubview:_scrollView];
    }

    return self;
}


- (void) reset
{
    [_textView setString:@""];
    _urlToIssueMap = nil;
}


- (void) appendMark
{

}



- (void) appendMessage:(NSString *)message type:(LogViewMessageType)type
{
    NSColor *color = _foregroundColor;

    if (type == LogViewMessageTypeInternal) {
        color = [color colorWithAlphaComponent:0.5];
    } else if (type == LogViewMessageTypeError) {
        color = _errorColor;
    }

    message = [message stringByAppendingString:@"\n"];

    NSAttributedString *as = [[NSAttributedString alloc] initWithString:message attributes:@{
        NSForegroundColorAttributeName: color
    }];
    
    [[_textView textStorage] appendAttributedString:as];
    [_textView scrollRangeToVisible:NSMakeRange([[_textView string] length], 0)];
}

- (void) appendIssueWithPath: (NSString *) filePath
                  lineNumber: (NSInteger) lineNumber
                 issueString: (NSString *) issueString
{
    if (!_urlToIssueMap) {
        _urlToIssueMap = [NSMutableDictionary dictionary];
    }

    NSURL *link = [NSURL URLWithString:[NSString stringWithFormat:@"issue://%ld", [_urlToIssueMap count]]];

    NSString *linkText = [NSString stringWithFormat:@"%@:%ld", [filePath lastPathComponent], (long)lineNumber];

    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] init];
    
    [as appendAttributedString:[[NSAttributedString alloc] initWithString:linkText attributes:@{
        NSForegroundColorAttributeName: _linkColor ? _linkColor : [NSColor blueColor],
        NSLinkAttributeName: link,
        NSUnderlineColorAttributeName: [NSColor clearColor]
    }]];

    issueString = [NSString stringWithFormat:@" %@\n", issueString];

    [as appendAttributedString:[[NSAttributedString alloc] initWithString:issueString attributes:@{
        NSForegroundColorAttributeName: [NSColor blackColor],
    }]];

    [[_textView textStorage] appendAttributedString:as];
    [_textView scrollRangeToVisible:NSMakeRange([[_textView string] length], 0)];
}


- (BOOL) textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
    OutputParserIssueLine *issue = [_urlToIssueMap objectForKey:link];
    
//    [_delegate logView:self clickedOnFileURL:[_urlToIssueMap] line:(NSInteger)
//    NSLog(@"%@ %ld", [issue path], (long) [issue lineNumber]);
    
    return YES;
}

@end
