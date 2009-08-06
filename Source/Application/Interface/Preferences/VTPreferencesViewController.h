/******************************************************************************
 * 
 * VirtueDesktops 
 *
 * A desktop extension for MacOS X
 *
 * Copyright 2007, Stephen Voida
 * Copyright 2004, Thomas Staller  
 * playback@users.sourceforge.net
 *
 * See COPYING for licensing details
 * 
 *****************************************************************************/ 

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/NSPreferencePane.h>

@interface VTPreferencesViewController : NSWindowController {
	// outlets 
	IBOutlet NSArrayController*	mPreferencePanesController; 
	IBOutlet NSBox*				mPreferencePaneContainer; 
	IBOutlet NSView*			mPreferencePaneLoading;
	IBOutlet NSTableView*		mPreferencePanesTable; 

	NSMutableArray*				mAvailablePreferencePanes;	//!< Array of dictionaries describing a preference pane
	NSMutableDictionary*		mToolbarItems;				//!< Available toolbar items 
	NSMutableDictionary*		mPreferencePanes;			//!< Available panes 
	NSPreferencePane*			mCurrentPane;				//!< Currently displayed pane 
}

- (void) addPreferencePane:(NSPreferencePane *)pane title:(NSString *)title description:(NSString *)description iconFilename:(NSString *)iconFilename;

@end
