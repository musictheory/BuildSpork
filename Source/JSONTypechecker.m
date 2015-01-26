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

#import "JSONTypechecker.h"

NSString * const JSONTypeArray       = @"JSONTypeArray";
NSString * const JSONTypeData        = @"JSONTypeData";
NSString * const JSONTypeDate        = @"JSONTypeDate";
NSString * const JSONTypeDictionary  = @"JSONTypeDictionary";
NSString * const JSONTypeNumber      = @"JSONTypeNumber";
NSString * const JSONTypeString      = @"JSONTypeString";

NSString * const JSONTypeAny         = @"JSONTypeAny";
NSString * const JSONTypeDelete      = @"JSONTypeDelete";
NSString * const JSONTypeKey         = @"JSONTypeKey";


typedef struct {
    CFMutableStringRef     path;
    CFMutableDictionaryRef pathToTypeMap;
} JSONTypecheckState;

static NS_RETURNS_RETAINED id sCopyTypecheckedObject(JSONTypecheckState *state, id inObject, NSString *expectedType);


static NS_RETURNS_RETAINED NSDictionary *sCopyTypecheckedDictionary(JSONTypecheckState *state, NSDictionary *inDictionary) 
{
    NSUInteger count = [inDictionary count];
    NSMutableDictionary *outDictionary = [[NSMutableDictionary alloc] initWithCapacity:count];
    
    CFRange range = CFRangeMake(CFStringGetLength(state->path), 1);

    const UniChar dot = '.';

    CFStringAppendCharacters(state->path, &dot, 1);
    BOOL isWildcardKey = NO;

    if (CFDictionaryGetValue(state->pathToTypeMap, state->path) == (__bridge CFTypeRef)JSONTypeKey) {
        const UniChar star = '*';
        CFStringAppendCharacters(state->path, &star, 1);
        range.length = 2;
        isWildcardKey = YES;
    }

    for (id inKey in inDictionary) {
        id outKey = sCopyTypecheckedObject(state, inKey, JSONTypeString);
        CFRange range2;

        if (!isWildcardKey) {
            CFStringRef keyString = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@"), inKey);
            range2 = CFRangeMake(CFStringGetLength(state->path), CFStringGetLength(keyString));
            CFStringAppend(state->path, keyString);
            CFRelease(keyString);
        }

        NSString *expectedTypeForValue = (__bridge NSString *)(CFDictionaryGetValue(state->pathToTypeMap, state->path));

        id inObject  = [inDictionary objectForKey:inKey];
        id outObject = sCopyTypecheckedObject(state, inObject, expectedTypeForValue);
        if (outObject) {
            [outDictionary setObject:outObject forKey:outKey];
        }
        
        if (!isWildcardKey) {
            CFStringDelete(state->path, range2);
        }
    }
    
    CFStringDelete(state->path, range);

    return outDictionary;
}


static NS_RETURNS_RETAINED NSArray *sCopyTypecheckedArray(JSONTypecheckState *state, NSArray *inArray)
{
    CFRange range  = CFRangeMake(CFStringGetLength(state->path), 2);

    NSUInteger count = [inArray count];
    NSMutableArray *outArray = [[NSMutableArray alloc] initWithCapacity:count];

    CFStringAppend(state->path, CFSTR("[]"));
    NSString *typeString = (__bridge NSString *)(CFDictionaryGetValue(state->pathToTypeMap, state->path));

    for (id inObject in inArray) {
        id outObject = sCopyTypecheckedObject(state, inObject, typeString);

        if (outObject) {
            [outArray addObject:outObject];
        }
    }

    CFStringDelete(state->path, range);

    return outArray;
}


static NS_RETURNS_RETAINED NSObject *sCopyTypecheckedObject(JSONTypecheckState *state, id inObject, NSString *expectedType)
{
    id outObject = nil;
    
    NSString *actualType = nil;
    if      ( [inObject isKindOfClass:[NSArray      class]] ) { actualType = JSONTypeArray;      }
    else if ( [inObject isKindOfClass:[NSData       class]] ) { actualType = JSONTypeData;       }
    else if ( [inObject isKindOfClass:[NSDate       class]] ) { actualType = JSONTypeDate;       }
    else if ( [inObject isKindOfClass:[NSDictionary class]] ) { actualType = JSONTypeDictionary; }
    else if ( [inObject isKindOfClass:[NSNumber     class]] ) { actualType = JSONTypeNumber;     }
    else if ( [inObject isKindOfClass:[NSString     class]] ) { actualType = JSONTypeString;     }
    
    if (!actualType) {
        NSLog(@"[JSONTypechecker] - Unknown class for %@: %@", state->path, NSStringFromClass([inObject class]));
        return outObject;
    }
    
    if (!expectedType) {
        NSLog(@"[JSONTypechecker] - No type defined for %@", state->path);
        return outObject;
    }
    
    if (expectedType == JSONTypeDelete) {
        return outObject;
    }

    if (actualType == JSONTypeArray && expectedType == JSONTypeArray) {
        outObject = sCopyTypecheckedArray(state, (NSArray *)inObject);
        
    } else if (actualType == JSONTypeDictionary && expectedType == JSONTypeDictionary) {
        outObject = sCopyTypecheckedDictionary(state, (NSDictionary *)inObject);

    } else if ((actualType == JSONTypeString) && (expectedType == JSONTypeNumber)) {
        outObject = [[NSNumber alloc] initWithInteger:[(NSString *)inObject integerValue]];
        
    } else if ((actualType == JSONTypeNumber) && (expectedType == JSONTypeString)) {
        outObject = [(NSNumber *)inObject stringValue];

    } else if ((actualType == expectedType) || (expectedType == JSONTypeAny)) {
        outObject = inObject;
    }

    if (!outObject) {
        NSLog(@"[JSONTypechecker] - %@: expected %@, actual %@", state->path, expectedType, actualType);
    }

    return outObject;
}


id GetTypecheckedObject(id inObject, NSArray *typeMap)
{
    if (!inObject) return nil;

    JSONTypecheckState state = {
        CFStringCreateMutable(NULL, 0),
        CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks)
    };
    
    const UniChar dollar = '$';
    CFStringAppendCharacters(state.path, &dollar, 1);

    NSEnumerator *enumerator = [typeMap objectEnumerator];
    while (1) {
        NSString *path = [enumerator nextObject];  if (!path) break;
        NSString *type = [enumerator nextObject];  if (!type) break;
        CFDictionarySetValue(state.pathToTypeMap, (__bridge CFStringRef)path, (__bridge CFStringRef)type);
    }
    
    NSString *expectedRootType = CFDictionaryGetValue(state.pathToTypeMap, state.path);
    if (!expectedRootType) expectedRootType = JSONTypeDictionary;

    id result = sCopyTypecheckedObject(&state, inObject, expectedRootType);

    CFRelease(state.path);
    CFRelease(state.pathToTypeMap);

    return result;
}

