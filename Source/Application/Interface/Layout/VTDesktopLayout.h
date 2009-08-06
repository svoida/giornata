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

#import <Cocoa/Cocoa.h>
#import "PNDesktop.h" 
#import "VTPager.h" 

// types 
typedef enum {
	kVtDirectionNone		= FOUR_CHAR_CODE('DRno'),
	kVtDirectionEast		= FOUR_CHAR_CODE('DRe '), 
	kVtDirectionWest		= FOUR_CHAR_CODE('RDw '), 
} VTDirection; 

#pragma mark -
@interface VTDesktopLayout : NSObject {
	NSString*			mName; 
	NSMutableArray*		mDesktopLayout;
	VTPager*			mPager; 
}

#pragma mark -
#pragma mark Lifetime
+ (VTDesktopLayout *) sharedInstance;

#pragma mark -
#pragma mark Attributes 
- (NSString*) name; 
- (VTPager*) pager; 
- (NSArray*) desktops; 
- (NSArray*) orderedDesktops; 
- (unsigned int) maximumNumberOfDesktops;

#pragma mark -
#pragma mark Queries 
- (PNDesktop*) desktopInDirection: (VTDirection) direction ofDesktop: (PNDesktop*) desktop; 
- (VTDirection) directionFromDesktop: (PNDesktop*) referenceDesktop toDesktop: (PNDesktop*) desktop; 

#pragma mark -
#pragma mark - Actions
- (void)swapDesktopAtIndex:(unsigned int)firstIndex withIndex:(unsigned int)secondIndex;

@end
