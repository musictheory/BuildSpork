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


#import "Event.h"

NSString * const EventTypeInit     = @"init";
NSString * const EventTypeStart    = @"start";
NSString * const EventTypeStop     = @"stop";
NSString * const EventTypeReset    = @"reset";
NSString * const EventTypeMark     = @"mark";
NSString * const EventTypeMessage  = @"message";
NSString * const EventTypeInfo     = @"info";
NSString * const EventTypeIssue    = @"issue";
NSString * const EventTypeInternal = @"internal";


@implementation Event

- (void) _saveToDictionary:(NSMutableDictionary *)dictionary
{
    NSString *type   = [self type];
    NSString *string = [self string];
    
    if (type)   [dictionary setObject:type   forKey:@"type"];
    if (string) [dictionary setObject:string forKey:@"string"];

    if ([self location] == EventLocationErrorStream) {
        [dictionary setObject:@"error" forKey:@"location"];
    } else {
        [dictionary setObject:@"output" forKey:@"location"];
    }
}


- (NSDictionary *) dictionaryRepresentation
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self _saveToDictionary:dictionary];
    return dictionary;
}

@end


@implementation IssueEvent

- (void) _saveToDictionary:(NSMutableDictionary *)dictionary
{
    [super _saveToDictionary:dictionary];

    NSString *path  = [self path];
    NSString *issue = [self issueString];
    
    NSInteger lineNumber   = [self lineNumber];
    NSInteger columnNumber = [self columnNumber];

    NSString *line;
    NSString *column;
    
    if (lineNumber != NSNotFound) {
        line = [NSString stringWithFormat:@"%ld", (long)[self lineNumber]];
    }
    
    if (columnNumber != NSNotFound) {
        column = [NSString stringWithFormat:@"%ld", (long)[self columnNumber]];
    }

    if (path)   [dictionary setObject:path   forKey:@"path"];
    if (line)   [dictionary setObject:line   forKey:@"line"];
    if (column) [dictionary setObject:column forKey:@"column"];
    if (issue)  [dictionary setObject:issue  forKey:@"issue"];
}

@end
