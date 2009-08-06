/******************************************************************************
*
* VirtueDesktops framework
*
* Copyright 2004, Thomas Staller playback@users.sourceforge.net
* Copyright 2006, Tony Arnold tony@tonyarnold.com
*
* See COPYING for licensing details
*
*****************************************************************************/

#import <Cocoa/Cocoa.h>
#import "PNDesktop.h" 
#import "VTDesktopLayout.h" 


@interface VTDesktopController : NSObject {
	NSMutableArray*			_desktops; 
	NSMutableArray*			mApplications; 
	
	PNDesktop*				mPreviousDesktop; 
	PNDesktop*				mSnapbackDesktop; 
	
	NSString*				mDefaultDesktopBackgroundPath;
	
	BOOL					mExpectingBackgroundChange;
	
	BOOL					mFollowApps;
	NSTimer*				mFollowTimer;
}

#pragma mark -
#pragma mark Lifetime 

+ (VTDesktopController*) sharedInstance; 

#pragma mark -
#pragma mark Factories 

- (PNDesktop*) desktopWithFreeId; 
- (int) freeId; 
	
#pragma mark -
#pragma mark Attributes 

- (NSMutableArray*) desktops;
- (void) setDesktops: (NSArray*)newDesktops;
- (void) addInDesktops: (PNDesktop*) desktop; 
- (void) insertObject: (PNDesktop*) desktop inDesktopsAtIndex: (unsigned int) desktopIndex;
- (void) removeObjectFromDesktopsAtIndex: (unsigned int) desktopIndex;
- (void) sendWindowUnderPointerBack;

#pragma mark -
- (BOOL) canAdd;
- (BOOL) canDelete; 

#pragma mark -
- (PNDesktop*) activeDesktop; 
- (PNDesktop*) previousDesktop; 
- (PNDesktop*) snapbackDesktop; 

#pragma mark -
- (void) temporarilyFollowApplicationChanges;
- (void) stopFollowingApplicationChanges:(NSTimer *)timer;
- (BOOL) isTemporarilyFollowingApplicationChanges;

#pragma mark -
#pragma mark Querying 

- (PNDesktop*) desktopWithUUID: (NSString*) uuid; 
- (PNDesktop*) desktopWithIdentifier: (int) identifier; 
- (PNDesktop*) getDesktopInDirection: (VTDirection) direction;

#pragma mark -
#pragma mark Desktop switching 

- (void) activateDesktop: (PNDesktop*) desktop;
- (void) activateDesktop: (PNDesktop*) desktop usingTransition: (PNTransitionType) type withOptions: (PNTransitionOption) options withDuration: (float) duration; 
- (void) activateDesktopInDirection: (VTDirection) direction; 

#pragma mark -
#pragma mark Desktop persistency 

- (void) serializeDesktopsMovingContents:(BOOL)moveContents;
- (void) deserializeDesktops; 

#pragma mark -
#pragma mark Per-desktop storage helper
+ (NSString *) activityStorePath;

@end
