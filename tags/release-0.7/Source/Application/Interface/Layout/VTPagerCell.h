/******************************************************************************
* 
* VirtueDesktops 
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller playback@users.sourceforge.net
* Copyright 2005-2006, Tony Arnold tony@tonyarnold.com
*
* See COPYING for licensing details
* 
*****************************************************************************/ 

#import <Cocoa/Cocoa.h>
#import "PNDesktop.h"
#import "VTDesktopController.h"

@interface VTPagerCell : NSActionCell {
	// attributes 
	PNDesktop*				mDesktop; 
	BOOL					mDraggingTarget; 
	// cached values 
	NSMutableDictionary*	mDesktopNameAttributes;
	// cached colors 
	NSColor*				mBorderColor;						//!< Border
	NSColor*				mBackgroundColor;					//!< Background 
	NSColor*				mBackgroundHighlightColor;			//!< Background when highlighted 
	// subcells 
	NSMutableArray*			mAppletCells; 
}

#pragma mark -
#pragma mark Lifetime 
- (id) init; 
- (id) initWithDesktop: (PNDesktop*) desktop; 

#pragma mark -
#pragma mark Attributes 
- (void) setDesktop: (PNDesktop*) desktop; 
- (PNDesktop*) desktop; 
#pragma mark -
- (void) setDraggingTarget: (BOOL) flag; 
- (BOOL) isDraggingTarget; 

#pragma mark -
- (void) setTextColor: (NSColor*) color; 
- (void) setBackgroundColor: (NSColor*) color; 
- (void) setBackgroundHighlightColor: (NSColor*) color; 
- (void) setBorderColor: (NSColor*) color;

#pragma mark -
#pragma mark Operations 
- (NSImage*) drawToImage; 

@end
