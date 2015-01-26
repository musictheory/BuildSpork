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

#import "OutputParser.h"
#import "Event.h"
#import "Project.h"


@implementation OutputParser {
    NSRegularExpression *_issueRegularExpression;
}


- (Event *) eventForLineData:(NSData *)data project:(Project *)project fromStandardError:(BOOL)fromStandardError
{
    const char *bytes  = [data bytes];
    NSInteger   length = [data length];
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    __block Class      cls          = [Event class];
    __block NSString  *type         = EventTypeMessage;
    __block NSString  *lightColor   = nil;
    __block NSString  *lightName    = nil;
    __block NSString  *path         = nil;
    __block NSInteger  lineNumber   = NSNotFound;
    __block NSInteger  columnNumber = NSNotFound;
    __block NSString  *issueString  = nil;

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

        if ([command isEqualToString:@"init"]) {
            type = EventTypeInit;

        } else if ([command isEqualToString:@"start"]) {
            type = EventTypeStart;

        } else if ([command isEqualToString:@"stop"]) {
            type = EventTypeStop;

        } else if ([command isEqualToString:@"reset"]) {
            type = EventTypeReset;

        } else if ([command isEqualToString:@"mark"]) {
            type = EventTypeMark;
        
        } else if ([command isEqualToString:@"light"]) {
            cls  = [LightEvent class];
            type = EventTypeLight;

            lightName  = count > 2 ? [words objectAtIndex:2] : nil;
            lightColor = nil;
            
            if (count > 3) {
                lightColor = [[words subarrayWithRange:NSMakeRange(3, count - 3)] componentsJoinedByString:@" "];
            }
            
            if (!lightName || !lightColor) {
                type = EventTypeInternal;
            }

        } else {
            type = EventTypeInternal;
        }

    // Check for file issue
    } else {
        if (!_issueRegularExpression) {
            _issueRegularExpression =  [NSRegularExpression regularExpressionWithPattern:@"(.*?):([0-9]+)(:[0-9]+)?\\s+(.*?)$" options:NSRegularExpressionCaseInsensitive error:NULL];
        }
        
        MatchRegularExpression(_issueRegularExpression, string, ^(NSArray *matches) {
            if ([matches count] == 4) {
                path = [matches objectAtIndex:0];

                if (![project URLWithFilePath:path]) {
                    return;
                }

                cls  = [IssueEvent class];
                type = EventTypeIssue;

                path = [matches objectAtIndex:0];
                lineNumber = [[matches objectAtIndex:1] integerValue];

                NSString *columnString = [matches objectAtIndex:2];
                columnNumber = [columnString length] > 0 ? [columnString integerValue] : NSNotFound;
    
                issueString = [matches objectAtIndex:3];
            }
        });
    }

    Event *event = [[cls alloc] init];
    
    [event setType:type];
    [event setString:string];
    [event setLocation:(fromStandardError ? EventLocationErrorStream : EventLocationOutputStream)];

    if ([event isKindOfClass:[LightEvent class]]) {
        LightEvent *lightEvent = (LightEvent *)event;
    
        [lightEvent setColorString:lightColor];
        [lightEvent setLightName:lightName];

    } else if ([event isKindOfClass:[IssueEvent class]]) {
        IssueEvent *issueEvent = (IssueEvent *)event;
        
        [issueEvent setPath:path];
        [issueEvent setLineNumber:lineNumber];
        [issueEvent setColumnNumber:columnNumber];
        [issueEvent setIssueString:issueString];
    }
    
    return event;
}


@end
