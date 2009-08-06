//
//  CPBonjourGroup.m
//  ContactPalette
//
//  Created by Stephen Voida on 1/21/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import "CPBonjourGroup.h"


@implementation CPBonjourGroup

#pragma mark Lifecycle methods

- (id) init {
	return [super initWithName:@"Nearby Users" editable:NO];
}


#pragma mark -
#pragma mark Output representation methods 

- (NSImage *)defaultIcon {
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForImageResource:@"bonjour.png"];
	return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
}

@end
