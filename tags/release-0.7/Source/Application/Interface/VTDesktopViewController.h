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
#import "VTImageViewFileDropper.h" 
#import "VTHotkeyTextField.h" 
#import "VTHotkeyTextView.h" 
#import "VTHotkeyCell.h"
#import "VTDesktopLayout.h"

@interface VTDesktopViewController : NSWindowController {
	// Outlets
	IBOutlet NSTableView*				mDesktopsTableView;
	IBOutlet NSArrayController*			mDesktopsController; 
	IBOutlet VTImageViewFileDropper*	mImageView;
  
	// Instance variables 
	PNDesktop*				mDesktop;			//!< The model we are dealing with 
	NSMutableArray*			desktops;
}

#pragma mark -
#pragma mark Attributes 
- (PNDesktop*) desktop; 

#pragma mark -
#pragma mark Actions 
- (IBAction) addDesktop: (id) sender; 
- (IBAction) deleteDesktop: (id) sender; 
- (void) showWindowForDesktop: (PNDesktop*) desktop; 

#pragma mark -
#pragma mark Accessors
- (VTDesktopLayout*) activeDesktopLayout;

@end
