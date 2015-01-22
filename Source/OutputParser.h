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

@import AppKit;


typedef NS_ENUM(NSInteger, OutputParserLineType) {
    OutputParserLineTypeReset,
    OutputParserLineTypeMark,
    OutputParserLineTypeMessage,
    OutputParserLineTypeError,
    OutputParserLineTypeParseError,
    OutputParserLineTypeLight,     // class = OutputParserLightLine
    OutputParserLineTypeFileIssue  // class = OutputParserFileIssueLine
};

@class OutputParserLine;

@interface OutputParser : NSObject
- (OutputParserLine *) lineForLineData:(NSData *)data;
@end


@interface OutputParserLine : NSObject
@property OutputParserLineType type;
@property NSString *string;
@end


@interface OutputParserLightLine : OutputParserLine
@property (readonly) NSString *lightName;
@property (readonly) NSColor  *color;
@end


@interface OutputParserIssueLine : OutputParserLine
@property (readonly) NSString  *path;
@property (readonly) NSInteger  lineNumber;
@property (readonly) NSInteger  columnNumber;   // May be NSNotFound
@property (readonly) NSString  *issueString;
@end
