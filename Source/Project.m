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

#import "Project.h"
#import "JSONTypechecker.h"

NSString * const ProjectDidUpdateConfigurationNotification = @"ProjectDidUpdateConfiguration";

static NSString * const sUUIDKey     = @"UUID";
static NSString * const sBookmarkKey = @"Bookmark";


static NSArray *GetTypeMap()
{
    static NSArray *result = nil;
    
    if (!result) result = @[
        @"$",                          JSONTypeDictionary,

        @"$.name",                     JSONTypeString,
        @"$.env",                      JSONTypeDictionary,
        @"$.env.",                     JSONTypeKey,
        @"$.env.*",                    JSONTypeString,

        @"$.targets",                  JSONTypeArray,
        @"$.targets[]",                JSONTypeDictionary,
        @"$.targets[].title",          JSONTypeString,
        @"$.targets[].command",        JSONTypeString,
        
        @"$.actions",                  JSONTypeArray,
        @"$.actions[]",                JSONTypeDictionary,
        @"$.actions[].title",          JSONTypeString,
        @"$.actions[].command",        JSONTypeString,
        @"$.actions[].tooltip",        JSONTypeString,
        @"$.actions[].icon",           JSONTypeString,

        @"$.lights",                   JSONTypeArray,
        @"$.lights[]",                 JSONTypeDictionary,
        @"$.lights[].name",            JSONTypeString,
        @"$.lights[].title",           JSONTypeString,
        @"$.lights[].tooltip",         JSONTypeString
    ];
    
    return result;
}


@interface Project ()
@property (atomic) NSString *name;
@property (atomic) NSDictionary *environment;
@property (atomic) NSString *path;
@property (atomic) NSArray *targets;
@property (atomic) NSArray *actions;
@property (atomic) NSArray *lights;
@property (atomic) ProjectStatus status;
@property (atomic) NSError *error;
@end



@interface ProjectTarget ()
- (id) _initWithDictionary:(NSDictionary *)dictionary;
@end

@interface ProjectAction ()
- (id) _initWithDictionary:(NSDictionary *)dictionary;
@end

@interface ProjectLight ()
- (id) _initWithDictionary:(NSDictionary *)dictionary;
@end


@implementation Project {
    dispatch_source_t _watcher;
    NSData           *_bookmark;
}

- (id) _initWithURL:(NSURL *)URL orBookmark:(NSData *)bookmark UUID:(NSUUID *)UUID
{
    if ((self = [super init])) {
        BOOL bookmarkIsStale = NO;
        NSError *error = nil;

        if (bookmark) {
            URL = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&bookmarkIsStale error:&error];
        }
        
        if (!URL) {
            self = nil;
            return self;
        }

        if (!bookmark || bookmarkIsStale) {
            bookmark = [URL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
        }

        if (!UUID) {
            UUID = [NSUUID UUID];
        }

        _URL      = URL;
        _bookmark = bookmark;
        _UUID     = UUID;

        [self _readBuildJSON];
        [self _startMonitoringBuildConfiguration];
    }
    
    return self;
}


- (id) initWithURL:(NSURL *)URL
{
    return [self _initWithURL:URL orBookmark:nil UUID:nil];
}


- (id) initWithDictionary:(NSDictionary *)dictionary
{
    NSData   *bookmark   = [dictionary objectForKey:sBookmarkKey];
    NSString *UUIDString = [dictionary objectForKey:sUUIDKey];

    if (!bookmark || !UUIDString) {
        self = nil;
        return self;
    }

    NSUUID *UUID = [[NSUUID alloc] initWithUUIDString:UUIDString];

    return [self _initWithURL:nil orBookmark:bookmark UUID:UUID];
}


#pragma mark - Private Methods

- (void) _readBuildJSON
{
    [self _startMonitoringBuildConfiguration];

    NSData *data = [NSData dataWithContentsOfURL:[self _buildConfigurationURL]];

    NSError *error = nil;
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;

    if (!data || error) {
        [self setName:[_URL lastPathComponent]];
        [self setStatus:data ? ProjectStatusInvalidJSON : ProjectStatusMissingJSON];
        [self setError:error];

        [[NSNotificationCenter defaultCenter] postNotificationName:ProjectDidUpdateConfigurationNotification object:self];
        
        return;
    }
    
    NSDictionary *root = GetTypecheckedObject(object, GetTypeMap());
    
    NSArray  *targetDictionaries = [root objectForKey:@"targets"];
    NSArray  *actionDictionaries = [root objectForKey:@"actions"];
    NSArray  *lightDictionaries  = [root objectForKey:@"lights"];

    NSString       *name         = [root objectForKey:@"name"];
    NSDictionary   *environment  = [root objectForKey:@"env"];

    NSMutableArray *targets = [NSMutableArray array];
    NSMutableArray *actions = [NSMutableArray array];
    NSMutableArray *lights  = [NSMutableArray array];

    for (NSDictionary *targetDictionary in targetDictionaries) {
        [targets addObject:[[ProjectTarget alloc] _initWithDictionary:targetDictionary]];
    }

    for (NSDictionary *actionDictionary in actionDictionaries) {
        [actions addObject:[[ProjectAction alloc] _initWithDictionary:actionDictionary]];
    }

    for (NSDictionary *lightDictionary in lightDictionaries) {
        [lights addObject:[[ProjectLight alloc] _initWithDictionary:lightDictionary]];
    }
 
    [self setName:name];
    [self setEnvironment:environment];
    [self setTargets:targets];
    [self setActions:actions];
    [self setLights:lights];
    [self setStatus:ProjectStatusValid];
    [self setError:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ProjectDidUpdateConfigurationNotification object:self];
}


- (NSURL *) _buildConfigurationURL
{
    return [_URL URLByAppendingPathComponent:@"spork.json"];
}


- (void) _startMonitoringBuildConfiguration
{
    [self _stopMonitoringBuildConfiguration];

    int fd = open([[[self _buildConfigurationURL] path] fileSystemRepresentation], O_EVTONLY);

    unsigned long mask = DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND |
                         DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK  | DISPATCH_VNODE_RENAME |
                         DISPATCH_VNODE_REVOKE;

    _watcher = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd, mask, dispatch_get_global_queue(0, 0));

    __weak id weakSelf = self;
    dispatch_source_set_event_handler( _watcher, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _readBuildJSON];
        });
    });

    dispatch_source_set_cancel_handler(_watcher, ^{
        close(fd);
    });
    
    dispatch_resume(_watcher);
}


- (void) _stopMonitoringBuildConfiguration
{
    if (_watcher) {
        dispatch_source_cancel(_watcher);
        _watcher = nil;
    }
}


#pragma mark - Public Methods

- (NSURL *) URLWithFilePath:(NSString *)path
{
    if (!_URL) return nil;

    NSMutableArray *components = [NSMutableArray array];
    
    NSArray *toAdd;
    
    toAdd = [_URL pathComponents];
    if (toAdd) [components addObjectsFromArray:toAdd];

    toAdd = [path pathComponents];
    if (toAdd) [components addObjectsFromArray:toAdd];
    

    NSURL *URL = [NSURL fileURLWithPathComponents:components];
    
    if (URL && [[NSFileManager defaultManager] fileExistsAtPath:[URL path]]) {
        return URL;
    }
    return nil;
}


- (NSDictionary *) dictionaryRepresentation
{
    if (!_UUID || !_bookmark) return nil;

    return @{
        sUUIDKey: [_UUID UUIDString],
        sBookmarkKey: _bookmark
    };
}


@end



@implementation ProjectTarget

- (id) _initWithDictionary:(NSDictionary *)dictionary
{
    if ((self = [super init])) {
        _title   = [dictionary objectForKey:@"title"];
        _command = [dictionary objectForKey:@"command"];
    }
    
    return self;
}

@end


@implementation ProjectAction

- (id) _initWithDictionary:(NSDictionary *)dictionary
{
    if ((self = [super init])) {
        _title   = [dictionary objectForKey:@"title"];
        _command = [dictionary objectForKey:@"command"];
        _tooltip = [dictionary objectForKey:@"tooltip"];
        _icon    = [dictionary objectForKey:@"icon"];
    }
    
    return self;
}

@end


@implementation ProjectLight

- (id) _initWithDictionary:(NSDictionary *)dictionary
{
    if ((self = [super init])) {
        _name  = [dictionary objectForKey:@"name"];
        _title = [dictionary objectForKey:@"title"];
    }
    
    return self;
}

@end


