//
//  NSShadowWithOffset.h
//  Dock Icon
//
//  Created by John Devor on 1/9/07.
//

#import <Cocoa/Cocoa.h>


@interface NSShadow (DockIcon)

- (id)initWithShadowOffset:(NSSize)offset blurRadius:(float)radius color:(NSColor *)color;

+ (NSShadow *)shadowWithOffset:(NSSize)offset blurRadius:(float)radius color:(NSColor *)color;

@end
