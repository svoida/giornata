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
#import "VTDesktopLayout.h" 
#import "VTPagerCell.h" 

@interface VTPagerView : NSView {
	NSColor*		mBackgroundColor;
	NSColor*		mBackgroundHighlightColor; 
	NSColor*		mTextColor; 
	
	NSMatrix*		mPagerCells;
	NSMutableArray*	mTrackingRects; 
	
	VTPagerCell*		mCurrentDraggingTarget; 
	VTDesktopLayout*	mLayout; 
}

#pragma mark -
#pragma mark Lifetime 
- (id) initWithFrame: (NSRect) frame forLayout: (VTDesktopLayout*) layout; 
- (void) dealloc; 

#pragma mark -
#pragma mark Attributes 
- (void) setSelectedDesktop: (PNDesktop*) desktop; 
- (PNDesktop*) selectedDesktop; 

#pragma mark -
- (NSMatrix*) desktopCollectionMatrix; 

#pragma mark -
- (void) setTextColor: (NSColor*) color; 
- (NSColor*) textColor; 
- (void) setBackgroundColor: (NSColor*) color; 
- (NSColor*) backgroundColor; 
- (void) setBackgroundHighlightColor: (NSColor*) color; 
- (NSColor*) backgroundHighlightColor; 

@end
