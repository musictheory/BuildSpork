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

#import "TaskRun.h"
#import "Project.h"

@implementation TaskRun {
    NSTask *_task;

    NSMutableData *_outputBuffer;
    NSMutableData *_errorBuffer;
}

- (id) initWithCommand:(NSString *)command project:(Project *)project
{
    if ((self = [super init])) {
        _command = command;
        _project = project;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];

    }

    return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Private Methods

- (void) _handleApplicationWillTerminate:(NSNotification *)note
{
    [_task terminate];
}


- (void) _taskDidTerminate
{
    [_delegate taskRunStopped:self];
    _task = nil;
}


- (void) _appendData:(NSData *)data toBuffer:(NSMutableData *)buffer
{
    [buffer appendData:data];

    const UInt8 *bytes  = [buffer bytes];
    NSInteger    length = [buffer length];
    
    NSInteger lineStart = 0;
    
    for (NSInteger i = 0; i < length; i++) {
        if (bytes[i] == 0x0a) {
            [_delegate taskRun:self receivedLineData:[buffer subdataWithRange:NSMakeRange(lineStart, i - lineStart)] fromStandardError:(buffer == _errorBuffer)];
            lineStart = i + 1;
        }
    }

    [buffer replaceBytesInRange:NSMakeRange(0, lineStart) withBytes:NULL length:0];
}


#pragma mark - Public Methods

- (void) start
{
    if (!_command) return;

    if (_task) {
        [_task terminate];
        _task = nil;
    }
    
    _task = [[NSTask alloc] init];

    [_task setLaunchPath:@"/bin/sh"];
    [_task setArguments:@[ @"-c", _command ]];
    [_task setCurrentDirectoryPath:[[_project URL] path]];
    
    NSMutableDictionary *environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
    
    for (NSString *key in [_project environment]) {
        NSString *replacement = [[_project environment] objectForKey:key];
        [environment setObject:replacement forKey:key];
    }
    
    [environment setObject:@"1" forKey:@"net_musictheory_spork"];

    [_task setEnvironment:environment];

    NSPipe *outputPipe = [NSPipe pipe];
    [_task setStandardOutput:outputPipe];

    NSPipe *errorPipe = [NSPipe pipe];
    [_task setStandardError:errorPipe];

    _errorBuffer  = [NSMutableData data];
    _outputBuffer = [NSMutableData data];

    __weak id weakSelf = self;

    [[outputPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
        NSData *data = [handle availableData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _appendData:data toBuffer:_outputBuffer];
        });
    }];

    [[errorPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
        NSData *data = [handle availableData];

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _appendData:data toBuffer:_errorBuffer];
        });
    }];

    [_task setTerminationHandler:^(NSTask *task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _taskDidTerminate];
        });
    }];

    [_task launch];
    [_delegate taskRunStarted:self];
}


- (void) stop
{
    [_task terminate];
}


@end
