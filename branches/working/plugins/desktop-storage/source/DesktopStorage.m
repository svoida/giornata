//
//  DesktopStorage.m
//  Giornata
//
//  Created by Development on 8/15/09.
//  Copyright 2009 Stephen Voida. All rights reserved.
//

#import "DesktopStorage.h"

@implementation DesktopStorage

- (void)pluginLoaded:(GiornataController *)controller;
{
	
}

- (unsigned)interfaceVersion;
{
	return 1;
}

- (NSString *)displayName;
{
	return @"Desktop Storage";
}

- (NSString *)description;
{
	return @"Provides activity-aware desktop storage region";
}

- (NSViewController *)plugInConfigurationViewController;
{
	return nil;
}

@end
