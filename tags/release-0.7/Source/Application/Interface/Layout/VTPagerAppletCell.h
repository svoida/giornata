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
#import "PNApplication.h"

@interface VTPagerAppletCell : NSImageCell {
	PNApplication* mApplication; 
}

#pragma mark -
#pragma mark Lifetime 
- (id) init; 
- (id) initWithApplication: (PNApplication*) application; 

#pragma mark -
#pragma mark Attributes 
- (PNApplication*) application; 
- (void) setApplication: (PNApplication*) application; 

@end
