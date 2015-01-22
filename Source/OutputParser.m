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

#import "OutputParser.h"

@interface OutputParserLightLine ()
@property NSString *lightName;
@property NSColor  *color;
@end


@interface OutputParserIssueLine ()
@property NSString  *path;
@property NSInteger  lineNumber;
@property NSInteger  columnNumber;   // May be NSNotFound
@property NSString  *issueString;
@end


@implementation OutputParser {
    NSRegularExpression *_issueRegularExpression;
}


static BOOL sMatch(NSRegularExpression *re, NSString *string, void (^callback)(NSArray *))
{
    NSTextCheckingResult *result = [re firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    BOOL didFind = NO;

    NSInteger numberOfRanges = [result numberOfRanges];
    if ([result numberOfRanges] > 1) {
        NSMutableArray *captureGroups = [NSMutableArray array];
        
        NSInteger i;
        for (i = 1; i < numberOfRanges; i++) {
            NSRange captureRange = [result rangeAtIndex:i];
            
            if (captureRange.location != NSNotFound) {
                [captureGroups addObject:[string substringWithRange:captureRange]];
            } else {
                [captureGroups addObject:@""];
            }
        }
        
        callback(captureGroups);
        
        didFind = YES;
    }
    
    return didFind;
}


static NSColor *sGetColorFromParsedString(NSString *stringToParse)
{
    if (!stringToParse) return nil;

    __block NSColor *color = nil;

    float (^scanHex)(NSString *, float) = ^(NSString *string, float maxValue) {
        const char *s = [string UTF8String];
        float result = s ? (strtol(s, NULL, 16) / maxValue) : 0.0;
        return result;
    };

    void (^withPattern)(NSString *, void(^)(NSArray *)) = ^(NSString *pattern, void (^callback)(NSArray *result)) {
        if (color) return;

        NSRegularExpression  *re = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
        sMatch(re, stringToParse, callback);
    };

    withPattern(@"#([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})", ^(NSArray *result) {
        if ([result count] == 3) {
            color = [NSColor colorWithRed: scanHex([result objectAtIndex:0], 65535.0)
                                    green: scanHex([result objectAtIndex:1], 65535.0)
                                     blue: scanHex([result objectAtIndex:2], 65535.0)
                                    alpha: 1.0];
        }
    });
    
    withPattern(@"#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})", ^(NSArray *result) {
        if ([result count] == 3) {
            color = [NSColor colorWithRed: scanHex([result objectAtIndex:0], 255.0)
                                    green: scanHex([result objectAtIndex:1], 255.0)
                                     blue: scanHex([result objectAtIndex:2], 255.0)
                                    alpha: 1.0];
        }
    });

    withPattern(@"rgb\\s*\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)", ^(NSArray *result) {
        if ([result count] == 3) {
            color = [NSColor colorWithRed: ([[result objectAtIndex:0] floatValue] / 255.0)
                                    green: ([[result objectAtIndex:1] floatValue] / 255.0)
                                     blue: ([[result objectAtIndex:2] floatValue] / 255.0)
                                    alpha: 1.0];
        }
    });

    withPattern(@"rgba\\s*\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)", ^(NSArray *result) {
        if ([result count] == 4) {
            color = [NSColor colorWithRed: ([[result objectAtIndex:0] floatValue] / 255.0)
                                    green: ([[result objectAtIndex:1] floatValue] / 255.0)
                                     blue: ([[result objectAtIndex:2] floatValue] / 255.0)
                                    alpha:  [[result objectAtIndex:3] floatValue]];
        }
    });

    withPattern(@"([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})", ^(NSArray *result) {
        if ([result count] == 3) {
            color = [NSColor colorWithRed: scanHex([result objectAtIndex:0], 255.0)
                                    green: scanHex([result objectAtIndex:1], 255.0)
                                     blue: scanHex([result objectAtIndex:2], 255.0)
                                    alpha: 1.0];
        }
    });

    return color;
}



- (OutputParserLine *) lineForLineData:(NSData *)data
{
    const char *bytes  = [data bytes];
    NSInteger   length = [data length];
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    __block Class                cls          = [OutputParserLine class];
    __block OutputParserLineType type         = OutputParserLineTypeMessage;
    __block NSColor             *lightColor   = nil;
    __block NSString            *lightName    = nil;
    __block NSString            *path         = nil;
    __block NSInteger            lineNumber   = NSNotFound;
    __block NSInteger            columnNumber = NSNotFound;
    __block NSString            *issueString  = nil;

    size_t sporkSize = strlen("[spork]");

    if ((length > sporkSize) && memcmp(bytes, "[spork]", sporkSize) == 0) {
        NSArray        *components = [string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableArray *words      = [NSMutableArray array];
        
        for (NSString *component in components) {
            if ([component length]) {
                [words addObject:component];
            }
        }
        
        NSInteger count   = [words count];
        NSString *command = count > 1 ? [words objectAtIndex:1] : nil;
        
        if ([command isEqualToString:@"reset"]) {
            type = OutputParserLineTypeReset;
        
        } else if ([command isEqualToString:@"mark"]) {
            type = OutputParserLineTypeMark;
        
        } else if ([command isEqualToString:@"light"]) {
            cls  = [OutputParserLightLine class];
            type = OutputParserLineTypeLight;

            lightName  = count > 2 ? [words objectAtIndex:2] : nil;
            lightColor = sGetColorFromParsedString(string);
            
            if (!lightName || !lightColor) {
                type = OutputParserLineTypeParseError;
            }

        } else {
            type = OutputParserLineTypeParseError;
        }

    // Check for file issue
    } else {
        if (!_issueRegularExpression) {
            _issueRegularExpression =  [NSRegularExpression regularExpressionWithPattern:@"(.*?):([0-9]+)(:[0-9]+)?\\s+(.*?)$" options:NSRegularExpressionCaseInsensitive error:NULL];
        }
        
        sMatch(_issueRegularExpression, string, ^(NSArray *matches) {
            if ([matches count] == 4) {
                cls  = [OutputParserIssueLine class];
                type = OutputParserLineTypeFileIssue;

                path = [matches objectAtIndex:0];
                lineNumber = [[matches objectAtIndex:1] integerValue];

                NSString *columnString = [matches objectAtIndex:2];
                columnNumber = [columnString length] > 0 ? [columnString integerValue] : NSNotFound;
    
                issueString = [matches objectAtIndex:3];
            }
        });
    }

    OutputParserLine *line = [[cls alloc] init];
    
    [line setType:type];
    [line setString:string];
    
    if (type == OutputParserLineTypeLight) {
        OutputParserLightLine *lightLine = (OutputParserLightLine *)line;
    
        [lightLine setColor:lightColor];
        [lightLine setLightName:lightName];

    } else if (type == OutputParserLineTypeFileIssue) {
        OutputParserIssueLine *issueLine = (OutputParserIssueLine *)line;
        
        [issueLine setPath:path];
        [issueLine setLineNumber:lineNumber];
        [issueLine setColumnNumber:columnNumber];
        [issueLine setIssueString:issueString];
    }
    
    return line;
}


@end


@implementation OutputParserLine
@end


@implementation OutputParserLightLine
@end


@implementation OutputParserIssueLine
@end

