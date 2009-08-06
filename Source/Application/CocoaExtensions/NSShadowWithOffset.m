//
//  NSShadowWithOffset.m
//  Dock Icon
//
//  Created by John Devor on 1/9/07.
//

#import "NSShadowWithOffset.h"


@implementation NSShadow (DockIcon)

- (id)initWithShadowOffset:(NSSize)offset blurRadius:(float)radius color:(NSColor *)color
{
	if (self = [super init]) {
		[self setShadowOffset:offset];
		[self setShadowBlurRadius:radius];
		[self setShadowColor:color];
	}
	return self;
}

+ (NSShadow *)shadowWithOffset:(NSSize)offset blurRadius:(float)radius color:(NSColor *)color
{
	return [[[NSShadow alloc] initWithShadowOffset:offset blurRadius:radius color:color] autorelease];
}

@end
