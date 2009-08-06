//
//  CPController.h
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//


#import <Cocoa/Cocoa.h>
@class CPRootGroup;
@class CPPalette;
@class PNDesktop;

#define kCPEmailCheckFrequency  @"CPEmailCheckFrequency"


@interface CPController : NSObject
{
	CPRootGroup *_rootGroup;
	CPPalette *_rootPalette;
	PNDesktop *_currentDesktop;
	NSTimer *_emailCheckTimer;
    
    BOOL _fadeToTransparent;
}

+ (CPController *)sharedInstance;

- (void)onDesktopDidChange:(NSNotification*)notification;
- (void)checkForUnreadEmails:(id)sender;
- (void)fadePalettesToTransparent:(BOOL)toTransparent;

@end
