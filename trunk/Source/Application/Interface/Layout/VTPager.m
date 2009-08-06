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

#import "VTPager.h"

#import "NSColorString.h"
#import "NSUserDefaultsControllerKeyFactory.h"
#import "PNDesktop.h"
#import "PNWindow.h"
#import "VTPagerView.h" 
#import "VTDesktopController.h"
#import "VTTriggerController.h"
#import "ZNEffectWindow.h"
#import "ZNMemoryManagementMacros.h"

#pragma mark -
@interface VTPagerWindow : ZNEffectWindow 
- (BOOL) canBecomeKeyWindow; 
@end 

#pragma mark -
@interface VTPager (Private) 
- (void) createWindow; 

- (void) doDisplayWindow; 
- (void) doHideWindow; 
@end 

#pragma mark -
@implementation VTPager

#pragma mark -
#pragma mark Lifetime 

- (id) initWithLayout: (VTDesktopLayout*) layout {
	if (self = [super init]) {
		// attributes 
		ZEN_ASSIGN(mLayout, layout); 
		mWindow				= nil;
		mStick				= NO; 
		mAnimates			= YES; 
		mShowing			= NO;
        mInitialFlags       = 0;
		
		// initialize 
		[self createWindow]; 
		
		return self; 
	}
	
	return nil; 
}

- (void) dealloc {
	ZEN_RELEASE(mLayout); 
	ZEN_RELEASE(mWindow); 
	
	[super dealloc]; 
}

#pragma mark -
#pragma mark Attributes 
- (NSString*) name {
  return @"Simple Pager";
}

#pragma mark -
- (void) setBackgroundColor: (NSColor*) color {
	[[mWindow contentView] setBackgroundColor: color]; 
}

- (NSColor*) backgroundColor {
	return [[mWindow contentView] backgroundColor]; 
}

#pragma mark -
- (void) setHighlightColor: (NSColor*) color {
	[[mWindow contentView] setBackgroundHighlightColor: color]; 
}

- (NSColor*) highlightColor {
	return [[mWindow contentView] backgroundHighlightColor]; 
}

#pragma mark -
- (void) setDesktopNameColor: (NSColor*) color {
	[[mWindow contentView] setTextColor: color]; 
}

- (NSColor*) desktopNameColor {
	return [[mWindow contentView] textColor]; 
}


#pragma mark -
#pragma mark VTPager 

- (void) display: (BOOL) stick {
	mStick = stick;

	[self doDisplayWindow]; 
}

- (void) hide {
	[self doHideWindow];
}

#pragma mark -
#pragma mark NSWindow delegate 

- (void) windowDidResignKey: (NSNotification*) aNotification {
	// as soon as the window resigned key focus, we will close it 
	[self doHideWindow];
		
	// if we got a selected desktop, switch to it
	if ([(VTPagerView*)[mWindow contentView] selectedDesktop] == nil)
		return; 
	
	PNDesktop* desktop = [(VTPagerView*)[mWindow contentView] selectedDesktop]; 
	[[VTDesktopController sharedInstance] activateDesktop: desktop]; 
}

#pragma mark -
- (void) flagsChanged: (NSEvent*) event {
    // Ignore if sticky or if the shift key status changes
	if (mStick == NO &&
        ((([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) | NSShiftKeyMask | NSAlphaShiftKeyMask) !=
          ((mInitialFlags & NSDeviceIndependentModifierFlagsMask) | NSShiftKeyMask | NSAlphaShiftKeyMask)))
		[self doHideWindow];
}

- (void) keyDown: (NSEvent*) event {
	NSString*		characters	= [event charactersIgnoringModifiers]; 
	
	// Enter and Space: Will trigger switch to selected desktop 
	if (([characters characterAtIndex: 0] == NSEnterCharacter) ||
		([characters characterAtIndex: 0] == NSCarriageReturnCharacter) ||
		([characters characterAtIndex: 0] == 0x0020)) {
			
		[self doHideWindow];
		return; 
	}
	// Escape: Will trigger closing without switch, by setting the selected 
	// desktop to nil 
	if ([characters characterAtIndex: 0] == 0x001B) {
		[(VTPagerView*)[mWindow contentView] setSelectedDesktop: nil];
		[self doHideWindow];
		
		return; 
	}
}

#pragma mark -
#pragma mark Actions 

- (void) onDesktopSelected: (id) sender {
	// order out window, we will do the rest then... 
	[self doHideWindow];
}

@end

#pragma mark -
@implementation VTPager (Private) 

- (void) createWindow {
	// create our view 
	NSRect contentRect = NSZeroRect; 
	
	// create our view 
	VTPagerView* view = [[[VTPagerView alloc] initWithFrame: contentRect forLayout: mLayout] autorelease];
	// and attach ourselves as the target 
	[[view desktopCollectionMatrix] setTarget: self]; 
	[[view desktopCollectionMatrix] setAction: @selector(onDesktopSelected:)]; 
	
	// get the content rect from the view 
	contentRect = [view frame];
	
	// create the window 
	mWindow = [[VTPagerWindow alloc] initWithContentRect: contentRect 
											   styleMask: NSBorderlessWindowMask 
												 backing: NSBackingStoreBuffered
												   defer: NO];
	
	// set up the window as we need it 
	[mWindow setBackgroundColor: [NSColor clearColor]];
	[mWindow setOpaque: NO];
	[mWindow setIgnoresMouseEvents: NO];
	[mWindow setAcceptsMouseMovedEvents: YES]; 
	[mWindow setHasShadow: YES];
	[mWindow setReleasedWhenClosed: NO];
	
	// bind the view to the window  
	[mWindow setContentView: view];
	[mWindow setInitialFirstResponder: view]; 
	
	// now set alpha to 1 and level accordingly 
	[mWindow setAlphaValue: 1.0f]; 
	[mWindow setLevel: kCGUtilityWindowLevel]; 
	// set ourselves as the delegate 
	[mWindow setDelegate: self]; 
	
	// and make the window special to hide it
	[[PNWindow windowWithNSWindow: mWindow] setSpecial: YES];
	[[PNWindow windowWithNSWindow: mWindow] setSticky: YES];	
}

- (void) doDisplayWindow {
	mShowing = YES; 
	
	// we have to set position and size of the window...
	NSRect	windowFrame		= [mWindow frame]; 
		
    [mWindow center];
    windowFrame = [mWindow frame];
		
	// position the window off screen 
	[mWindow setFrame: windowFrame display: NO]; 
	
	// set desktop for view 
	[(VTPagerView*)[mWindow contentView] setSelectedDesktop: [[VTDesktopController sharedInstance] activeDesktop]]; 
	// force redisplay to be sure we are displaying the latest snapshot
	[[mWindow contentView] setNeedsDisplay: YES]; 
	
	// make our window the key window; we are being rude here and take away 
	// key from other applications and make ourselves the active application
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES]; 
	[(ZNEffectWindow*) mWindow setFadingAnimationTime: 0.0f]; 
	[(ZNEffectWindow*) mWindow fadeIn]; 
	
	// and disable all hotkeys 
	[[VTTriggerController sharedInstance] setEnabled: NO];
    
    // save the current modifier flags so we can figure out when to dismiss the pager
    mInitialFlags = [[[NSApplication sharedApplication] currentEvent] modifierFlags];
}

- (void) doHideWindow {
	if (mShowing == NO)
		return; 	
	mShowing = NO; 

	// reactivate hotkeys 
	[[VTTriggerController sharedInstance] setEnabled: YES]; 

	PNDesktop* selectedDesktop = [(VTPagerView*)[mWindow contentView] selectedDesktop]; 
	
	// if we have a selected desktop, we order out immediately as we will switch
	// desktops and there is no time to fade out
	if ((selectedDesktop != nil) && (selectedDesktop != [[VTDesktopController sharedInstance] activeDesktop])) {
		[(ZNEffectWindow*)mWindow setFadingAnimationTime: 0.0f]; 
		[(ZNEffectWindow*)mWindow fadeOut]; 
		
		return; 
	}
	
	// otherwise, smoothly fade out the window 
	[(ZNEffectWindow*)mWindow setFadingAnimationTime: 0.2f]; 
	[(ZNEffectWindow*)mWindow fadeOut]; 
}

#pragma mark -
#pragma mark ZNEffectWindow Delegate 

- (void) windowDidFadeIn: (NSNotification*) notification {
	[[notification object] makeKeyAndOrderFront: self]; 
}

- (void) windowDidFadeOut: (NSNotification*) notification {
	[[notification object] orderOut: self]; 
}

@end 

#pragma mark -
@implementation VTPagerWindow

/**
 * Have to work around the Cocoa default implementation that disallows windows 
 * without title bar to become the key window.. so we will override the guilty 
 * method and return YES here 
 *
 */ 
- (BOOL) canBecomeKeyWindow {
	return YES; 
}

/**
 * TODO: Fixme
 * Note that this is a workaround, as I thought those events from the NSResponder
 * walk up the responder chain automagically if not handled; maybe something done
 * in the VTPagerView is wrong and breaks the chain? 
 * 
 */ 
- (void) flagsChanged: (NSEvent*) event {
	[[self delegate] flagsChanged: event]; 
}

- (void) keyDown: (NSEvent*) event {
	[[self delegate] keyDown: event]; 
}

@end 
