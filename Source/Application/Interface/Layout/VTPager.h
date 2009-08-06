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
@class VTDesktopLayout;

@interface VTPager : NSObject {
	NSWindow*			mWindow; 
	VTDesktopLayout*	mLayout; 
	
	BOOL				mStick; 
	BOOL				mAnimates; 
	
	BOOL				mShowing;
    
    unsigned int        mInitialFlags;
}

#pragma mark -
#pragma mark Lifetime 
- (id) initWithLayout: (VTDesktopLayout*) layout; 
- (void) dealloc; 

#pragma mark -
#pragma mark Operations 
- (void) display: (BOOL) stick; 
- (void) hide; 

#pragma mark -
#pragma mark Attributes 
- (NSString*) name;
#pragma mark -
- (void) setBackgroundColor: (NSColor*) color; 
- (NSColor*) backgroundColor; 
#pragma mark -
- (void) setHighlightColor: (NSColor*) color; 
- (NSColor*) highlightColor; 
#pragma mark -
- (void) setDesktopNameColor: (NSColor*) color; 
- (NSColor*) desktopNameColor; 

@end
