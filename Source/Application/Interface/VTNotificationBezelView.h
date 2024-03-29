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


@interface VTNotificationBezelView : NSView {
	NSShadow*				mShadow;			//!< Shadow for application icons 
	NSMutableDictionary*	mTextAttributes;	//!< Attributes for desktop name text 
	
	NSString*	mText; 
	PNDesktop*	mDesktop; 
	BOOL		mDrawApplets; 
}

#pragma mark -
#pragma mark Lifetime 

- (id) initWithFrame: (NSRect) frame; 
- (void) dealloc; 

#pragma mark -
#pragma mark Attributes 

- (void) setText: (NSString*) text; 
- (void) setDesktop: (PNDesktop*) desktop; 

- (void) setDrawsApplets: (BOOL) flag; 
- (BOOL) drawsApplets; 

@end
