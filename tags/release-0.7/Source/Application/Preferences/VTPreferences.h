/******************************************************************************
* 
* VirtueDesktops 
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller 
* playback@users.sourceforge.net
*
* See COPYING for licensing details
* 
*****************************************************************************/ 

#import <Cocoa/Cocoa.h>

#pragma mark Virtue Application
#define VTVirtueWelcomeShown				@"VTVirtueWelcomeShown"
#define VTVirtueCheckUIScripting            @"VTVirtueCheckUIScripting"
#define VTVirtueWarnBeforeQuitting			@"VTVirtueWarnBeforeQuitting"
#define VTVirtueShowStatusbarMenu			@"VTVirtueShowStatusbarMenu"
#define VTVirtueShowStatusbarDesktopName	@"VTVirtueShowStatusbarDesktopName"
#define VTVirtueShowDockIcon				@"VTVirtueShowDockIcon"

#pragma mark -
#pragma mark Desktop Transitions
#define VTDesktopTransitionEnabled			@"VTDesktopTransitionEnabled"
#define VTDesktopTransitionType				@"VTDesktopTransitionType"
#define VTDesktopTransitionOptions			@"VTDesktopTransitionOptions"
#define VTDesktopTransitionDuration			@"VTDesktopTransitionDuration"

#define VTDesktopTransitionNotifyEnabled	@"VTDesktopTransitionNotifyEnabled"
#define VTDesktopTransitionNotifyDuration	@"VTDesktopTransitionNotifyDuration"
#define VTDesktopTransitionNotifyApplets	@"VTDesktopTransitionNotifyApplets"

#pragma mark -
#pragma mark Desktop follows application
#define VTDesktopFollowsApplicationFocus			@"VTDesktopFollowsApplicationFocus"
#define VTDesktopFollowsApplicationFocusModifier	@"VTDesktopFollowsApplicationFocusModifier"

#pragma mark -
#pragma mark Window adoption
#define VTWindowsCollectOnQuit				@"VTWindowsCollectOnQuitEnabled"
#define VTWindowsCollectOnDelete			@"VTWindowsCollectOnDeleteEnabled"
#define VTFollowWindowsOnMove				@"VTFollowWindowsOnMove"

#pragma mark -
#pragma mark Hotkeys 
#define VTHotkeys							@"VTHotkeys"

#pragma mark -
#pragma mark Layouts 
#define VTLayouts							@"VTLayouts"

#pragma mark -
#pragma mark Active Edges 
#define VTActiveEdgesEnabled				@"VTActiveEdgesEnabled"
#define VTActiveEdgesVerticalEnabled		@"VTActiveEdgesVerticalEnabled"
#define VTActiveEdgesVerticalModifier		@"VTActiveEdgesVerticalModifier"
#define VTActiveEdgesHorizontalEnabled		@"VTActiveEdgesHorizontalEnabled"
#define VTActiveEdgesHorizontalModifier		@"VTActiveEdgesHorizontalModifier"

#pragma mark -
#pragma mark Operations 
#define VTOperationsTint					@"VTOperationsTintWindow"
#define VTOperationsTintColor				@"VTOperationsTintWindowColor"
#define VTOperationsAnimateSending			@"VTOperationsAnimateSending" 
#define VTOperationsAnimateSendingDuration	@"VTOperationsAnimateSendingDuration"

#pragma mark -
#pragma mark System Integration
#define VTMailClient                        @"VTMailClient"

#pragma mark -
@interface VTPreferences : NSObject {
}

+ (void) registerDefaults; 

@end
