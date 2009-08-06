/******************************************************************************
* 
* VirtueDesktops 
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller 
* playback@users.sourceforge.net
*
* Copyright 2007, Stephen Voida
* svoida@cc.gatech.edu
*
* See COPYING for licensing details
* 
*****************************************************************************/ 

#import "VTDesktopLayout.h"

#import "VTDesktopController.h"
#import "ZNMemoryManagementMacros.h"


@interface VTDesktopLayout (Private)

- (unsigned int)indexOfDesktop:(PNDesktop*)desktop; 
- (void)synchronizeDesktopLayout; 

@end 


@implementation VTDesktopLayout

#pragma mark -
#pragma mark Lifetime 

+ (VTDesktopLayout *) sharedInstance {
	static VTDesktopLayout* ms_INSTANCE = nil; 
	
	if (ms_INSTANCE == nil)
		ms_INSTANCE = [[VTDesktopLayout alloc] init]; 
	
	return ms_INSTANCE; 
}

#pragma mark -

- (id)init {
	if (self = [super init]) {
		// fetch localized name for our layout 
		ZEN_ASSIGN_COPY(mName, NSLocalizedString(@"VTLayoutName", @"Simple Layout")); 
		
		// set up pager
		mPager = [[VTPager alloc] initWithLayout:self];
		
		// set up desktop layout 
		[self synchronizeDesktopLayout]; 
		
		// and listen to desktop changes 
		[[VTDesktopController sharedInstance] addObserver:self forKeyPath:@"desktops" options:NSKeyValueObservingOptionNew context:NULL]; 
		return self; 
	}
	
	return nil; 
}

- (void) dealloc {
	// no notifications anymore please 
	[[VTDesktopController sharedInstance] removeObserver:self forKeyPath:@"desktops"]; 
	
	ZEN_RELEASE(mDesktopLayout); 
	ZEN_RELEASE(mName); 
	
	[super dealloc]; 
}

#pragma mark -
#pragma mark Attributes 

- (NSString*) name {
	return mName; 
}

- (VTPager*) pager {
	return mPager;
}

- (NSArray*) desktops { 
	return mDesktopLayout; 
}

- (NSArray*) orderedDesktops { 
	// assemble new array containing our desktops in the correct order
	NSMutableArray* orderedDesktops = [NSMutableArray array]; 
	NSEnumerator*   desktopIter     = [mDesktopLayout objectEnumerator]; 
	NSString*       desktopUUID     = nil; 
	
	while (desktopUUID = [desktopIter nextObject]) {
		[orderedDesktops addObject:[[VTDesktopController sharedInstance] desktopWithUUID:desktopUUID]];
	}
	
	return orderedDesktops; 
}

// Always room for one more...
- (unsigned int) maximumNumberOfDesktops {
	return [[self desktops] count] + 1;
}

#pragma mark -
#pragma mark Actions

- (void)swapDesktopAtIndex:(unsigned int)firstIndex withIndex:(unsigned int)secondIndex {
	if (firstIndex == secondIndex)
		return; 
	
	[self willChangeValueForKey: @"desktops"]; 
	[self willChangeValueForKey: @"orderedDesktops"]; 
	
	NSString* uuidOfFirst	= [[[mDesktopLayout objectAtIndex: firstIndex] retain] autorelease]; 
	NSString* uuidOfSecond	= [[[mDesktopLayout objectAtIndex: secondIndex] retain] autorelease]; 
	
	[mDesktopLayout replaceObjectAtIndex:firstIndex withObject:uuidOfSecond]; 
	[mDesktopLayout replaceObjectAtIndex:secondIndex withObject:uuidOfFirst]; 
	
	[self didChangeValueForKey: @"orderedDesktops"]; 
	[self didChangeValueForKey: @"desktops"]; 
}

#pragma mark -
#pragma mark Queries 

- (PNDesktop*) desktopInDirection: (VTDirection) direction ofDesktop: (PNDesktop*) desktop {
	int desktopIndex = [self indexOfDesktop:desktop]; 
	
	if (direction == kVtDirectionEast)
		desktopIndex += 1;
	else if (direction == kVtDirectionWest)
		desktopIndex -= 1;
	else
		// we do not support other directions 
		return desktop; 
	
	// Check wrapping conditions
	if (desktopIndex < 0)
		desktopIndex = [mDesktopLayout count] - 1;
	if (desktopIndex == (int)[mDesktopLayout count])
		desktopIndex = 0;
	
	// Fetch the desktop that index is pointing to
	NSString* identifier = [mDesktopLayout objectAtIndex:desktopIndex];
	return [[VTDesktopController sharedInstance] desktopWithUUID:identifier]; 
}

- (VTDirection) directionFromDesktop: (PNDesktop*) referenceDesktop toDesktop: (PNDesktop*) desktop {
	// we need indices of both desktops... 
	unsigned int indexOfTarget		= [self indexOfDesktop:desktop]; 
	unsigned int indexOfReference   = [self indexOfDesktop:referenceDesktop]; 
	
	if (indexOfTarget > indexOfReference)
		return kVtDirectionEast;
	if (indexOfTarget < indexOfReference)
		return kVtDirectionWest;
	
	// If all else fails...
	return kVtDirectionNone; 
}

#pragma mark -
#pragma mark KVO Sink 

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
	if ([keyPath isEqualToString:@"desktops"]) {
		// sync our layout 
		[self synchronizeDesktopLayout]; 
	}
}

@end


@implementation VTDesktopLayout(Private)

#pragma mark -

- (unsigned int)indexOfDesktop:(PNDesktop*)desktop {
	return [mDesktopLayout indexOfObject:[desktop uuid]]; 
}

#pragma mark -

/**
* Synchronizes the desktop layout with the currently available desktops 
 */ 
- (void)synchronizeDesktopLayout {
	[self willChangeValueForKey:@"desktops"]; 
	[self willChangeValueForKey:@"orderedDesktops"]; 
	
	// resize and fill empty slots with null markers 
	NSMutableArray*	newLayout = [[NSMutableArray alloc] init]; 
	
	// And add each of the items that the desktop controller has available
	NSEnumerator*	desktopIter = [[[VTDesktopController sharedInstance] desktops] objectEnumerator];
	PNDesktop*		desktop = nil;
	while (desktop = [desktopIter nextObject])
		[newLayout addObject:[desktop uuid]];
	
	// now get rid of original 
	ZEN_RELEASE(mDesktopLayout); 
	// remember new 
	mDesktopLayout = newLayout; 
	
	[self didChangeValueForKey:@"orderedDesktops"];
	[self didChangeValueForKey:@"desktops"];
}

@end 
