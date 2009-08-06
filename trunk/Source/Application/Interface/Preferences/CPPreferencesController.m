//
//  CPPreferencesController.m
//  Giornata
//
//  Created by Stephen Voida on 2/12/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import "CPPreferencesController.h"

#import "CPController.h"

// Static array to map UI positions in the nib to frequency values (in seconds)
// (this needs to be kept up-to-date if the nib file changes!)
static const int CHECK_FREQUENCIES[5] = {60, 180, 300, 600, -1};


#pragma mark -
@implementation CPPreferencesController

#pragma mark -
#pragma mark NSPreferencePane Delegate 

- (id)initWithBundle:(NSBundle *)bundle {
	self = [super initWithBundle:bundle];
	
	if (self)
		_displayWarning = NO;
	
	return self;
}

- (NSString*) mainNibName {
	return @"CPPreferences";
}

- (void) mainViewDidLoad {
    // Convert the stored check frequency to a UI index
    int currentFrequency = [[NSUserDefaults standardUserDefaults] integerForKey:kCPEmailCheckFrequency];
    int currentIndex = -1;
    unsigned counter;
    for (counter = 0; counter < sizeof(CHECK_FREQUENCIES) / sizeof(int); counter++)
        if (currentFrequency == CHECK_FREQUENCIES[counter])
            currentIndex = counter;
    
    // If we didn't retrieve a valid value, then reset it to the default
    if (currentIndex == -1) {
        NSLog(@"Discovered an invalid email check frequency in the user preferences file. Resetting to default value (5 minutes).");
        
        currentIndex = 2;
        [[NSUserDefaults standardUserDefaults] setInteger:CHECK_FREQUENCIES[[_emailCheckFrequencyButton indexOfSelectedItem]]
                                                   forKey:kCPEmailCheckFrequency];
    }
    
    // Set up the UI with the appropriate value
    [_emailCheckFrequencyButton selectItemAtIndex:currentIndex];
}

- (void) willUnselect {
}

#pragma mark -
#pragma mark Actions
- (IBAction)toggleWarning:(id)sender {
	[self willChangeValueForKey:@"displayWarning"];

	_displayWarning = !_displayWarning;
	
	[self didChangeValueForKey:@"displayWarning"];
}

- (IBAction)updateEmailCheckFrequency:(id)sender {
    // Modify the data in the user preferences; the Contact Palette handles the rest on the other side
    [[NSUserDefaults standardUserDefaults] setInteger:CHECK_FREQUENCIES[[_emailCheckFrequencyButton indexOfSelectedItem]]
                                               forKey:kCPEmailCheckFrequency];
}

- (IBAction)checkEmailNow:(id)sender {
    // Propagate the message to somebody who can actually do something about it
    [[CPController sharedInstance] checkForUnreadEmails:sender];
}

#pragma mark -
#pragma mark Attributes
- (BOOL)displayWarning {
	return _displayWarning;
}

@end
