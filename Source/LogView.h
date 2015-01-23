//
//  LogView.h
//  Build Spork
//
//  Created by Ricci Adams on 2015-01-22.
//  Copyright (c) 2015 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OutputParserLine;

typedef NS_ENUM(NSInteger, LogViewMessageType) {
    LogViewMessageTypeDefault  = 0,
    LogViewMessageTypeError    = 1,
    LogViewMessageTypeInternal = 2
};

@protocol LogViewDelegate;


@interface LogView : NSView

- (void) reset;
- (void) appendMark;

- (void) appendMessage:(NSString *)message type:(LogViewMessageType)type;

- (void) appendIssueWithPath: (NSString *) filePath
                  lineNumber: (NSInteger) lineNumber
                 issueString: (NSString *) issueString;

@property (weak) id<LogViewDelegate> delegate;

@property (strong) NSFont  *font;
@property (strong) NSColor *foregroundColor;
@property (strong) NSColor *backgroundColor;
@property (strong) NSColor *errorColor;
@property (strong) NSColor *linkColor;

@end


@protocol LogViewDelegate <NSObject>
- (void) logView:(LogView *)logView clickedOnFileURL:(NSURL *)fileURL line:(NSInteger)lineNumber;
@end