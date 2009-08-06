//
//  CPPreferencesController.h
//  Giornata
//
//  Created by Stephen Voida on 2/12/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/NSPreferencePane.h> 

@interface CPPreferencesController : NSPreferencePane {
	BOOL _displayWarning;
    
    IBOutlet NSPopUpButton *_emailCheckFrequencyButton;
}

#pragma mark -
#pragma mark Actions
- (IBAction)toggleWarning:(id)sender;
- (IBAction)updateEmailCheckFrequency:(id)sender;
- (IBAction)checkEmailNow:(id)sender;

#pragma mark -
#pragma mark Attributes
- (BOOL)displayWarning;

@end
