//
//  CPEntity.m
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import "CPEntity.h"

#define CPEntityNameKey @"CPEntityName"
#define CPEntityEditableKey @"CPEntityEditable"
#define CPEntityIconKey @"CPEntityIcon"
#define CPEntityContentsKey @"CPEntityContents"


@implementation CPEntity

#pragma mark Lifetime methods

- (id)initWithName:(NSString *)name editable:(BOOL)editable {
	self = [super init];
	
	if (self) {
        if (name == nil)
            return nil;
        
		_name = [name copy];
		_editable = editable;
		_icon = [[CPEntity scaledIcon:[self defaultIcon]] retain];
		_contents = [[NSMutableArray alloc] init];
		_badgeCount = 0;
	}
	
	return self;
}

- (void)dealloc {
	// Stop listening to all children entities
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Release memory allocated to contents
	[_contents release];
	[_name release];
	[_icon release];
	
	// Clean up
	[super dealloc];    // BUG: Potential problem here with a resulting image dealloc (?)
}


#pragma mark -
#pragma mark NSCoding compliance methods

- (id)initWithCoder:(NSCoder *)coder {
	[super init];
	
	_name = [[coder decodeObjectForKey:CPEntityNameKey] copy];
	_editable = [coder decodeBoolForKey:CPEntityEditableKey];
	_icon = [[coder decodeObjectForKey:CPEntityIconKey] retain];
	_contents = [[coder decodeObjectForKey:CPEntityContentsKey] retain];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:_name forKey:CPEntityNameKey];
	[coder encodeBool:_editable forKey:CPEntityEditableKey];
	[coder encodeObject:_icon forKey:CPEntityIconKey];
	[coder encodeObject:_contents forKey:CPEntityContentsKey];
}


#pragma mark -
#pragma mark Output representation methods 

- (NSString *)description {
	return _name;
}

- (NSString *)toolTipText {
	return _name;
}

- (NSImage *)defaultIcon {
	return nil;
}


# pragma mark -
# pragma mark Accessor methods

- (NSString *)name {
	return _name;
}

- (void)setName:(NSString *)name {
	if ([self isEditable] && name != nil) {
		name = [name copy];
		[_name release];
		_name = name;
		
		// Notify the world that this entity has changed
		[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
															object:self];
	}
}

- (BOOL)isEditable {
	return _editable;
}

- (NSImage *)icon {
	return _icon;
}

- (void)setIcon:(NSImage *)icon {
	[_icon release];
	_icon = [[CPEntity scaledIcon:icon] retain];
	
	// Notify the world that this entity has changed
	[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
														object:self];
}

- (int)badgeCount {
	return _badgeCount;
}

- (void)setBadgeCount:(int)badgeCount {
	// Don't do anything if it's not an actual change!
	if (_badgeCount == badgeCount)
		return;

	_badgeCount = badgeCount;
	
	// Notify the world that this entity has changed
	[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
														object:self];
}


#pragma mark -
#pragma mark Child management methods

- (unsigned)addChild:(CPEntity *)entity fromSource:(CPEntity *)source {
	if (entity && [self canAddChild:entity fromSource:source]) {
		// Add the entity
		[_contents addObject:entity];
		
		_badgeCount += [entity badgeCount];
		
		// Pay attention to changes enacted to this new child
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(childChanged:)
													 name:kCPEntityChanged
												   object:entity];
		
		// Notify the world that this entity has changed
		[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
															object:self];
	}
	
	return [_contents count] - 1;
}

- (unsigned)insertChild:(CPEntity *)entity atIndex:(unsigned)insertionIndex fromSource:(CPEntity *)source {
	unsigned resultIndex = -1;
	
	if (entity &&
		[self canAddChild:entity fromSource:source] &&
		insertionIndex >= 0) {

		if (insertionIndex >= [_contents count]) {
			[_contents addObject:entity];
			resultIndex = [_contents count] - 1;
		} else {
			[_contents insertObject:entity atIndex:insertionIndex];
			resultIndex = insertionIndex;
		}
		
		_badgeCount += [entity badgeCount];
		
		// Pay attention to the changes enacted to this new child
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(childChanged:)
													 name:kCPEntityChanged
												   object:entity];
		
		// Notify the world that this entity has changed
		[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
															object:self];
	}
    
    return resultIndex;
}

- (CPEntity *)childAtIndex:(unsigned)childIndex {
	if (childIndex >= 0 &&
		childIndex < [_contents count])
		return [_contents objectAtIndex:childIndex];
	else
		return nil;
}

- (void)moveChildFromIndex:(unsigned)sourceIndex toIndex:(unsigned)destinationIndex {
	if (sourceIndex >= 0 &&
		sourceIndex < [_contents count] &&
		destinationIndex >= 0 &&
		destinationIndex <= [_contents count] &&
		[self canMoveChild:[_contents objectAtIndex:sourceIndex] toDestination:destinationIndex]) {
		// Grab (and retain the moving child)
		CPEntity *mover = [[_contents objectAtIndex:sourceIndex] retain];
		
		// Remove it from the contents array
		[_contents removeObjectAtIndex:sourceIndex];
		
		// And then add it back at the right destination
		if (destinationIndex > sourceIndex)
			destinationIndex--;
		
		if (destinationIndex == [_contents count])
			[_contents addObject:mover];
		else
			[_contents insertObject:mover atIndex:destinationIndex];
		
		// Finally, let go of our copy
		[mover release];
		
		// and notify the world that this entity has changed
		[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
															object:self];
	}
}

- (void)removeChild:(CPEntity *)entity {
	if (entity && [self canRemoveChild:entity]) {
		// Stop paying attention to changes on the removed child
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:kCPEntityChanged
													  object:entity];
		
		// Remove the entity
		[_contents removeObject:entity];
		
		_badgeCount -= [entity badgeCount];
		
		// Notify the world that this entity has changed
		[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
															object:self];
	}
}

- (void)removeChildAtIndex:(unsigned)childIndex {
	// The helper methods will take care of the bounds checking and change notifications on our behalf
	CPEntity *victim = [self childAtIndex:childIndex];
	[self removeChild:victim];
}

- (BOOL)isEmpty {
	return ([_contents count] == 0);
}

- (unsigned)count {
	return [_contents count];
}

- (BOOL)containsChild:(CPEntity *)entity recursively:(BOOL)recursively {
	if ([_contents containsObject:entity])
		return YES;
	
	if (recursively) {
		NSEnumerator *e = [_contents objectEnumerator];
		CPEntity *child;
		while (child = [e nextObject]) {
			if ([child containsChild:entity recursively:YES])
				return YES;
		}
	}
	
	return NO;
}


#pragma mark -
#pragma mark Capability specification methods

- (BOOL)canAddChild:(CPEntity *)entity fromSource:(CPEntity *)source {
	return source && _editable;
}

- (BOOL)canMoveChild:(CPEntity *)entity toDestination:(unsigned)destinationIndex {
	return _editable;
}

- (BOOL)canRemoveChild:(CPEntity *)entity {
	return _editable;
}


#pragma mark -
#pragma mark Child change notification handling methods

- (void)childChanged:(NSNotification *)notification {
	// Avoid cycles (just in case)
	if ([notification object] == self)
		return;

	// Rebroadcast change, notifying the world that this object has changed as well
	[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
														object:self];
}


#pragma mark -
#pragma mark Icon management helper class method

+ (NSImage *)scaledIcon:(NSImage *)icon {
	NSImage *scaledIcon = [[[NSImage alloc] initWithSize:NSMakeSize(ENTITY_ICON_SIZE, ENTITY_ICON_SIZE)] autorelease];
	
	if (icon) {
		[scaledIcon lockFocus];
		[icon drawInRect:NSMakeRect(0.0, 0.0, ENTITY_ICON_SIZE, ENTITY_ICON_SIZE)
				fromRect:NSZeroRect
			   operation:NSCompositeSourceOver
				fraction:1.0];
		[scaledIcon unlockFocus];
	}
	
	return scaledIcon;
}

@end
