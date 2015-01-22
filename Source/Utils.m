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