//
//  NSBezierPathWithRoundedRect.m
//  Dock Icon
//
//  Created by John Devor on 1/9/07.
//

#import "NSBezierPathWithRoundedRect.h"


@implementation NSBezierPath (DockIcon)

+ (NSBezierPath *)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius
{
	NSBezierPath* path = [self bezierPath];
	radius = fminf(radius, 0.5f * fminf(NSWidth(aRect), NSHeight(aRect)));
	NSRect rect = NSInsetRect(aRect, radius, radius);
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) radius:radius startAngle:180.0 endAngle:270.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) radius:radius startAngle:270.0 endAngle:360.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) radius:radius startAngle:  0.0 endAngle: 90.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) radius:radius startAngle: 90.0 endAngle:180.0];
	[path closePath];
	return path;
}

@end
