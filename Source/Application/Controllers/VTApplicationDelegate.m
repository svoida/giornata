/******************************************************************************
*
* Virtue
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller playback@users.sourceforge.net
* Copyright 2005-2006, Tony Arnold tony@tonyarnold.com
*
* See COPYING for licensing details
*
*****************************************************************************/
#import <Sparkle/Sparkle.h>

#import "VTApplicationDelegate.h"

#import "fixExecutable.h"
#import "CPPreferencesController.h"
#import "DECInjector.h"
#import "FSMonitorController.h"
#import "NSFileManagerDesktopShuffle.h"
#import "NSUserDefaultsControllerKeyFactory.h"
#import "PNApplication.h"
#import "VTAppearancePreferencesController.h"
#import "VTApplicationController.h"
#import "VTApplicationPreferencesController.h"
#import "VTApplicationViewController.h"
#import "VTDesktopBackgroundHelper.h"
#import "VTDesktopController.h"
#import "VTDesktopViewController.h"
#import "VTHotkeyPreferencesController.h"
#import "VTNotifications.h"
#import "VTPreferences.h"
#import "VTPreferenceKeys.h"
#import "VTDesktopLayout.h"
#import "VTTriggerController.h"
#import "ZNMemoryManagementMacros.h"

enum
{
	kVtMenuItemMagicNumber			= 666,
	kVtMenuItemRemoveMagicNumber	= 667,
};

@interface VTApplicationDelegate (Private)
- (void) registerObservers;
- (void) unregisterObservers;
#pragma mark -
- (void) updateStatusItem;
- (void) updateDesktopsMenu;
#pragma mark -
- (void) showDesktopInspectorForDesktop: (PNDesktop*) desktop;
- (void) invalidateQuitDialog:(NSNotification *)aNotification;
#pragma mark -
- (BOOL) checkUIScripting;
@end


@implementation VTApplicationDelegate

#pragma mark -
#pragma mark Lifetime

- (id) init {
	if (self = [super init]) {
		// init attributes
		mStartedUp = NO;
		mConfirmQuitOverridden = NO;
		mStatusItem = nil;
		mStatusItemMenuDesktopNeedsUpdate = YES;
		[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
		
		NSLog(@"Giornata is starting up.");
		
		return self;
	}
	
	return nil;
}

- (void) dealloc {
	ZEN_RELEASE(mStatusItem);
	ZEN_RELEASE(mNotificationBezel);
	ZEN_RELEASE(mPreferenceController);
	ZEN_RELEASE(mOperationsController);
	ZEN_RELEASE(mApplicationWatcher);
	ZEN_RELEASE(mDesktopInspector);
	ZEN_RELEASE(mApplicationInspector);
	ZEN_RELEASE(mActiveDesktop);
	ZEN_RELEASE(mCPController);
	
	[[VTDesktopLayout sharedInstance] removeObserver: self forKeyPath: @"desktops"];
	[[VTDesktopController sharedInstance] removeObserver: self forKeyPath: @"desktops"];
	[[VTDesktopController sharedInstance] removeObserver: self forKeyPath: @"activeDesktop"];
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver: self
																 forKeyPath: [NSUserDefaultsController pathForKey: VTVirtueShowStatusbarDesktopName]];
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver: self
																 forKeyPath: [NSUserDefaultsController pathForKey: VTVirtueShowStatusbarMenu]];
	
	// TODO: Unload what were plugins
	
	[self unregisterObservers];
	[super dealloc];
}

#pragma mark -
#pragma mark Bootstrapping
- (void) bootstrap {
	// This registers us to recieve NSWorkspace notifications, even though we are have LSUIElement enabled
	[NSApplication sharedApplication];
  
	// Figure out if we're being restarted following a crash and set up a lock file for future crash tracking
	BOOL isBeingRestarted = [[NSFileManager defaultManager] fileExistsAtPath:[self lockFilePath]];
	if (!isBeingRestarted) {
		[[self versionString] writeToFile:[self lockFilePath] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
	} else
		NSLog(@"*** RESTARTING FROM PREVIOUS CRASH STATE ***");
  
	// Retrieve the current version of the DockExtension, and whether it is currently loaded into the Dock process
	int dockCodeIsInjected		= 0;
	int dockCodeMajorVersion	= 0;
	int dockCodeMinorVersion	= 0;
	dec_info(&dockCodeIsInjected,&dockCodeMajorVersion,&dockCodeMinorVersion);
  
	// Inject dock extension code into the Dock process if it hasn't been already
	if (dockCodeIsInjected != 1) {
		if (dec_inject_code() != 0) {
#if defined(__i386__) 
      if ([self checkExecutablePermissions] == NO) {
        
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText: NSLocalizedString(@"VTPermsNeedsAttention", @"Alert title")];
        [alert addButtonWithTitle: NSLocalizedString(@"VTPermsOKButton", @"Go ahead and fix permissions")];
        [alert addButtonWithTitle: NSLocalizedString(@"VTPermsIgnoreButton", @"Ignore the alert and continue without fixing permissions")];
        [alert setInformativeText: NSLocalizedString(@"VTPermsMessage", @"Longer description about what will happen")];
        [alert setAlertStyle: NSWarningAlertStyle];
        [alert setDelegate: self];
        if ([alert runModal] == NSAlertFirstButtonReturn) {
          [self fixExecutablePermissions: self];
        }
      }
#endif /* __i386__ */
			[[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"DockExtensionLoaded"];
		} else {
			[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"DockExtensionLoaded"];
		}
	}
	
	// Set-up default preferences
	[VTPreferences registerDefaults];

	// and ensure we have our version information in there
	[[NSUserDefaults standardUserDefaults] setObject: [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
											  forKey:@"VTPreferencesVirtueVersionName"];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// Only move stuff out of the way if it's a clean start (otherwise, we're essentially restoring state manually)
	if (!isBeingRestarted)
		[self sanitizeDesktop];
    
    // Check UI scripting, just so it's out of the way
    [self checkUIScripting];
	
	// Read our desktops from disk (if they exist), otherwise populate the defaults
	[VTDesktopController	sharedInstance];
	[[VTDesktopController	sharedInstance] deserializeDesktops];
	
	// Load and initialize Giornata "plugins"
	mCPController = [CPController sharedInstance];
	mActiveDesktop = [[ActiveDesktop alloc] init];
	
	// Create/Instantiate our controllers
	[VTDesktopBackgroundHelper	sharedInstance];
	[VTTriggerController        sharedInstance];
	[VTApplicationController    sharedInstance];
	[FSMonitorController		sharedInstance];
	
	mPreferenceController	= [[VTPreferencesViewController alloc] init];
	mOperationsController	= [[VTOperationsViewController alloc] init];
	mApplicationWatcher		= [[VTApplicationWatcherController alloc] init];
	mDesktopInspector		= [[VTDesktopViewController alloc] init];
	mApplicationInspector	= [[VTApplicationViewController alloc] init];
	
	// Interface controllers
	mNotificationBezel = [[VTNotificationBezel alloc] init];
	
	// Interface layout
	[VTDesktopLayout sharedInstance];
	
	// Decode application preferences…
	NSDictionary* applicationDict = [[NSUserDefaults standardUserDefaults] objectForKey: VTPreferencesApplicationsName];
	if (applicationDict)
		[[VTApplicationController sharedInstance] decodeFromDictionary: applicationDict];
	
	// Prep the preference panes
	NSPreferencePane *pane;
	pane = [[[VTApplicationPreferencesController alloc] initWithBundle:[NSBundle bundleForClass:[self class]]] autorelease];
	[mPreferenceController addPreferencePane:pane title:@"Application" description:@"Application preferences" iconFilename:@"iconApplicationPreferences.icns"];
	pane = [[[VTAppearancePreferencesController alloc] initWithBundle:[NSBundle bundleForClass:[self class]]] autorelease];
	[mPreferenceController addPreferencePane:pane title:@"Appearance" description:@"Appearance and Animation settings" iconFilename:@"imagePreferencesAppearance.tiff"];
	pane = [[[VTHotkeyPreferencesController alloc] initWithBundle:[NSBundle bundleForClass:[self class]]] autorelease];
	[mPreferenceController addPreferencePane:pane title:@"Triggers" description:@"Keyboard and Mouse Trigger settings" iconFilename:@"imageHotkeyPreferences.tiff"];
	pane = [[[CPPreferencesController alloc] initWithBundle:[NSBundle bundleForClass:[self class]]] autorelease];
	[mPreferenceController addPreferencePane:pane title:@"Contact Palette" description:@"Contact Palette appearance and content settings" iconFilename:@"person.png"];
	
	// …and scan for initial applications
	[[VTApplicationController sharedInstance] scanApplications];
	
    // TEMPORARY CODE: Remove the "Organize applications..." menu item from the status bar menu
    [mStatusItemMenu removeItemAtIndex:4];
    // END TEMPORARY CODE
    
	// Update status item
	[self updateStatusItem];
	
	// Update items within the status menu
	[self updateDesktopsMenu];
    
    mPresentationMode = NO;
    [mStatusItemPresentationModeItem setState:NSOffState];
	
	// Register observers
	[[VTDesktopLayout sharedInstance] addObserver: self forKeyPath: @"desktops" options: NSKeyValueObservingOptionNew context: NULL];
	
	[[VTDesktopController sharedInstance] addObserver: self forKeyPath: @"desktops" options: NSKeyValueObservingOptionNew context: NULL];
	
	[[VTDesktopController sharedInstance] addObserver: self forKeyPath: @"activeDesktop" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: NULL];
	
	[[[VTDesktopController sharedInstance] activeDesktop] addObserver: self forKeyPath: @"applications" options: NSKeyValueObservingOptionNew context: NULL];
	
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver: self forKeyPath: [NSUserDefaultsController pathForKey: VTVirtueShowStatusbarDesktopName] options: NSKeyValueObservingOptionNew context: NULL];
	
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver: self forKeyPath: [NSUserDefaultsController pathForKey: VTVirtueShowStatusbarMenu] options: NSKeyValueObservingOptionNew context: NULL];
	
	// Register private observers
	[self registerObservers];
	
	// We're all started up!
	mStartedUp = YES;
	[[NSNotificationCenter defaultCenter] postNotificationName:kVTApplicationStartedUp object:self];
  
  // If this is the first time the user has used VirtueDesktops, show a welcome screen to set the most important options.
  if ([[NSUserDefaults standardUserDefaults] boolForKey: VTVirtueWelcomeShown] == NO) {
    [mWelcomePanel center];
    [self showWelcomePanel: nil];
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey: VTVirtueWelcomeShown];
  }
}

- (NSString*) versionString {
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

#pragma mark -
#pragma mark Controllers

- (VTDesktopController*) desktopController {
	return [VTDesktopController sharedInstance];
}

#pragma mark -
#pragma mark Actions

- (IBAction) showPreferences: (id) sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	[mPreferenceController showWindow: self];
}

- (IBAction) togglePresentationMode: (id) sender {
    mPresentationMode = !(mPresentationMode);
    if (mPresentationMode)
        [mStatusItemPresentationModeItem setState:NSOnState];
    else
        [mStatusItemPresentationModeItem setState:NSOffState];

    // Do the heavy lifting in the CPController and ActiveDesktop sub-modules
    [mCPController fadePalettesToTransparent:mPresentationMode];
    [mActiveDesktop fadeToTransparent:mPresentationMode];
}

- (IBAction) showHelp: (id) sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	[[NSApplication sharedApplication] showHelp: sender];
}

#pragma mark -
- (IBAction) showDesktopInspector: (id) sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	[self showDesktopInspectorForDesktop: [[VTDesktopController sharedInstance] activeDesktop]];
}

- (IBAction) showApplicationInspector: (id) sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	[mApplicationInspector showWindow: sender];
}

- (IBAction) showStatusbarMenu: (id) sender {
	[self updateStatusItem];
}

- (IBAction) showWelcomePanel: (id) sender {
  [mWelcomePanel orderFront: self];
}

#pragma mark -
- (IBAction) sendFeedback: (id) sender {
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: [NSString stringWithFormat:@"mailto:svoida@gmail.com?subject=Giornata%%20Feedback%%20[%@]", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]]];
}

#pragma mark -
- (IBAction) deleteActiveDesktop: (id) sender {
    // Generate a warning and let users opt out...
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    if (NSRunAlertPanel(NSLocalizedString(@"VTActivityCloseWarning", @"Are you sure you want to close this activity?"),
                        NSLocalizedString(@"VTActivityCloseMessage", @"This action cannot be undone."),
                        NSLocalizedString(@"VTActivityCloseOKButton", @"Close Activity"),
                        NSLocalizedString(@"VTActivityCloseCancelButton", @"Cancel"),
                        nil) == NSAlertAlternateReturn)
        return;
    
	// fetch index of active desktop to delete
	int victimIndex = [[[VTDesktopController sharedInstance] desktops] indexOfObject: [[VTDesktopController sharedInstance] activeDesktop]];
	// and get rid of it
	[[VTDesktopController sharedInstance] removeObjectFromDesktopsAtIndex: victimIndex];
}

- (IBAction) addNewDesktop: (id) sender {
	// create a new desktop 
	PNDesktop*	newDesktop = [[VTDesktopController sharedInstance] desktopWithFreeId]; 
	
	// set up the desktop (initially it has no name)
	[newDesktop setTags:[NSArray array]]; 
	
	// and add it to our collection 
	[[VTDesktopController sharedInstance] insertObject: newDesktop inDesktopsAtIndex: [[[VTDesktopController sharedInstance] desktops] count]];
	[[VTDesktopController sharedInstance] activateDesktop: newDesktop];
}

- (BOOL) checkExecutablePermissions {
	NSDictionary	*applicationAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:[[NSBundle mainBundle] executablePath] traverseLink: YES];
	
	// We expect 2755 as octal (1517 as decimal, -rwxr-sr-x as extended notation)
	return ([applicationAttributes filePosixPermissions] == 1517 && [[applicationAttributes fileGroupOwnerAccountName] isEqualToString: @"procmod"]);
}

- (IBAction) fixExecutablePermissions: (id) sender {
	// If we were not able to inject code, with fix the executable by changing it's group to procmod (9) and by setting the set-group-ID-on-execution bit
	fixVirtueDesktopsExecutable([[[NSBundle mainBundle] executablePath] fileSystemRepresentation]);	
	
	[[NSUserDefaults standardUserDefaults] setBool: YES	forKey: @"PermissionsFixed"];
	// We override asking us whether we want to quit, because the user really doesn't have any choice.
	mConfirmQuitOverridden = YES;
	
	// Thanks to Allan Odgaard for this restart code, which is much more clever than mine was.
	setenv("LAUNCH_PATH", [[[NSBundle mainBundle] bundlePath] UTF8String], 1);
	system("/bin/bash -c '{ for (( i = 0; i < 3000 && $(echo $(/bin/ps -xp $PPID|/usr/bin/wc -l))-1; i++ )); do\n"
         "    /bin/sleep .2;\n"
         "  done\n"
         "  if [[ $(/bin/ps -xp $PPID|/usr/bin/wc -l) -ne 2 ]]; then\n"
         "    /usr/bin/open \"${LAUNCH_PATH}\"\n"
         "  fi\n"
         "} &>/dev/null &'");
	[[NSApplication sharedApplication] terminate:self];
    NSLog(@"Giornata exit value: 1");
    exit(1);
}

- (NSString *) lockFilePath {
	NSString *lockFileFolder = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
								 stringByAppendingPathComponent:@"Application Support"]
								stringByAppendingPathComponent:@"Giornata"];
	
	// Create an application support directory to hold the lock file (will just fail if it already exists)
	[[NSFileManager defaultManager] createDirectoryAtPath:lockFileFolder attributes:nil];
	
	return [lockFileFolder stringByAppendingPathComponent:@"Giornata.lock"];
}

- (void) sanitizeDesktop {
	// Check to make sure the desktop is clean before loading up the activity state
	if ([[NSFileManager defaultManager] visibleItemsOnDesktop] > 0) {
		// Prompt the user that there's stuff in the way
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText: NSLocalizedString(@"VTDesktopNeedsCleaning", @"Alert title")];
		[alert addButtonWithTitle: NSLocalizedString(@"VTDesktopCleanOKButton", @"Move items")];
		[alert addButtonWithTitle: NSLocalizedString(@"VTDesktopCleanQuitButton", @"Quit the program")];
		[alert setInformativeText: NSLocalizedString(@"VTDesktopCleanMessage", @"Longer description about what will happen")];
		[alert setAlertStyle: NSWarningAlertStyle];
		if ([alert runModal] == NSAlertSecondButtonReturn) {
			NSLog(@"TERMINATING: User opted not to move Desktop items out of the way.");
			[[NSApplication sharedApplication] terminate:self];
            NSLog(@"Giornata exit value: 2");
            exit(2);
		}
		
		// Move the stuff out of the way
		NSString *cleanupPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Previous Desktop Contents"];
		BOOL result = [[NSFileManager defaultManager] moveDesktopItemsToFolder:cleanupPath storeLocations:NO];
		if (!result) {
			alert = [[[NSAlert alloc] init] autorelease];
			[alert setMessageText: NSLocalizedString(@"VTDesktopCleanFailed", @"Alert title")];
			[alert addButtonWithTitle: NSLocalizedString(@"VTDesktopCleanFailedOKButton", @"Quit the program")];
			[alert setInformativeText: [NSString stringWithFormat:NSLocalizedString(@"VTDesktopCleanFailedMessage", @"Your files couldn't be moved and might be in %@"), @"the 'Previous Desktop Contents' folder in your home directory"]];
			[alert setAlertStyle: NSCriticalAlertStyle];
			[alert runModal];
			[[NSApplication sharedApplication] terminate:self];
            NSLog(@"Giornata exit value: 3");
            exit(3);
		}
	}
}

#pragma mark -
#pragma mark NSAlert delegate

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
  if (returnCode == NSAlertFirstButtonReturn) {
    [self fixExecutablePermissions: self];
  }
}


#pragma mark -
#pragma mark NSApplication delegates

- (void) applicationWillFinishLaunching: (NSNotification*) notification {}

- (void) applicationDidFinishLaunching: (NSNotification*) notification {
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	[self bootstrap];
}

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)sender {
	// Check if we are started up already
	if (mStartedUp == NO)
		return NSTerminateNow;
	
	// Check if we should confirm that we are going to quit
	if ([[NSUserDefaults standardUserDefaults] boolForKey: VTVirtueWarnBeforeQuitting] == YES && mConfirmQuitOverridden == NO) {
		[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
		
		// Display an alert to make sure the user knows what they are doing
		NSAlert* alertWindow = [[NSAlert alloc] init];
		
		// Set-up
		[alertWindow setAlertStyle:			NSInformationalAlertStyle];
		[alertWindow setMessageText:		NSLocalizedString(@"VTQuitConfirmationDialogMessage", @"Giornata is quitting")];
		[alertWindow setInformativeText:	NSLocalizedString(@"VTQuitConfirmationDialogDescription", @"Are you sure you want to quit?")];
		[alertWindow addButtonWithTitle:	NSLocalizedString(@"VTQuitConfirmationDialogCancel", @"Cancel")];
		[alertWindow addButtonWithTitle:	NSLocalizedString(@"VTQuitConfirmationDialogOK", @"Quit")];
        [alertWindow addButtonWithTitle:    NSLocalizedString(@"VTQuitConfirmationDialogOKForever", @"Quit, and don't ask again")];
		
		int returnValue = [alertWindow runModal];
		
		[alertWindow release];
		
		if (returnValue == NSAlertFirstButtonReturn)
			return NSTerminateCancel;
        
        // Don't bug the user again!
        if (returnValue == NSAlertThirdButtonReturn)
            [[NSUserDefaults standardUserDefaults] setBool: NO forKey: VTVirtueWarnBeforeQuitting];
	}
	
	// Begin shutdown by moving all windows to the current desktop
	if ([[NSUserDefaults standardUserDefaults] boolForKey: VTWindowsCollectOnQuit] == YES) {
		NSEnumerator*	desktopIter = [[[VTDesktopController sharedInstance] desktops] objectEnumerator];
		PNDesktop*		desktop		= nil;
		PNDesktop*		target		= [[VTDesktopController sharedInstance] activeDesktop];
		
		while ((desktop = [desktopIter nextObject])) {
			// Record which windows were where before moving them around
			[desktop updatePersistedWindowList];
			
			if ([desktop isEqual: target])
				continue;
			
			[desktop moveAllWindowsToDesktop: target];
		}
	}
	
	// Reset desktop picture to the default
	[[VTDesktopBackgroundHelper sharedInstance] setBackground: [[VTDesktopBackgroundHelper sharedInstance] defaultBackground]];
	
	// and write out preferences to be sure
	[[NSUserDefaults standardUserDefaults] synchronize];
	// persist desktops
	[[VTDesktopController sharedInstance] serializeDesktopsMovingContents:YES];
	// persist hotkeys
	[[VTTriggerController sharedInstance] synchronize];
	
	// Clear the "lock" file to indicate a clean shut down
	[[NSFileManager defaultManager] removeFileAtPath:[self lockFilePath] handler:nil];
	
	NSLog(@"Giornata has terminated.");
	
	return NSTerminateNow;
}

/**
* @brief	Called upon reopening request by the user
 *
 * This implementation will show the preferences window, maybe we can make the
 * action that should be carried out configurable, but for now this one is fine
 *
 */
- (BOOL) applicationShouldHandleReopen: (NSApplication*) theApplication hasVisibleWindows: (BOOL) flag {
	[self showPreferences: self];
	return NO;
}


- (BOOL) validateMenuItem:(id <NSMenuItem>)anItem {
	if (anItem == mStatusItemRemoveActiveDesktopItem) {
		// if the number of desktops is 1 (one) we will disable the entry, otherwise
		// enable it.
		int numberOfDesktops = [[[VTDesktopController sharedInstance] desktops] count];
		
		return (numberOfDesktops > 1);
	}
	
	return YES;
}

- (void) menuNeedsUpdate: (NSMenu*) menu {
	if (menu != mStatusItemMenu)
		return;
	
	// check if we need to update any menu entries and do so
	if (mStatusItemMenuDesktopNeedsUpdate)
		[self updateDesktopsMenu];
}

#pragma mark -
#pragma mark Targets

- (void) onMenuDesktopSelected: (id) sender {
	// fetch the represented object
	PNDesktop* desktop = [sender representedObject];
	
	// and activate
	[[VTDesktopController sharedInstance] activateDesktop: desktop];
}

#pragma mark -
#pragma mark Request Sinks

- (void) onSwitchToDesktopEast: (NSNotification*) notification {
	[[VTDesktopController sharedInstance] activateDesktopInDirection: kVtDirectionEast];
}

- (void) onSwitchToDesktopWest: (NSNotification*) notification {
	[[VTDesktopController sharedInstance] activateDesktopInDirection: kVtDirectionWest];
}

- (void) onAddDesktop: (NSNotification*) notification {
	[self addNewDesktop: self];
}

- (void) onDeleteDesktop: (NSNotification*) notification {
	[self deleteActiveDesktop: self];
}

- (void) onSwitchToDesktop: (NSNotification*) notification {
	PNDesktop* targetDesktop = [[notification userInfo] objectForKey: VTRequestChangeDesktopParamName];
	// ignore empty desktop parameters
	if (targetDesktop == nil)
		return;
	
	[[VTDesktopController sharedInstance] activateDesktop: targetDesktop];
}

- (void) onMoveApplicationToDesktopEast: (NSNotification*) notification {
	[self moveFrontApplicationInDirection: kVtDirectionEast];
}

- (void) onMoveApplicationToDesktopWest: (NSNotification*) notification {
	[self moveFrontApplicationInDirection: kVtDirectionWest];
}

- (void) moveFrontApplicationInDirection: (VTDirection) direction {
	PNDesktop* moveToDesktop = [[VTDesktopController sharedInstance] getDesktopInDirection: direction];
	PNDesktop* activeDesktop = [[VTDesktopController sharedInstance] activeDesktop];
	NSEnumerator* applicationIter = [[activeDesktop applications] objectEnumerator];
	PNApplication* application = nil;
	
	ProcessSerialNumber activePSN;
	OSErr result = GetFrontProcess(&activePSN);
	
	while (application = [applicationIter nextObject]) {
		ProcessSerialNumber currentPSN = [application psn];
		Boolean same;
		
		result = SameProcess(&activePSN, &currentPSN, &same);
		if (same == TRUE) {
			[application setDesktop: moveToDesktop];
			[[[VTDesktopController sharedInstance] activeDesktop] updateDesktop];
			[moveToDesktop updateDesktop];
			[[VTDesktopController sharedInstance] activateDesktop: moveToDesktop];
			result = SetFrontProcess(&currentPSN);
			return;
		}
	}
}

- (void) onSendWindowBack: (NSNotification*) notification {
	[[VTDesktopController sharedInstance] sendWindowUnderPointerBack];
}

#pragma mark -
- (void) onShowPager: (NSNotification*) notification {
	[[[VTDesktopLayout sharedInstance] pager] display: NO];
}

- (void) onShowPagerSticky: (NSNotification*) notification {
	[[[VTDesktopLayout sharedInstance] pager] display: YES];
}

#pragma mark -
- (void) onShowOperations: (NSNotification*) notification {
	[mOperationsController window];
	[mOperationsController display];
}

#pragma mark -
- (void) onShowDesktopInspector: (NSNotification*) notification {
	[self showDesktopInspector: self];
}

- (void) onShowPreferences: (NSNotification*) notification {
	[self showPreferences: self];
}

- (void) onShowApplicationInspector: (NSNotification*) notification {
	[self showApplicationInspector: self];
}



#pragma mark -
#pragma mark KVO Sinks

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)anObject change:(NSDictionary *)theChange context:(void *)theContext
{
	if ([keyPath isEqualToString: @"desktops"] || [keyPath isEqualToString: @"activeLayout"] || [keyPath isEqualToString: @"activeLayout.desktops"]) {
		mStatusItemMenuDesktopNeedsUpdate = YES;
	}
	else if ([keyPath isEqualToString: @"activeDesktop"]) {
		mStatusItemMenuDesktopNeedsUpdate = YES;
		
		PNDesktop* newDesktop = [theChange objectForKey: NSKeyValueChangeNewKey];
		PNDesktop* oldDesktop = [theChange objectForKey: NSKeyValueChangeOldKey];
    
		// unregister from the old desktop and reregister at the new one
		if (oldDesktop)
			[oldDesktop removeObserver: self forKeyPath: @"applications"];
		
		[newDesktop addObserver: self forKeyPath: @"applications" options: NSKeyValueObservingOptionNew context: NULL];
		
		[self updateStatusItem];
    
	}
	else if ([keyPath isEqualToString: @"applications"]) {
		mStatusItemMenuDesktopNeedsUpdate = YES;
	}
	else if ([keyPath hasSuffix: VTVirtueShowStatusbarMenu]) {
		[self updateStatusItem];
	}
	else if ([keyPath hasSuffix: VTVirtueShowStatusbarDesktopName]) {
		[self updateStatusItem];
	}
}

@end

#pragma mark -
@implementation VTApplicationDelegate (Private)

- (void) registerObservers {
	// register observers for requests
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onSwitchToDesktopEast:) name: VTRequestChangeDesktopToEastName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onSwitchToDesktopWest:) name: VTRequestChangeDesktopToWestName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onAddDesktop:) name: VTRequestAddDesktopName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onDeleteDesktop:) name: VTRequestDeleteDesktopName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onSwitchToDesktop:) name: VTRequestChangeDesktopName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onSendWindowBack:) name: VTRequestSendWindowBackName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onShowPager:) name: VTRequestShowPagerName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onShowPagerSticky:) name: VTRequestShowPagerAndStickName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onShowOperations:) name: VTRequestDisplayOverlayName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onShowDesktopInspector:) name: VTRequestInspectDesktopName object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onShowPreferences:) name: VTRequestInspectPreferencesName object: nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self selector: @selector(invalidateQuitDialog:) name: NSWorkspaceWillPowerOffNotification object: [NSWorkspace sharedWorkspace]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(invalidateQuitDialog:) name: SUUpdaterWillRestartNotification object:nil];
	
	/** observers for moving applications */
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onMoveApplicationToDesktopEast:) name: VTRequestApplicationMoveToEast object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onMoveApplicationToDesktopWest:) name: VTRequestApplicationMoveToWest object: nil];
	/** end of moving applications */
}

- (void) unregisterObservers {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
}

#pragma mark -

- (void) updateStatusItem {
	if ([[NSUserDefaults standardUserDefaults] boolForKey: VTVirtueShowStatusbarMenu] == YES) {
		// create if necessary
		if (mStatusItem == nil) {
			// set up the status bar and attach the menu
			NSStatusBar* statusBar = [NSStatusBar systemStatusBar];
			
			// fetch the item and prepare it
			mStatusItem = [[statusBar statusItemWithLength: NSVariableStatusItemLength] retain];
			
			// set up the status item
			[mStatusItem setMenu: mStatusItemMenu];
			[mStatusItem setImage: [NSImage imageNamed: @"imageGiornata.png"]];
			[mStatusItem setAlternateImage: [NSImage imageNamed: @"imageGiornataHighlighted.png"]];
			[mStatusItem setHighlightMode: YES];
		}
		
		// check if we should set the desktop name as the title
		if ([[NSUserDefaults standardUserDefaults] boolForKey: VTVirtueShowStatusbarDesktopName] == YES) {
			NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSFont labelFontOfSize: 0], NSFontAttributeName,
        [NSColor darkGrayColor], NSForegroundColorAttributeName,
        nil];
			
			NSString* title = [NSString stringWithFormat: @"[%@]", [[[VTDesktopController sharedInstance] activeDesktop] displayName]];
			NSAttributedString* attributedTitle = [[[NSAttributedString alloc] initWithString: title attributes: attributes] autorelease];
			
			[mStatusItem setAttributedTitle: attributedTitle];      
		}
		else {
			[mStatusItem setTitle: @""];
		}
	}
	else {
		if (mStatusItem) {
			// remove the status item from the status bar and get rid of it
			[[NSStatusBar systemStatusBar] removeStatusItem: mStatusItem];
			ZEN_RELEASE(mStatusItem);
		}
	}
}

- (void) updateDesktopsMenu {
	// we dont need to do this if there is no status item
	if (mStatusItem == nil)
		return;
	
	mStatusItemMenuDesktopNeedsUpdate = NO;
	
	// first remove all items that have no associated object
	NSArray*		menuItems		= [mStatusItemMenu itemArray];
	NSEnumerator*   menuItemIter	= [menuItems objectEnumerator];
	NSMenuItem*		menuItem		= nil;
	
	while (menuItem = [menuItemIter nextObject]) {
		// check if we should remove the item
		if ([[menuItem representedObject] isKindOfClass: [PNDesktop class]]) {
			[mStatusItemMenu removeItem: menuItem];
		}
	}
	
	// now we can read the items
	NSEnumerator*	desktopIter		= [[[[VTDesktopLayout sharedInstance] desktops] objectEnumerator] retain];
	NSString*		uuid			= nil;
	PNDesktop*		desktop			= nil;
	int				currentIndex	= 0;
	
	while (uuid = [desktopIter nextObject]) {
		// get desktop
		desktop = [[VTDesktopController sharedInstance] desktopWithUUID: uuid];
		
		// we will only include filled slots and skip empty ones
		if (desktop == nil)
			continue;
		
		menuItem = [[NSMenuItem alloc] initWithTitle: [desktop displayName]
                                              action: @selector(onMenuDesktopSelected:) keyEquivalent: @""];
		[menuItem setRepresentedObject: desktop];
		[menuItem setEnabled: YES];
		
		// decide on which image to set
		if ([desktop visible] == YES)
			[menuItem setImage: [NSImage imageNamed: @"imageDesktopActive.png"]];
		else
			[menuItem setImage: [NSImage imageNamed: @"imageDesktopPopulated.png"]];
		
		[mStatusItemMenu insertItem: menuItem atIndex: currentIndex++];
		// free temporary instance
		[menuItem release];
	}
	
	[desktopIter release];
}

#pragma mark -

- (void) showDesktopInspectorForDesktop: (PNDesktop*) desktop {
	// and activate ourselves
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	// show the window we manage there
	[[mDesktopInspector window] center];
	[mDesktopInspector window];
	[mDesktopInspector showWindowForDesktop: desktop];
}

#pragma mark -

- (void) invalidateQuitDialog:(NSNotification *)aNotification
{
	// If we're shutting down, logging out, restarting or auto-updating via Sparkle, we don't want to ask the user if we should quit. They have already made that decision for us.
	mConfirmQuitOverridden = YES;
}

#pragma mark -

- (BOOL) checkUIScripting {
    // We only need to do this once. If it's been done before and passed, the check, there's no sense in doing it again.
    if ([[NSUserDefaults standardUserDefaults] objectForKey:VTVirtueCheckUIScripting] == nil ||
        [[NSUserDefaults standardUserDefaults] boolForKey:VTVirtueCheckUIScripting] == YES) {
        
        // All of the UI is handled in the script, and, since it's not essential that this works, we'll leave
        // it up to the user to make the changes...we mostly just want to warn them if there's a problem...
        NSMutableString *scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Check UI Scripting.applescript"]];
        NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
        NSDictionary *errorDictionary;
        NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errorDictionary];
        [appleScript release];
        
        // Check and return the result
        if (result) {
            BOOL returnValue = (BOOL)[result booleanValue];
            // If we passed the test this time, don't bother checking again!
            if (returnValue == YES) {
                [[NSUserDefaults standardUserDefaults] setObject:@"NO"
                                                          forKey:VTVirtueCheckUIScripting];
             
                [[NSUserDefaults standardUserDefaults] synchronize];
            }            
            
            return returnValue;
        } else
            return NO;
    }
    
    return YES;
}

@end
