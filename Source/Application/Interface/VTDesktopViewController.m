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

#import "VTDesktopViewController.h"

#import "VTApplicationRunningCountTransformer.h"
#import "VTDesktopBackgroundHelper.h"
#import "VTDesktopController.h"
#import "VTNotifications.h"
#import "ZNMemoryManagementMacros.h"

#define kVtMovedRowsDropType @"VIRTUE_DESKTOP_COLLECTION_MOVE"

@interface VTDesktopViewController (Selection) 
- (PNDesktop*) selectedDesktop; 
- (void) setSelectedDesktop: (PNDesktop*) desktop;
- (void) showDesktop: (PNDesktop*) desktop; 
@end 

#pragma mark -
@implementation VTDesktopViewController

+ (void) initialize {
	NSValueTransformer* transformer = [[[VTApplicationRunningCountTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer: transformer
									forName: @"VTApplicationRunningCountTransformer"];
}

#pragma mark -
#pragma mark Lifetime 

- (id) init {
	if (self = [super initWithWindowNibName: @"VTDesktopInspector"]) {		
		return self;
	}
	
	return nil;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self]; 	
	
	ZEN_RELEASE(mDesktop); 
	
	[super dealloc]; 
}

#pragma mark -
#pragma mark Actions 
- (IBAction) addDesktop: (id) sender {
	// create a new desktop 
	PNDesktop*	newDesktop = [[VTDesktopController sharedInstance] desktopWithFreeId]; 
	
	// set up the desktop 
	[newDesktop setTags: [NSArray array]]; 
	
	// and add it to our collection 
	[[VTDesktopController sharedInstance] insertObject: newDesktop inDesktopsAtIndex: [[[VTDesktopController sharedInstance] desktops] count]];
	[mDesktopsController setSelectionIndex: [[[VTDesktopController sharedInstance] desktops] indexOfObject: newDesktop]];
}

- (IBAction) deleteDesktop: (id) sender {
	PNDesktop* desktop	= [self selectedDesktop]; 
	unsigned desktopIndex	= [[[VTDesktopController sharedInstance] desktops] indexOfObject: desktop]; 
	
    // Generate a warning and let users opt out...
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    if (NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"VTActivityCloseWarningNamed", @"Are you sure you want to close this activity?"), [desktop displayName]],
                        NSLocalizedString(@"VTActivityCloseMessage", @"This action cannot be undone."),
                        NSLocalizedString(@"VTActivityCloseOKButton", @"Close Activity"),
                        NSLocalizedString(@"VTActivityCloseCancelButton", @"Cancel"),
                        nil) == NSAlertAlternateReturn)
        return;
    
	// remove the selected desktop 
	[[VTDesktopController sharedInstance] removeObjectFromDesktopsAtIndex: desktopIndex];
	[mDesktopsController rearrangeObjects];
  
	if ([[[VTDesktopController sharedInstance] desktops] count] > desktopIndex) {
		[mDesktopsController setSelectionIndex: desktopIndex];
	} else {
		[mDesktopsController setSelectionIndex: [[[VTDesktopController sharedInstance] desktops] count] - 1];
  }
}

- (IBAction) showWindow: (id) sender {
	[self showWindowForDesktop: [[VTDesktopController sharedInstance] activeDesktop]]; 
}

- (void) showWindowForDesktop: (PNDesktop*) desktop {
	[self setSelectedDesktop: desktop];
	[super showWindow: self]; 
}

#pragma mark -
#pragma mark Attributes 

- (PNDesktop*) desktop {
	return mDesktop; 
}

#pragma mark -
#pragma mark Accessors

- (VTDesktopLayout*) activeDesktopLayout {
	return [VTDesktopLayout sharedInstance];	
}

#pragma mark -
#pragma mark NSWindowController overrides 

- (void) windowDidLoad {
	[[self window] setAcceptsMouseMovedEvents: YES]; 
	[[self window] setHidesOnDeactivate: NO];
	[[self window] setDelegate: self]; 
	
	// and select a desktop 
	[self showDesktop: [self selectedDesktop]];
  
	[mImageView bind: @"imagePath" toObject: mDesktop withKeyPath: @"desktopBackground" options: nil];
	[mDesktop bind: @"desktopBackground" toObject: mImageView withKeyPath: @"imagePath" options: nil];
}


#pragma mark -
#pragma mark NSWindow delegate 

- (void) windowWillClose: (NSNotification*) notification { 
	// and write out preferences to be sure 
	[[NSUserDefaults standardUserDefaults] synchronize]; 
	// and also the desktop settings 
	[[VTDesktopController sharedInstance] serializeDesktopsMovingContents:YES]; 
}

#pragma mark -
#pragma mark NSTableView delegate 

- (void) tableViewSelectionDidChange: (NSNotification*) notification {
	// Desktops table view
	if ([[notification object] isEqual: mDesktopsTableView]) 
		[self showDesktop: [self selectedDesktop]];
}

@end

#pragma mark -
@implementation VTDesktopViewController (Selection) 

- (PNDesktop*) selectedDesktop {
	int selectedIndex = [mDesktopsController selectionIndex];
	if (selectedIndex == NSNotFound)
		return nil; 
	
	return [[[VTDesktopLayout sharedInstance] orderedDesktops] objectAtIndex: selectedIndex]; 
}

- (void) setSelectedDesktop: (PNDesktop*) desktop {
	// get index of passed desktop
	unsigned int desktopIndex = [[[VTDesktopLayout sharedInstance] orderedDesktops] indexOfObject: desktop];
	// and select it in the table view
	[mDesktopsTableView selectRowIndexes: [NSIndexSet indexSetWithIndex: desktopIndex]
					byExtendingSelection: NO];
}

- (void) showDesktop: (PNDesktop*) desktop {
	[mImageView unbind: @"imagePath"];
	[mDesktop unbind: @"desktopBackground"];
	
	// attributes 
	ZEN_ASSIGN(mDesktop, desktop);

	[mImageView bind: @"imagePath" toObject: mDesktop withKeyPath: @"desktopBackground" options: nil];
	[mDesktop bind: @"desktopBackground" toObject: mImageView withKeyPath: @"imagePath" options: nil];
}

@end
