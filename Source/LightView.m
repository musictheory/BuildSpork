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

#import "LightView.h"

@implementation LightView

- (void) drawRect:(NSRect)dirtyRect
{
    NSBezierPath *outerPath = [NSBezierPath bezierPathWithOvalInRect:CGRectInset([self bounds], 2, 2)];
    if (_color) {
        [_color set];
        [outerPath fill];
    }
    
    NSBezierPath *innerPath = [NSBezierPath bezierPathWithOvalInRect:CGRectInset([self bounds], 3, 3)];
    [outerPath appendBezierPath:[innerPath bezierPathByReversingPath]];

    [[NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:0.2] set];
    [outerPath fill];
}


- (void) setColor:(NSColor *)color
{
    if (_color != color) {
        _color = color;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTitle:(NSString *)title
{
    if (_title != title) {
        _title = title;
        [self setNeedsDisplay:YES];
    }
}


@end
