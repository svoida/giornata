/*
 *  PlugInProtocol.h
 *  Giornata
 *
 *  Created by Development on 8/15/09.
 *  Copyright 2009 Stephen Voida. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "GiornataController.h"

@protocol GiornataPlugIn

// Initializes the plugin, giving a reference to the hosting AppController
- (void)pluginLoaded:(GiornataController *)controller;

// Returns the version of the interface you're implementing.
// Return 1 here or future versions may look for features you don't have!
- (unsigned)interfaceVersion;

// Returns the display name for the plug-in.
- (NSString *)displayName;

// Returns a brief description of what the plug-in does.
- (NSString *)description;

// Returns the view controller for the settings configuration view.
- (NSViewController *)plugInConfigurationViewController;

@end