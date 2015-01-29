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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, EventLocation) {
    EventLocationOutputStream,
    EventLocationErrorStream
};


extern NSString * const EventTypeInit;
extern NSString * const EventTypeStart;
extern NSString * const EventTypeStop;
extern NSString * const EventTypeReset;
extern NSString * const EventTypeMark;
extern NSString * const EventTypeMessage;
extern NSString * const EventTypeInfo;
extern NSString * const EventTypeInternal;
extern NSString * const EventTypeIssue;     // class = IssueEvent


@interface Event : NSObject
@property (copy) NSString *type;
@property (copy) NSString *string;

@property (readonly) NSDictionary *dictionaryRepresentation;

@property EventLocation location;

@end


@interface IssueEvent : Event
@property (copy) NSString  *path;
@property        NSInteger  lineNumber;
@property        NSInteger  columnNumber; // May be NSNotFound
@property (copy) NSString  *issueString;
@end
