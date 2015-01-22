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

#import "Preferences.h"


NSString * const PreferencesDidChangeNotification = @"PreferencesDidChange";

static NSDictionary *sGetDefaultValues()
{
    static NSDictionary *sDefaultValues = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

    sDefaultValues = @{
        @"iconMode":       @(IconModeDock),

        @"font":            [NSFont fontWithName:@"Menlo" size:12],

        @"foregroundColor": [NSColor blackColor],
        @"backgroundColor": [NSColor whiteColor],
        @"errorColor":      [NSColor redColor],
        @"linkColor":       [NSColor blueColor]
    };

    });
    
    return sDefaultValues;
}



static void sSetDefaultObject(id dictionary, NSString *key, id valueToSave, id defaultValue)
{
    void (^saveObject)(NSObject *, NSString *) = ^(NSObject *o, NSString *k) {
        if (o) {
            [dictionary setObject:o forKey:k];
        } else {
            [dictionary removeObjectForKey:k];
        }
    };

    if ([defaultValue isKindOfClass:[NSNumber class]] || [defaultValue isKindOfClass:[NSString class]]) {
        saveObject(valueToSave, key);

    } else if ([defaultValue isKindOfClass:[NSFont class]]) {
        saveObject(@[ [valueToSave fontName], @( [valueToSave pointSize] ) ], key);
       
    } else if ([defaultValue isKindOfClass:[NSColor class]]) {
        NSMutableData *data = nil;
        
        if (valueToSave) {
            data = [NSMutableData data];
            NSArchiver *encoder = [[NSArchiver alloc] initForWritingWithMutableData:data];
            [encoder encodeRootObject:valueToSave];
        }
        
        saveObject(data, key);
    }
}


static void sRegisterDefaults()
{
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

    NSDictionary *defaultValuesDictionary = sGetDefaultValues();
    for (NSString *key in defaultValuesDictionary) {
        id value = [defaultValuesDictionary objectForKey:key];
        sSetDefaultObject(defaults, key, value, value);
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


@implementation Preferences


+ (id) sharedInstance
{
    static Preferences *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sRegisterDefaults();
        sSharedInstance = [[Preferences alloc] init];
    });
    
    return sSharedInstance;
}


- (id) init
{
    if ((self = [super init])) {
        [self _load];
        
        for (NSString *key in sGetDefaultValues()) {
            [self addObserver:self forKeyPath:key options:0 context:NULL];
        }
    }

    return self;
}


- (void) _load
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    id (^loadObjectOfClass)(Class, NSString *) = ^(Class cls, NSString *key) {
        NSObject *o = [defaults objectForKey:key];
        return [o isKindOfClass:cls] ? o : nil;
    };

    NSDictionary *defaultValuesDictionary = sGetDefaultValues();
    for (NSString *key in defaultValuesDictionary) {
        id defaultValue = [defaultValuesDictionary objectForKey:key];

        if ([defaultValue isKindOfClass:[NSNumber class]]) {
            [self setValue:@([defaults integerForKey:key]) forKey:key];

        } else if ([defaultValue isKindOfClass:[NSString class]]) {
            NSString *value = [defaults stringForKey:key];
            if (value) [self setValue:value forKey:key];
        
        } else if ([defaultValue isKindOfClass:[NSFont class]]) {
            NSArray *array = [defaults arrayForKey:key];
            if ([array count] >= 2) {
                NSString *name =  [array objectAtIndex:0];
                double    size = [[array objectAtIndex:1] doubleValue];
                
                NSFont *font = [NSFont fontWithName:name size:size];
                if (font) [self setValue:font forKey:key];
            }

        } else if ([defaultValue isKindOfClass:[NSColor class]]) {
            NSColor *result = nil;
            
            @try {
                NSData *data = loadObjectOfClass([NSData class], key);
                if (!data) continue;
                
                NSUnarchiver *unarchiver = [[NSUnarchiver alloc] initForReadingWithData:data];
                if (!unarchiver) continue;
                
                result = [unarchiver decodeObject];

            } @catch (NSException *e) { }

            [self setValue:result forKey:key];
        }
    }
}


- (void) _save
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSDictionary *defaultValuesDictionary = sGetDefaultValues();
    for (NSString *key in defaultValuesDictionary) {
        id defaultValue = [defaultValuesDictionary objectForKey:key];
        id selfValue    = [self valueForKey:key];
        
        sSetDefaultObject(defaults, key, selfValue, defaultValue);
    }

    [defaults synchronize];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PreferencesDidChangeNotification object:self];
        [self _save];
    }
}


@end
