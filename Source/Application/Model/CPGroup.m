//
//  CPGroup.m
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import "CPGroup.h"
#import "CPPerson.h";


@implementation CPGroup

#pragma mark Output representation methods

- (NSString *)toolTipText {
	NSMutableString *tooltip = [NSMutableString stringWithFormat:@"%@\nGroup\n------------\nMembers (%d):", _name, [_contents count]];
	int i;
	
	int numEntities = [_contents count];
	if (numEntities == 0)
		[tooltip appendString:@"\n(none)"];
	else {
		for (i = 0; i < MIN(numEntities, 5); i++)
			[tooltip appendFormat:@"\n- %@", [[_contents objectAtIndex:i] description]];
		if (numEntities > 5)
			[tooltip appendString:@"\n..."];
	}
	
	return (NSString *)tooltip;
}

- (NSImage *)defaultIcon {
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForImageResource:@"group.png"];
	return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
}


#pragma mark Accessor methods

- (NSImage *)icon {
	// If there's nothing in the group, just go with the basic icon
	if ([self isEmpty])
		return _icon;
	
	// Define a new (temporary) icon
	NSImage *expandableIcon = [[[NSImage alloc] initWithSize:NSMakeSize(ENTITY_ICON_SIZE, ENTITY_ICON_SIZE)] autorelease];
	
	// Paint the basic icon into it
	[expandableIcon lockFocus];
	[_icon drawInRect:NSMakeRect(0.0, 0.0, [expandableIcon size].width, [expandableIcon size].height)
			 fromRect:NSMakeRect(0.0, 0.0, [_icon size].width, [_icon size].height)
			operation:NSCompositeSourceOver
			 fraction:1.0];
	
	// Then load the overlay icon
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForImageResource:@"overlay_expands.png"];
	NSImage *overlay = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	
	// And paint that on top
	[overlay drawInRect:NSMakeRect(0.0, 0.0, [expandableIcon size].width, [expandableIcon size].height)
			   fromRect:NSMakeRect(0.0, 0.0, [overlay size].width, [overlay size].height)
			  operation:NSCompositeSourceOver
			   fraction:1.0];
	[expandableIcon unlockFocus];
	
	return expandableIcon;
}

- (NSArray *)memberEmails {
	NSMutableArray *result = [NSMutableArray array];
	NSEnumerator *children = [_contents objectEnumerator];
	CPEntity *child;
	while (child = [children nextObject])
		if ([child isKindOfClass:[CPPerson class]])
			[result addObject:[(CPPerson *)child email]];
		else if ([child isMemberOfClass:[CPGroup class]])
			[result addObjectsFromArray:[(CPGroup *)child memberEmails]];
	
	return result;
}


#pragma mark -
#pragma mark Capability specification methods

- (BOOL)canAddChild:(CPEntity *)entity fromSource:(CPEntity *)source {
	if (entity &&
		source &&
		_editable &&
		[entity isKindOfClass:[CPPerson class]] &&
		![self containsChild:entity recursively:NO])
		return YES;
	else
		return NO;
}

- (BOOL)canMoveChild:(CPEntity *)entity toDestinationIndex:(unsigned)destinationIndex {
	return YES;
}

- (BOOL)canRemoveChild:(CPEntity *)entity {
	if (entity &&
		_editable &&
		[self containsChild:entity recursively:NO])
		return YES;
	else
		return NO;
}

#pragma mark -
#pragma mark Badge maintenance method

- (int)updateBadgeCountsUsingDictionary:(NSDictionary *)badgeDict {
	// Populate children first, but keep count of how many badges we apply
	int badgeCount = 0;
	NSEnumerator *children = [_contents objectEnumerator];
	CPEntity *child;
	while (child = [children nextObject]) {
		if ([child isMemberOfClass:[CPPerson class]]) {
			NSNumber *badges = [badgeDict objectForKey:[(CPPerson *)child email]];
			if (badges != nil) {
				[child setBadgeCount:[badges intValue]];
				badgeCount += [badges intValue];
			} else
				[child setBadgeCount:0];
		} else if ([child isKindOfClass:[CPGroup class]])
			badgeCount += [(CPGroup *)child updateBadgeCountsUsingDictionary:badgeDict];
	}
	
	// Set our own badge count last
	[self setBadgeCount:badgeCount];
	
	// And then return it, so that our parents can use it to compute theirs
	return badgeCount;
}

@end
