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

#import "ProjectManager.h"
#import "Project.h"


@interface ProjectManager ()
@property NSMutableArray *projects;
@end

static NSString * const sProjectsKey = @"Projects";

@implementation ProjectManager {
    NSMutableArray *_projects;
}


+ (id) sharedInstance
{
    static ProjectManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[ProjectManager alloc] init];
    });
    
    return sSharedInstance;
}


- (id) init
{
    if ((self = [super init])) {
        [self _loadProjects];
    }

    return self;
}


- (void) _setNeedsSave
{
    __weak id weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf _saveProjects];
    });
}


- (void) _loadProjects
{
    NSMutableArray *projects = [NSMutableArray array];
   
    for (NSDictionary *dictionary in [[NSUserDefaults standardUserDefaults] objectForKey:sProjectsKey]) {
        if (![dictionary isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        Project *project = [[Project alloc] initWithDictionary:dictionary];
        if (project) [projects addObject:project];
    }

    [self setProjects:projects];
}


- (void) _saveProjects
{
    NSMutableArray *outProjects = [NSMutableArray array];
    
    for (Project *project in [self projects]) {
        [outProjects addObject:[project dictionaryRepresentation]];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:outProjects forKey:sProjectsKey];
}


- (void) addProject:(Project *)project
{
    if (project) {
        [[self mutableArrayValueForKey:@"projects"] addObject:project];
    }
    
    [self _setNeedsSave];
}


- (void) removeProject:(Project *)project
{
    [[self mutableArrayValueForKey:@"projects"] removeObject:project];
    [self _setNeedsSave];
}


- (void) insertProject:(Project *)project atIndex:(NSInteger)index
{
    [[self mutableArrayValueForKey:@"projects"] insertObject:project atIndex:index];
    [self _setNeedsSave];
}


- (Project *) projectWithUUID:(NSUUID *)UUID
{
    if (!UUID) return nil;

    for (Project *project in [self projects]) {
        if ([[project UUID] isEqual:UUID]) {
            return project;
        }
    }
    
    return nil;
}


#pragma mark - KVC Compliance

- (void) insertProjects:(NSArray *)array atIndexes:(NSIndexSet *)indexes
{
    [_projects insertObjects:array atIndexes:indexes];
}


- (void) removeItemsAtIndexes:(NSIndexSet *)indexes
{
    [_projects removeObjectsAtIndexes:indexes];
}


@end
