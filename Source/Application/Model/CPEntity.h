//
//  CPEntity.h
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define ENTITY_ICON_SIZE 32
#define kCPEntityChanged @"CPEntityChanged"


@interface CPEntity : NSObject <NSCoding> {
	NSString *_name;
	BOOL _editable;
	NSImage *_icon;
	NSMutableArray *_contents;
	int _badgeCount;
}

// Lifetime methods
- (id)initWithName:(NSString *)name editable:(BOOL)editable;

// Output representation methods
- (NSString *)toolTipText;
- (NSImage *)defaultIcon;

// Accessor methods
- (NSString *)name;
- (void)setName:(NSString *)name;
- (BOOL)isEditable;
- (NSImage *)icon;
- (void)setIcon:(NSImage *)icon;
- (int)badgeCount;
- (void)setBadgeCount:(int)badgeCount;

// Child management methods
- (unsigned)addChild:(CPEntity *)entity fromSource:(CPEntity *)source;
- (unsigned)insertChild:(CPEntity *)entity atIndex:(unsigned)insertionIndex fromSource:(CPEntity *)source;
- (CPEntity *)childAtIndex:(unsigned)childIndex;
- (void)moveChildFromIndex:(unsigned)sourceIndex toIndex:(unsigned)destinationIndex;
- (void)removeChild:(CPEntity *)entity;
- (void)removeChildAtIndex:(unsigned)childIndex;
- (BOOL)isEmpty;
- (unsigned)count;
- (BOOL)containsChild:(CPEntity *)entity recursively:(BOOL)recursively;

// Capability specification methods
- (BOOL)canAddChild:(CPEntity *)entity fromSource:(CPEntity *)source;
- (BOOL)canMoveChild:(CPEntity *)entity toDestination:(unsigned)destinationIndex;
- (BOOL)canRemoveChild:(CPEntity *)entity;

// Child change notification handling methods
- (void)childChanged:(NSNotification *)notification;

// Icon management helper class method
+ (NSImage *)scaledIcon:(NSImage *)icon;

@end
