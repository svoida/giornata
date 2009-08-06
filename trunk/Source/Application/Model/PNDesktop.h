/******************************************************************************
* 
* Peony.Virtue 
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller 
* playback@users.sourceforge.net
*
* See COPYING for licensing details
* 
*****************************************************************************/ 

// cocoa includes 
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
// private cgs stuff
#import "CGSPrivate.h"
#import "VTCoding.h"

@class PNWindow;
@class PNApplication; 

/**
 * @brief	Desktop VTCoding constants
 *
 */\
#define kVtCodingShowsBackgroundImage     @"showsBackground"
#define kVtCodingTags                     @"tags"
#define kVtCodingBackgroundImage          @"backgroundImage"
#define kVtCodingDefaultBackgroundImage   @"usesDefaultBackgroundImage"
#define kVtCodingUUID                     @"UUID"
#define kVtCodingContacts				  @"contacts"
#define kVtCodingPersistedWindowList      @"persistedWindowList"

/**
 * @brief   Desktop switching Transitions
 *
 */ 
typedef enum {
	kPnTransitionAny		= -1,
	kPnTransitionNone		= CGSNone, 
	kPnTransitionFade, 
	kPnTransitionZoom,
	kPnTransitionReveal, 
	kPnTransitionSlide, 
	kPnTransitionWarpFade, 
	kPnTransitionSwap,
	kPnTransitionCube,
	kPnTransitionWarpSwitch,
	kPnTransitionFlip
} PNTransitionType; 

/**
 * @brief   Desktop transition parameters
 *
 */
typedef enum {
	kPnOptionAny			= -1, 
	kPnOptionDown			= CGSDown, 
	kPnOptionLeft,
	kPnOptionRight,
	kPnOptionInRight, 
	kPnOptionBottomLeft		= 5,
	kPnOptionBottomRight,		
	kPnOptionDownTopRight,		
	kPnOptionUp,					
	kPnOptionTopLeft,			
	kPnOptionTopRight,			
	kPnOptionUpBottomRight,		
	kPnOptionInBottom,			
	kPnOptionLeftBottomRight,	
	kPnOptionRightBottomLeft,	
	kPnOptionInBottomRight,		
	kPnOptionInOut				
} PNTransitionOption; 

enum
{
	kPnTransitionDurationDefault = 1
};

enum
{
	kPnDesktopInvalidId  = -1
}; 

enum
{
	kPnDesktopUnknownUnreadCount = -1
};

#pragma mark -

/**
 * @interface	PNDesktop
 * @brief		A collection of windows representing a window tree called 
 *				Workspace in Apple terminology
 *
 * This interface provides functionality to manipulate and collect windows
 * that belong to one desktop (a workspace) window tree. Since we do not 
 * own the workspace but provide a wrapper around existing functionality, 
 * this interface is but a wrapper. It is therefore possible to have
 * multiple desktop interfaces for the same workspace, no data between the
 * wrapper instances will be shared, e.g. if one of the instances gets assigned
 * a name, the other will keep its own. 
 *
 * @notify		kPnOnDesktopWillActivate
 *				Sent when the desktop is about to be activated 
 * @notify		kPnOnDesktopDidActivate 
 *				Sent when the desktop was activated
 * 
 */ 
@interface PNDesktop : NSObject<NSCopying,NSCoding,VTCoding>
{
	int						mDesktopId;			//!< The native workspace id of this desktop
	NSMutableArray*			mDesktopTags;		//!< Tags on the desktop
	NSMutableArray*			mWindows;			//!< List of windows managed by the desktop
	NSMutableDictionary*	mApplications;		//!< List of applications managed by the desktop indexed by pid
	
	NSString*				mDesktopBackgroundImagePath;
	BOOL					mShowsBackground;
	NSString*				mUUID;
	
	NSImage*				mThumbnail;
	NSMutableArray*			mContacts;
	NSMutableArray*			mPersistedWindowList;
	int						mUnreadCount;
}

#pragma mark -
#pragma mark Lifetime 

+ (id) desktopWithIdentifier: (int) identifier;
+ (id) desktopWithTags: (NSArray*) tags identifier: (int) identifier;

- (id) init; 
- (id) initWithTags: (NSArray*) tags identifier: (int) identifier uuid: (NSString *)uuid;

#pragma mark -
#pragma mark Attributes 

+ (int) activeDesktopIdentifier; 
+ (int) firstDesktopIdentifier; 

- (int) identifier; 
- (void) setIdentifier: (int) identifier; 

#pragma mark -
- (NSString*) displayName; 
- (NSArray*) tags;
- (void) setTags: (NSArray*) tags; 

#pragma mark -
- (void) setDesktopBackground: (NSString*) path;
- (NSString*) desktopBackground;

#pragma mark -
- (void) setShowsBackground: (BOOL) showsBackground;
- (BOOL) showsBackground;

#pragma mark -
- (NSString*) uuid;

#pragma mark -
- (NSArray*) windows;
- (NSArray*) applications;

#pragma mark -
- (BOOL) visible;

#pragma mark -
- (void) captureThumbnail;
- (NSImage*) thumbnail;

#pragma mark -
- (void) setUnreadCount: (int) unreadCount;
- (int) unreadCount;

#pragma mark -
- (void) updatePersistedWindowList;
- (BOOL) attemptToReparentWindow: (PNWindow*) window;

#pragma mark -
#pragma mark NSObject
- (BOOL) isEqual: (id) other; 
- (NSString*) description; 

#pragma mark -
#pragma mark Activation 
- (void) activate; 
- (void) activateWithTransition: (PNTransitionType) transition option: (PNTransitionOption) option duration: (float) seconds;

#pragma mark -
#pragma mark Window operations
- (void) moveAllWindowsToDesktop: (PNDesktop*) desktop;
- (void) orderWindowFront: (PNWindow*) window;
- (void) orderWindowBack: (PNWindow*) window;
- (void) sendWindowUnderPointerBack;

#pragma mark -
#pragma mark Updating 
- (void) updateDesktop; 
              
#pragma mark -
#pragma mark Queries 
- (PNWindow*) windowContainingPoint: (NSPoint) point;
- (PNWindow*) windowForId: (CGSWindow) window; 
- (PNApplication*) applicationForPid: (pid_t) pid;
- (PNWindow*) bottomMostWindow;

#pragma mark -
#pragma mark Contact management
- (void)storeContacts:(NSMutableArray *)contacts;
- (NSMutableArray *)loadContacts;

#pragma mark -
#pragma mark Desktop contents management
- (void)storeDesktopItems;
- (void)loadDesktopItems;

#pragma mark -
#pragma mark Desktop background
- (void) applyDesktopBackground;

@end 
