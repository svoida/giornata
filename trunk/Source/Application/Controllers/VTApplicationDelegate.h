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

#import "ActiveDesktop.h"
#import "CPController.h"
#import "VTApplicationViewController.h" 
#import "VTApplicationWatcherController.h"
#import "VTDesktopCollectionViewController.h" 
#import "VTDesktopViewController.h"
#import "VTNotificationBezel.h" 
#import "VTOperationsViewController.h" 
#import "VTPreferencesViewController.h"

@interface VTApplicationDelegate : NSObject {
	// Outlets 
	IBOutlet NSMenu*		mStatusItemMenu; 
	IBOutlet NSMenuItem*	mStatusItemRemoveActiveDesktopItem; 
    IBOutlet NSMenuItem*    mStatusItemPresentationModeItem;
	IBOutlet NSTextField*	mVersionTextField;
	IBOutlet NSPanel*		mWelcomePanel;
	
	// Attributes 
	BOOL			mStartedUp; 
	BOOL			mConfirmQuitOverridden;
	NSStatusItem*	mStatusItem; 
	BOOL			mStatusItemMenuDesktopNeedsUpdate; 
	BOOL			mUpdatedDock;
    BOOL            mPresentationMode;
	
	// Controllers 
	VTPreferencesViewController*		mPreferenceController;
	VTOperationsViewController*			mOperationsController; 
	VTApplicationWatcherController*		mApplicationWatcher; 
	CPController*						mCPController;
	
	// Interface
	VTNotificationBezel*			mNotificationBezel; 
	VTDesktopViewController*		mDesktopInspector; 
	VTApplicationViewController*	mApplicationInspector; 
	ActiveDesktop*					mActiveDesktop;
}

- (NSString*) versionString;

#pragma mark -
#pragma mark Actions 
- (IBAction) showPreferences: (id) sender; 
- (IBAction) togglePresentationMode: (id) sender;
- (IBAction) showHelp: (id) sender; 

#pragma mark -
- (IBAction) showDesktopInspector: (id) sender; 
- (IBAction) showApplicationInspector: (id) sender; 
- (IBAction) showStatusbarMenu: (id) sender; 

#pragma mark -
- (IBAction) sendFeedback: (id) sender; 
- (IBAction) showWelcomePanel: (id) sender;

#pragma mark -
- (IBAction) deleteActiveDesktop: (id) sender; 
- (IBAction) addNewDesktop: (id) sender;
- (BOOL) checkExecutablePermissions;
- (IBAction) fixExecutablePermissions: (id) sender;
- (NSString *) lockFilePath;
- (void) sanitizeDesktop;
- (void) moveFrontApplicationInDirection: (VTDirection) direction;

@end
