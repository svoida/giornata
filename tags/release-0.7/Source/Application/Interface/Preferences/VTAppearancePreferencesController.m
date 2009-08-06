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

#import "VTAppearancePreferencesController.h"

#pragma mark -
@implementation VTAppearancePreferencesController

#pragma mark -
#pragma mark NSPreferencePane Delegate 

- (NSString*) mainNibName {
	return @"VTAppearancePreferences";
}

- (void) mainViewDidLoad {
}

- (void) willUnselect {
}

@end 

