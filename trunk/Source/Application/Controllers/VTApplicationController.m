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

#import "VTApplicationController.h"

#import "PNNotifications.h"
#import "VTDesktopController.h" 
#import "ZNMemoryManagementMacros.h"

#define kVtCodingApplications	@"applications"

@interface VTApplicationController (KVO)

- (void) insertObjectInApplications: (VTApplicationWrapper*) wrapper atIndex: (unsigned int) index; 
- (void) removeObjectFromApplicationsAtIndex: (unsigned int) index; 
	
@end 

#pragma mark -
@interface VTApplicationController (Content) 

- (void) createApplications; 

@end 

#pragma mark -
@implementation VTApplicationController

+ (VTApplicationController*) sharedInstance {
	static VTApplicationController* ms_INSTANCE = nil; 
	
	if (ms_INSTANCE == nil) {
		ms_INSTANCE = [[VTApplicationController alloc] init]; 
	}
	
	return ms_INSTANCE; 
}

- (id) init {
	if (self = [super init]) {
		mApplications = [[NSMutableDictionary alloc] init]; 
		
		// and register for notifications about added and removed applications 
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onApplicationAttached:) name: PNApplicationWasAdded object: nil]; 
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onApplicationDetached:) name: PNApplicationWasRemoved object: nil]; 
		
		return self; 
	}
	
	return nil; 
}

- (void) dealloc {
	ZEN_RELEASE(mApplications); 
	
	[super dealloc]; 
}

- (void) scanApplications {
	[self createApplications]; 
}

#pragma mark -
#pragma mark Coding 

- (void) encodeToDictionary: (NSMutableDictionary*) dictionary {
	NSMutableArray*			applicationList	= [NSMutableArray array]; 
	NSEnumerator*			applicationIter = [mApplications objectEnumerator]; 
	VTApplicationWrapper*	application		= nil; 
	
	while (application = [applicationIter nextObject]) {
		// decide if we want to code this application 
		if (([application isSticky] == NO) && ([application isHidden] == NO) && ([application isUnfocused] == NO) && ([application boundDesktop] == nil))
			continue; 
		
		NSMutableDictionary* applicationDict = [[NSMutableDictionary alloc] init]; 
		// encode application 
		[application encodeToDictionary: applicationDict]; 
		// and add for later setting 
		[applicationList addObject: applicationDict]; 
		[applicationDict release]; 
	}
	
	[dictionary setObject: applicationList forKey: kVtCodingApplications]; 
}

- (id) decodeFromDictionary: (NSDictionary*) dictionary {
	NSArray* applications = [dictionary objectForKey: kVtCodingApplications]; 
	if (applications == nil)
		return self; 
	
	NSEnumerator*	applicationIter	= [applications objectEnumerator]; 
	NSDictionary*	applicationDict = nil; 
	
	while (applicationDict = [applicationIter nextObject]) {
		// create new application wrapper and decode 
		VTApplicationWrapper* newWrapper = [[VTApplicationWrapper alloc] init]; 
		newWrapper = [newWrapper decodeFromDictionary: applicationDict]; 
		
		if (newWrapper == nil)
			break; 
		
		// and add it 
		[self attachApplication: newWrapper]; 
		[newWrapper release]; 
	}
    
    return self;
}

#pragma mark -
#pragma mark Attributes 

- (NSArray*) applications {
	return [mApplications allValues]; 
}

- (VTApplicationWrapper*) applicationForBundle: (NSString*) bundle {
	return [mApplications objectForKey: bundle]; 
}


#pragma mark -
- (void) attachApplication: (VTApplicationWrapper*) wrapper {
	[self willChangeValueForKey: @"applications"]; 
	[mApplications setObject: wrapper forKey: [wrapper bundlePath]]; 
	[self didChangeValueForKey: @"applications"]; 	
}

- (void) detachApplication: (VTApplicationWrapper*) wrapper {
	[self willChangeValueForKey: @"applications"]; 	
	[mApplications removeObjectForKey: [wrapper bundlePath]]; 
	[self didChangeValueForKey: @"applications"]; 
}

#pragma mark -
#pragma mark Notification sink 
- (void) onApplicationAttached: (NSNotification*) notification {
	NSString* bundlePath = [notification object]; 
	
	// return nil paths 
	if (bundlePath == nil) 
		return; 
	
	// if we know about this application already, delegate to the wrapper 
	VTApplicationWrapper* wrapper = [mApplications objectForKey: bundlePath]; 
	
	if (wrapper != nil) {
		[wrapper onApplicationAttached: notification]; 
		return; 
	}
	
	// otherwise create a new wrapper 
	wrapper = [[[VTApplicationWrapper alloc] initWithBundlePath: bundlePath] autorelease];
	if (wrapper == nil) 
		return; 
	
	[self attachApplication: wrapper]; 
}

- (void) onApplicationDetached: (NSNotification*) notification {
	NSString* bundlePath = [notification object]; 
	
	// ignore nil paths 
	if (bundlePath == nil) 
		return; 
	
	// if we know about this application, let it know of the notification 
	VTApplicationWrapper* wrapper = [mApplications objectForKey: bundlePath]; 
	if (wrapper == nil)
		return; 
	
	[wrapper onApplicationDetached: notification]; 
	
	// now check if the application is still running and just return if it is
	if ([wrapper isRunning])
		return; 
	
	// check if we need to keep the application in our list
	if (([wrapper isSticky]) || ([wrapper isHidden]) || ([wrapper isUnfocused]) || ([wrapper isBindingToDesktop]))
		return; 
	
	// if the application died, we will potentially remove it from our list 
	// TODO: Consider user added flag 
	[self detachApplication: wrapper]; 
}

@end

#pragma mark -
@implementation VTApplicationController (Content) 

- (void) createApplications {
	// walk all desktops and collect applications 
	NSEnumerator*	desktopIter	= [[[VTDesktopController sharedInstance] desktops] objectEnumerator];
	PNDesktop*		desktop		= nil; 
	
	while (desktop = [desktopIter nextObject]) {
		NSEnumerator*	applicationIter	= [[desktop applications] objectEnumerator]; 
		PNApplication*	application		= nil; 
		
		while (application = [applicationIter nextObject]) {
			if ([application bundlePath] == nil)
				continue; 
			
			if ([mApplications objectForKey: [application bundlePath]] != nil)
				break; 
			
			// create a new wrapper and add it 
			VTApplicationWrapper* wrapper = [[VTApplicationWrapper alloc] initWithBundlePath: [application bundlePath]];
			
			if (wrapper == nil) 
				continue;
			
			[mApplications setObject: wrapper forKey: [application bundlePath]]; 
			[wrapper release]; 
		}
	}
}

@end 
