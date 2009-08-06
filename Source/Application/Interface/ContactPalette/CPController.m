//
//  CPController.m
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import "CPController.h"

#import <AddressBook/ABAddressBook.h>
#import "../Widgets/AutohideWindowView.h"
#import "../../Model/CPModel.h"
#import "CPPalette.h"
#import "../Widgets/HUDWindow.h"
#import "NSUserDefaultsControllerKeyFactory.h"
#import "PNDesktop.h"
#import "PNNotifications.h"
#import "VTDesktopController.h"
#import "VTNotifications.h"

#define kCPUnreadChirp              @"CPUnreadChirp"
#define kCPUnreadReveal             @"CPUnreadReveal"

#define CPABUpdateInterval          1800.0

#define CPFadeAnimationFrameRate    15.0
#define CPFadeAnimationDuration     0.5


@interface CPController (Private)
- (void)_doFadeAnimationInThread:(id)sender;
@end


@implementation CPController

+ (void)initialize {
	// create and register the default preferences 
	NSDictionary* defaultPreferences = [NSDictionary dictionaryWithObjectsAndKeys:
		
		// Unread email parameters
		@"YES", kCPUnreadChirp,
		@"YES", kCPUnreadReveal,
        [NSNumber numberWithInt:1], kCPEmailCheckFrequency,
		
		// the end 
		nil
		];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultPreferences];
}

+ (CPController *)sharedInstance {
    static CPController* ms_INSTANCE = nil; 
    
    if (ms_INSTANCE == nil)
        ms_INSTANCE = [[CPController alloc] init]; 
    
    return ms_INSTANCE; 
}

- (id) init {
    self = [super init];
    if (self != nil) {
        // Set up the root group (static contents)
        _rootGroup = [[CPRootGroup alloc] init];
        
        // Pay attention to potential changes in the Address Book database
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onAddressBookDidChange:)
                                                     name:kABDatabaseChangedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onAddressBookDidChange:)
                                                     name:kABDatabaseChangedExternallyNotification
                                                   object:nil];
        
        // Load the variable contents for the active desktop
        _currentDesktop = [[[VTDesktopController sharedInstance] activeDesktop] retain];
        [_rootGroup setContents:[_currentDesktop loadContacts]];
        
        // Turn on, already!
        // Make a rect that's a reasonable size. (The autohider will position it for us)
        NSRect windowFrame = NSMakeRect(0.0, 0.0, 88.0, 750.0); 
        
        // Create the root palette; it does the rest
        _rootPalette = [[CPPalette alloc] initWithGroup:_rootGroup
                                                  frame:windowFrame
                                                 parent:nil
                                        initiallyHidden:NO];
        
        // Set up our email check timer
        if ([[NSUserDefaults standardUserDefaults] integerForKey:kCPEmailCheckFrequency] > 0)
            _emailCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[[NSUserDefaults standardUserDefaults] integerForKey:kCPEmailCheckFrequency]
                                                                 target:self
                                                               selector:@selector(checkForUnreadEmails:)
                                                               userInfo:nil
                                                                repeats:NO] retain];
        else
            _emailCheckTimer = nil;
        
        // Connect to the rest of the app
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onDesktopDidChange:)
                                                     name:kVTOnApplicationStartedUp
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onDesktopDidChange:)
                                                     name:kPnOnDesktopDidActivate
                                                   object:nil];
        
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                                  forKeyPath:[NSUserDefaultsController pathForKey:kCPEmailCheckFrequency]
                                                                     options:NSKeyValueObservingOptionNew
                                                                     context:NULL]; 
    }
    
    return self;
}


- (void) dealloc {
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if ([_emailCheckTimer isValid])
        [_emailCheckTimer invalidate];
	[_emailCheckTimer release];
	_emailCheckTimer = nil;
    
	if (_rootPalette != nil) {
		[_rootPalette release];
		_rootPalette = nil;
	}

	// Let any other threads that might be messing with the rootGroup finish before wiping it out
    @synchronized(self) {
        [_rootGroup release];
        _rootGroup = nil;
    }
	
	[_currentDesktop release];
	
	[super dealloc];
}

- (void)onDesktopDidChange:(NSNotification*)notification {
	// Swap our variable contents
	[_currentDesktop storeContacts:[_rootGroup contents]];
	PNDesktop *newDesktop = [[[VTDesktopController sharedInstance] activeDesktop] retain];
	[_currentDesktop release];
	_currentDesktop = newDesktop;
    [_rootGroup setContents:[newDesktop loadContacts]];
	
	// Reset the selection (prevents weird things from happening)
	[_rootPalette resetSelection];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    // Clear existing timer
    if ([_emailCheckTimer isValid])
        [_emailCheckTimer invalidate];
    [_emailCheckTimer release];
    _emailCheckTimer = nil;
    
    // and then create a new one of the proper length (unless the preference is to only check manually)
    if ([[NSUserDefaults standardUserDefaults] integerForKey:kCPEmailCheckFrequency] > 0)
        _emailCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[[NSUserDefaults standardUserDefaults] integerForKey:kCPEmailCheckFrequency]
                                                             target:self
                                                           selector:@selector(checkForUnreadEmails:)
                                                           userInfo:nil
                                                            repeats:NO] retain];
}

- (void)checkForUnreadEmails:(id)sender {
    NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init];
    
#if defined (DEBUG)
    NSLog(@"Checking for unread emails...");
#endif /* DEBUG */

	int newUnreadCount;
    
    // Thread safety, particularly with respect to checkForABUpdates:
    @synchronized(self) {
        newUnreadCount = [_rootGroup updateVariableBadgeCounts];
    }
	
	if (newUnreadCount > [_currentDesktop unreadCount] && [_currentDesktop unreadCount] >= 0) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kCPAutohideEnabled] &&
			[[NSUserDefaults standardUserDefaults] boolForKey:kCPUnreadReveal])
			[(AutohideWindowView *)[[_rootPalette window] contentView] revealNow];
		
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kCPUnreadChirp]) {
			NSSound *chord = [NSSound soundNamed:@"Chord.mp3"];
			[chord play];
		}
	}
	
	[_currentDesktop setUnreadCount:newUnreadCount];
    
	// Reestablish our timer for the next round (the interval might have changed since our last iteration)
    if ([_emailCheckTimer isValid])
        [_emailCheckTimer invalidate];
    [_emailCheckTimer release];
    _emailCheckTimer = nil;
    
    if ([[NSUserDefaults standardUserDefaults] integerForKey:kCPEmailCheckFrequency] > 0)
        _emailCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[[NSUserDefaults standardUserDefaults] integerForKey:kCPEmailCheckFrequency]
                                                             target:self
                                                           selector:@selector(checkForUnreadEmails:)
                                                           userInfo:nil
                                                            repeats:NO] retain];
    else
        _emailCheckTimer = nil;
    
    [tempPool release];
}

- (void)fadePalettesToTransparent:(BOOL)toTransparent {
    _fadeToTransparent = toTransparent;
    
    // Spin this off as a new thread so we can do a quick, naive animation
    [NSThread detachNewThreadSelector:@selector(_doFadeAnimationInThread:)
                             toTarget:self
                           withObject:nil];
}

@end


@implementation CPController (Private)

- (void)_doFadeAnimationInThread:(id)sender {
    NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init];
    
    // Make sure the user can see what's going on (otherwise, it's kind of mysterious)
    if (_fadeToTransparent)
        [_rootPalette performSelectorOnMainThread:@selector(preventAutohiding:) withObject:nil waitUntilDone:YES];
    
    // Double check that our constants haven't been set maliciously
    if (CPFadeAnimationDuration > 0.0 && CPFadeAnimationDuration > 0.0) {
        unsigned numberOfSteps = (unsigned)(CPFadeAnimationFrameRate * CPFadeAnimationDuration);
        float alphaStep = (_fadeToTransparent) ? (-1.0 / numberOfSteps) : (1.0 / numberOfSteps);
        float currentAlpha = (_fadeToTransparent) ? 1.0 : 0.0;
        
        unsigned currentStep = 0;
        while (currentStep < numberOfSteps) {
            currentStep++;
            currentAlpha += alphaStep;
            [_rootPalette setAlphaRecursively:currentAlpha];
            
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(1.0 / CPFadeAnimationFrameRate)]];
        }
    }
    
    // Make sure we're set at the proper value when we stop
    if (_fadeToTransparent)
        [_rootPalette setAlphaRecursively:0.0];
    else {
        [_rootPalette setAlphaRecursively:1.0];
        [_rootPalette performSelectorOnMainThread:@selector(allowAutohiding:) withObject:nil waitUntilDone:NO];
    }
    
    [tempPool release];
}

@end
