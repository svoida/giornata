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

#import "VTPreferencesViewController.h"

#import "NSUserDefaultsColor.h"
#import "VTPreferences.h"
#import "VTTriggerController.h" 
#import "ZNMemoryManagementMacros.h"

#define		VTPreferencePaneName			@"VTPreferencePaneName"
#define		VTPreferencePaneHelpText		@"VTPreferencePaneHelpText"
#define		VTPreferencePaneImage			@"VTPreferencePaneImage"
#define		VTPreferencePaneInstance		@"VTPreferencePaneInstance"

@interface VTPreferencesViewController (Private)
- (void) showPreferencePane: (NSPreferencePane*) pane andAnimate: (BOOL) animate; 
@end

#pragma mark -
@interface VTPreferencesViewController (Visibility) 
- (void) showPreferencePane: (NSMutableDictionary*) preferencePane; 
- (NSMutableDictionary*) selectedPreferencePane; 
@end 

#pragma mark -
@implementation VTPreferencesViewController

#pragma mark -
#pragma mark Lifetime 

- (id) init {
	if (self = [super initWithWindowNibName: @"VTPreferences"]) {
		// preference panes array 
		mAvailablePreferencePanes	= [[NSMutableArray alloc] init]; 
		mCurrentPane				= nil; 
		
		return self; 
	}

	return nil; 
}

- (void) dealloc {
	[[self window] setDelegate: nil]; 
	ZEN_RELEASE(mCurrentPane); 
	ZEN_RELEASE(mAvailablePreferencePanes); 

	[super dealloc]; 
}

#pragma mark -
#pragma mark NSWindowController delegate  

- (void) windowDidLoad {
	// set content of our controller
	[mPreferencePanesController setContent: mAvailablePreferencePanes];
}

- (void) windowWillClose: (NSNotification*) notification {
	// send unselect notification 
	[mCurrentPane willUnselect]; 
	
	// write hotkeys 
	[[VTTriggerController sharedInstance] synchronize]; 
	// and write out preferences to be sure 
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[mCurrentPane didUnselect]; 
}

- (IBAction) showWindow: (id) sender {
	if (mCurrentPane) 
		[mCurrentPane willSelect]; 
	
	[super showWindow: sender];

	if (mCurrentPane)
		[mCurrentPane didSelect];
}

#pragma mark -
#pragma mark NSTableView delegate 
- (void) tableViewSelectionWillChange: (NSNotification*) aNotification { }

- (void) tableViewSelectionDidChange: (NSNotification*) aNotification {
	[self showPreferencePane: [self selectedPreferencePane]]; 
}

#pragma mark -
#pragma mark Preferences population
- (void) addPreferencePane:(NSPreferencePane *)pane title:(NSString *)title description:(NSString *)description iconFilename:(NSString *)iconFilename {
	// Create a dictionary entry to wrap up this pref pane
	NSMutableDictionary* preferencePaneDescriptor = [NSMutableDictionary dictionary]; 
	
	// Make sure the pane is ready internally
	[pane loadMainView];
	
	// Get the full path to the pane's icon
	NSString *imagePath = [[[pane bundle] resourcePath] stringByAppendingPathComponent:iconFilename];
	
	[preferencePaneDescriptor setObject:pane forKey:VTPreferencePaneInstance]; 
	[preferencePaneDescriptor setObject:title forKey:VTPreferencePaneName]; 
	[preferencePaneDescriptor setObject:description forKey:VTPreferencePaneHelpText]; 
	[preferencePaneDescriptor setObject:imagePath forKey:VTPreferencePaneImage]; 
	
	// and add it to our array
	[mAvailablePreferencePanes addObject: preferencePaneDescriptor]; 
}

@end 

#pragma mark -
@implementation VTPreferencesViewController(Private)

- (void) showPreferencePane: (NSPreferencePane*) pane andAnimate: (BOOL) animate {
	NSView* contentView = [[self window] contentView];
	NSView* oldView		= nil;
	
	if ([[contentView subviews] count]) 
		oldView = [[contentView subviews] objectAtIndex: 0];
	
	if (oldView == [pane mainView]) 
		return;
	
	NSRect newFrame = [[self window] frame];
	float newHeight = [[self window] frameRectForContentRect: [[pane mainView] frame]].size.height;
	newFrame.origin.y += newFrame.size.height - newHeight;
	newFrame.size.height = newHeight;
	
	// unselect old pane 
	if (mCurrentPane)
		[mCurrentPane willUnselect]; 
	
	if (oldView) 
		[oldView removeFromSuperview];
	
	if (mCurrentPane)
		[mCurrentPane didUnselect]; 
	
	[[self window] setFrame: newFrame display: YES animate: animate];
	
	ZEN_ASSIGN(mCurrentPane, pane); 
	
	if (mCurrentPane) {
		// select new pane 
		[mCurrentPane willSelect]; 
		[[[self window] toolbar] setSelectedItemIdentifier: [[mPreferencePanes allKeysForObject: mCurrentPane] objectAtIndex: 0]]; 
		[contentView addSubview: [pane mainView]];
		[[self window] setDelegate: pane]; 
		[mCurrentPane didSelect]; 
	}
	else {
		[[self window] setDelegate: self]; 
	}
}

@end

#pragma mark -
@implementation VTPreferencesViewController (Visibility) 

- (void) showPreferencePane: (NSMutableDictionary*) preferencePane {
	NSPreferencePane* pane = [preferencePane objectForKey: VTPreferencePaneInstance];

	[pane willSelect]; 
	[mCurrentPane willUnselect]; 
	
	[mPreferencePaneContainer setContentView: [pane mainView]]; 
	
	[mCurrentPane didUnselect]; 
	[pane didSelect]; 
	
	ZEN_ASSIGN(mCurrentPane, pane); 
}

- (NSMutableDictionary*) selectedPreferencePane {
	int selectionIndex = [mPreferencePanesController selectionIndex]; 
	
	// no selection, no primitive  
	if (selectionIndex == NSNotFound)
		return nil; 
	
	return [mAvailablePreferencePanes objectAtIndex: selectionIndex]; 
}

@end 
