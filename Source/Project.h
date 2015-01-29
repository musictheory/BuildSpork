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

@import Foundation;

extern NSString * const ProjectDidUpdateConfigurationNotification;

typedef NS_ENUM(NSInteger, ProjectStatus) {
    ProjectStatusValid,
    ProjectStatusMissingJSON,
    ProjectStatusInvalidJSON
};


@interface Project : NSObject

- (id) initWithURL:(NSURL *)URL;
- (id) initWithDictionary:(NSDictionary *)dictionary;

- (NSURL *) URLWithFilePath:(NSString *)path;   // nil if file doesn't exist

@property (readonly) NSString *name;
@property (readonly) NSDictionary *environment;

@property (readonly) NSURL *URL;
@property (readonly) NSData *bookmark;

@property (readonly) NSArray *targets;
@property (readonly) NSArray *actions;

@property (readonly) ProjectStatus status;
@property (readonly) NSError *error;

@property (readonly) NSUUID *UUID;

@property (readonly) NSDictionary *dictionaryRepresentation;

@end


@interface ProjectTarget : NSObject

@property (readonly) NSString *title;
@property (readonly) NSString *command;

@end


@interface ProjectAction : NSObject

@property (readonly) NSString *title;
@property (readonly) NSString *command;
@property (readonly) NSString *tooltip;
@property (readonly) NSString *icon;

@end

