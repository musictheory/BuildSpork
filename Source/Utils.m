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

#import "Utils.h"

extern NSArray *Map(id<NSFastEnumeration> collection, id (^callback)(id item))
{
    NSMutableArray *result = [NSMutableArray array];

    for (id item in collection) {
        id mapped = callback(item);
        if (mapped) [result addObject:mapped];
    }
    
    return result;
}



BOOL MatchRegularExpression(NSRegularExpression *re, NSString *string, void (^callback)(NSArray *))
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


BOOL IsDarkColor(NSColor *color)
{
    NSColorSpace     *space = [color colorSpace];
    NSColorSpaceModel model = [space colorSpaceModel];

    if (model == NSRGBColorSpaceModel) {
        CGFloat h, s, b, a;
        [color getHue:&h saturation:&s brightness:&b alpha:&a];
        return b < 0.5;
    
    } else if (model == NSGrayColorSpaceModel) {
        CGFloat w, a;
        [color getWhite:&w alpha:&a];
        return w < 0.5;
    }
    
    return NO;
}


NSString *GetStringForColor(NSColor *color)
{
    NSColorSpace     *space = [color colorSpace];
    NSColorSpaceModel model = [space colorSpaceModel];

    CGFloat r, g, b, a;

    if (model == NSRGBColorSpaceModel) {
        [color getRed:&r green:&g blue:&b alpha:&a];
        
    } else if (model == NSGrayColorSpaceModel) {
        CGFloat w;
        [color getWhite:&w alpha:&a];
        r = g = b = w;
    }
    
    return [NSString stringWithFormat:@"rgba(%ld, %ld, %ld, %g)", (long)(r * 255.0), (long)(g * 255.0), (long)(b * 255.0), a];
}


NSColor *GetColorForString(NSString *stringToParse)
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
        MatchRegularExpression(re, stringToParse, callback);
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
