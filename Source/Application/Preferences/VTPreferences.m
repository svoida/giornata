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

#import "VTPreferences.h"
#import "NSuserDefaultsColor.h" 

#define VT_ENSURE_COLOR(prefName, color)										\
if ([[NSUserDefaults standardUserDefaults] colorForKey: prefName] == nil)		\
[[NSUserDefaults standardUserDefaults] setColor: color forKey: prefName];

@implementation VTPreferences

+ (void) registerDefaults {
	static BOOL s_bRegistered = NO; 

	if (s_bRegistered == YES) {
		return;
	} 

	[NSColor setIgnoresAlpha: NO]; 	

	// create the default preferences 
	NSDictionary* defaultPreferences = [NSDictionary dictionaryWithObjectsAndKeys:
		
		// Application 
		@"YES",	VTVirtueWarnBeforeQuitting,
        @"YES", VTVirtueCheckUIScripting,
		@"YES", VTVirtueShowStatusbarMenu,
		
		// Desktop transition
		@"YES", VTDesktopTransitionEnabled,
		@"9",   VTDesktopTransitionType,
		@"0.5", VTDesktopTransitionDuration,
		
		// Desktop transition notification
		@"YES", VTDesktopTransitionNotifyEnabled, 
		@"2.5", VTDesktopTransitionNotifyDuration,
		
		// Desktop activation based on application focus 
		@"NO",  VTDesktopFollowsApplicationFocus,
		@"0",   VTDesktopFollowsApplicationFocusModifier,
		
		// Window collecting
		@"YES", VTWindowsCollectOnQuit, 
		@"YES", VTWindowsCollectOnDelete,
		@"NO",  VTFollowWindowsOnMove,
        
        // System integration
        @"1",   VTMailClient,
    
		// the end 
		nil
		];

	// register them with the NSUserDefaults instance 
	[[NSUserDefaults standardUserDefaults] registerDefaults: defaultPreferences];

	// ensure color values are written to defaults 
	VT_ENSURE_COLOR(VTOperationsTintColor, [NSColor colorWithCalibratedRed: 0.39 green: 0.39 blue: 0.39 alpha: 0.6]); 
	[[NSUserDefaults standardUserDefaults] synchronize];

	s_bRegistered = YES; 
}

@end
