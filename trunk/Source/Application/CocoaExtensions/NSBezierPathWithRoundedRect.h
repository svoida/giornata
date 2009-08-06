//
//  NSBezierPathWithRoundedRect.h
//  Dock Icon
//
//  Created by John Devor on 1/9/07.
//

#import <Cocoa/Cocoa.h>


@interface NSBezierPath (DockIcon)

+ (NSBezierPath *)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius;

@end
