/******************************************************************************
*
* VirtueDesktops framework
*
* Copyright 2004, Thomas Staller playback@users.sourceforge.net
* Copyright 2006, Tony Arnold tony@tonyarnold.com
*
* See COPYING for licensing details
*
*****************************************************************************/

#import "VTDesktopController.h"

#import "FSMonitorController.h"
#import "PNNotifications.h"
#import "VTDesktopBackgroundHelper.h" 
#import "VTDesktopLayout.h" 
#import "VTNotifications.h" 
#import "VTPreferences.h" 
#import "ZNMemoryManagementMacros.h"

#define VTDesktops				@"VTDesktops"
#define VTTempFollowTimeout		1.0

@interface VTDesktopController (Private)
- (void) createDefaultDesktops; 
#pragma mark -
- (PNDesktop*) desktopForId: (int) idendifier; 
#pragma mark -
- (void) doActivateDesktop: (PNDesktop*) desktop withDirection: (VTDirection) direction; 
- (void) doActivateDesktop: (PNDesktop*) desktop usingTransition: (PNTransitionType) type withOptions: (PNTransitionOption) option andDuration: (float) duration; 
#pragma mark -
- (void) applyDesktopBackground; 
@end

#pragma mark -
@implementation VTDesktopController

#pragma mark -
#pragma mark Lifetime 

+ (VTDesktopController*) sharedInstance {
	static VTDesktopController* ms_INSTANCE = nil; 
	
	if (ms_INSTANCE == nil)
		ms_INSTANCE = [[VTDesktopController alloc] init]; 
	
	return ms_INSTANCE; 
}

#pragma mark -

- (id) init {
	if (self = [super init]) {
		// init attributes 
		_desktops					= [[NSMutableArray alloc] init];
		mPreviousDesktop			= nil; 
		mSnapbackDesktop			= nil; 
		mExpectingBackgroundChange	= NO; 
		mFollowApps					= NO;
		mFollowTimer				= nil;
		
		ZEN_ASSIGN_COPY(mDefaultDesktopBackgroundPath, [[VTDesktopBackgroundHelper sharedInstance] background]); 
		
		// Register as observer for desktop switches 
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onDesktopWillChange:) name: kPnOnDesktopWillActivate object: nil];
		
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(onDesktopDidChange:) name: kPnOnDesktopDidActivate object: nil];
		
		[[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(onDesktopBackgroundChanged:) name: VTBackgroundHelperDesktopChangedName object: VTBackgroundHelperDesktopChangedObject]; 
		
    /* *  
      * Expose SwitchTo(Next|Prev)Workspace to the DistributedNotificationCenter. 
      * 
      * Initial patch to archive something similar to 
      * [http://blog.medallia.com/2006/05/smacbook_pro.html] 
        */ 
		// create timer loop to update desktops 
		[NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(onUpdateDesktops:) userInfo: nil repeats: NO]; 
		
		return self; 
	}
	
	return nil; 
}

- (void) dealloc {		
	// get rid of observer status 
	[[NSNotificationCenter defaultCenter] removeObserver: self]; 
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self]; 

	// suspend the timer (if there is one)
	[self stopFollowingApplicationChanges:nil];
	
	// get rid of attributes 
	[_desktops release];
	ZEN_RELEASE(mPreviousDesktop); 
	ZEN_RELEASE(mSnapbackDesktop); 
	ZEN_RELEASE(mDefaultDesktopBackgroundPath); 
	
	[super dealloc]; 
}

#pragma mark -
#pragma mark Factories 

- (PNDesktop*) desktopWithFreeId {
	return [PNDesktop desktopWithIdentifier: [self freeId]]; 
}

- (int) freeId {
	int i = [PNDesktop firstDesktopIdentifier]; 
	
	while (YES) {
		if ([self desktopForId: i] == nil)
			return i; 
		
		// try next one 
		i++; 
	}	
}


#pragma mark -
#pragma mark Attributes 

- (NSMutableArray*) desktops {
	return _desktops;
}

- (void) setDesktops: (NSArray*)newDesktops {
	if (_desktops != newDesktops)
	{
    [_desktops autorelease];
    _desktops = [[NSArray alloc] initWithArray: newDesktops];
	}
}

- (void) addInDesktops: (PNDesktop*) desktop {
	// and add 
	[self insertObject: desktop inDesktopsAtIndex: [_desktops count]];
}

- (void) insertObject: (PNDesktop*) desktop inDesktopsAtIndex: (unsigned int) desktopIndex {
	[[NSNotificationCenter defaultCenter] postNotificationName: VTDesktopWillAddNotification object: desktop]; 
	// notification that canDelete will change 
	[self willChangeValueForKey: @"canAdd"];
	[self willChangeValueForKey: @"canDelete"]; 
	
	// and add 
	[_desktops insertObject: desktop atIndex: desktopIndex]; 
	NSLog(@"Created a new activity with the following tags: %@", [desktop displayName]);
	
	[[NSNotificationCenter defaultCenter] postNotificationName: VTDesktopDidAddNotification object: desktop]; 
	
	// KVO notification for canAdd/canDelete
	[self didChangeValueForKey: @"canAdd"];
	[self didChangeValueForKey: @"canDelete"]; 	
}

- (void) removeObjectFromDesktopsAtIndex: (unsigned int) desktopIndex {
	PNDesktop* desktopToRemove = [[_desktops objectAtIndex: desktopIndex] retain]; 
	
	// check which desktop to move them to 
	int targetIndex = desktopIndex - 1; 
	if (targetIndex < 0)
		targetIndex = [_desktops count] - 1; 
	
	PNDesktop* target = [_desktops objectAtIndex: targetIndex]; 
	
	if ([[self activeDesktop] isEqual: desktopToRemove]) 
		[self activateDesktop: target]; 
	
	[[NSNotificationCenter defaultCenter] postNotificationName: VTDesktopWillRemoveNotification object: desktopToRemove]; 
	
	// check if we hit the previous desktop and if so, let it point to nil 
	if ([desktopToRemove isEqual: mPreviousDesktop]) {
		[self willChangeValueForKey: @"previousDesktop"]; 
		ZEN_RELEASE(mPreviousDesktop); 
		[self didChangeValueForKey: @"previousDesktop"]; 
	}
	// check if we hit the snapback desktop and if so, let it point to nil 
	if ([desktopToRemove isEqual: mSnapbackDesktop]) {
		[self willChangeValueForKey: @"snapbackDesktop"]; 
		ZEN_RELEASE(mSnapbackDesktop); 
		[self didChangeValueForKey: @"snapbackDesktop"]; 
	}
	
	// now check if we should move windows 
	if (([[NSUserDefaults standardUserDefaults] boolForKey: VTWindowsCollectOnDelete]) && 
		([_desktops count] > 1)) {
		[desktopToRemove moveAllWindowsToDesktop: target]; 
	}
	
	// and remove the object 
	[self willChangeValueForKey: @"canAdd"];
	[self willChangeValueForKey: @"canDelete"]; 
	[_desktops removeObjectAtIndex: desktopIndex]; 
	[self didChangeValueForKey: @"canAdd"];
	[self didChangeValueForKey: @"canDelete"]; 
	
	NSLog(@"Removed an actvity with the following tags: %@", [desktopToRemove displayName]);
	
	[[NSNotificationCenter defaultCenter] postNotificationName: VTDesktopDidRemoveNotification object: desktopToRemove]; 
	ZEN_RELEASE(desktopToRemove); 
	
	// check if we got any desktops left, and if we don't, we will create our
	// default desktops 
	if ([_desktops count] == 0)
		[self createDefaultDesktops]; 
}

- (void) sendWindowUnderPointerBack {
	[[self activeDesktop] sendWindowUnderPointerBack];
}

#pragma mark -
- (BOOL) canAdd {
	return ([[VTDesktopLayout sharedInstance] maximumNumberOfDesktops] > [_desktops count]);	
}

- (BOOL) canDelete {
	return ([_desktops count] > 1); 
}

#pragma mark -

- (PNDesktop*) activeDesktop {
	// ask the desktop class for the active one 
	int activeDesktopId = [PNDesktop activeDesktopIdentifier]; 
	
	// return that desktop 
	return [self desktopForId: activeDesktopId]; 	
}

#pragma mark -
- (PNDesktop*) previousDesktop {
	return mPreviousDesktop; 
}

#pragma mark -
- (PNDesktop*) snapbackDesktop {
	return mSnapbackDesktop; 
}

- (void) setSnapbackDesktop: (PNDesktop*) desktop {
	ZEN_ASSIGN(mSnapbackDesktop, desktop); 
}

#pragma mark -
- (void) temporarilyFollowApplicationChanges {
	// clear any existing timer
	[self stopFollowingApplicationChanges:nil];
	
	mFollowApps = YES;
	
	mFollowTimer = [[NSTimer scheduledTimerWithTimeInterval:VTTempFollowTimeout
													 target:self
												   selector:@selector(stopFollowingApplicationChanges:)
												   userInfo:nil
													repeats:NO] retain];
}

- (void) stopFollowingApplicationChanges:(NSTimer *)timer {
	mFollowApps = NO;
	
	if (mFollowTimer) {
		[mFollowTimer invalidate];
		[mFollowTimer release];
		mFollowTimer = nil;
	}
}

- (BOOL) isTemporarilyFollowingApplicationChanges {
	return mFollowApps;
}

#pragma mark -
#pragma mark Querying 
- (PNDesktop*) desktopWithUUID: (NSString*) uuid {
	NSEnumerator*	desktopIter		= [_desktops objectEnumerator]; 
	PNDesktop*		desktop			= nil; 
	
	while (desktop = [desktopIter nextObject]) {
		if ([[desktop uuid] isEqualToString: uuid]) 
			return desktop; 
	}
	
	return nil; 
}

- (PNDesktop*) desktopWithIdentifier: (int) identifier {
	return [self desktopForId: identifier]; 
}

- (PNDesktop*) getDesktopInDirection: (VTDirection) direction {
	return [[VTDesktopLayout sharedInstance] desktopInDirection: direction ofDesktop: [[VTDesktopController sharedInstance] activeDesktop]];
}

#pragma mark -
#pragma mark Desktop switching 

- (void) activateDesktop: (PNDesktop*) desktop {
	// fetch direction to foward 
	VTDirection direction = [[VTDesktopLayout sharedInstance] directionFromDesktop: [[VTDesktopController sharedInstance] activeDesktop] toDesktop: desktop];
	
	[self doActivateDesktop: desktop withDirection: direction]; 
}

- (void) activateDesktop: (PNDesktop*) desktop usingTransition: (PNTransitionType) type withOptions: (PNTransitionOption) option withDuration: (float) duration {
	// if we got passed the active desktop, we do not do anything 
	if ([[self activeDesktop] isEqual: desktop])
		return; 
	
	[self doActivateDesktop: desktop usingTransition: type withOptions: option andDuration: duration]; 
}

- (void) activateDesktopInDirection: (VTDirection) direction {
	// get desktop 
	PNDesktop* desktop = [[VTDesktopLayout sharedInstance] desktopInDirection: direction ofDesktop: [[VTDesktopController sharedInstance] activeDesktop]]; 
	
	[self doActivateDesktop: desktop withDirection: direction]; 
}

#pragma mark -
#pragma mark Desktop persistency 

- (void) serializeDesktopsMovingContents:(BOOL)moveContents {
	// iterate over all desktops and archive them 
	NSEnumerator*		desktopIter		= [_desktops objectEnumerator]; 
	PNDesktop*			desktop			= nil;
	NSMutableArray*	desktopsArray = [[NSMutableArray alloc] init];
	NSMutableArray* desktopsUUIDs = [[NSMutableArray alloc] init];
	
	while (desktop = [desktopIter nextObject])
	{
		// We ensure that preferences are not corrupt due to the bug in 0.53r210
		if ([desktopsUUIDs containsObject: [desktop uuid]]) {
			continue;
		}
		[desktopsUUIDs addObject: [desktop uuid]];
		
		// ...and continue
		[desktopsArray removeObjectIdenticalTo: desktop];
		NSMutableDictionary* dictionary = [[NSMutableDictionary dictionary] retain];
		[desktop encodeToDictionary: dictionary];
		[desktopsArray insertObject: dictionary atIndex: [desktopsArray count]];
		[dictionary release];
	}
  
	// write to preferences 
	[[NSUserDefaults standardUserDefaults] setObject: desktopsArray forKey: VTDesktops]; 
	// and sync 
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// Optionally, scoot the desktop contents to the appropriate folder (mostly used so we don't get into trouble on restart)
	if (moveContents)
		[[self activeDesktop] storeDesktopItems];
}

- (void) deserializeDesktops {
	// desktop id 
	int  desktopId = [PNDesktop firstDesktopIdentifier];
	NSArray* serialisedDesktops = [[NSUserDefaults standardUserDefaults] objectForKey: VTDesktops];
	NSEnumerator*	serialisedDesktopsIterator	= [serialisedDesktops objectEnumerator];
	NSDictionary*	serialisedDesktopDictionary;
	NSMutableArray*   uuidArray = [[NSMutableArray alloc] init];
	
	while (serialisedDesktopDictionary = [serialisedDesktopsIterator nextObject]) {
		if ([uuidArray containsObject: [serialisedDesktopDictionary valueForKey: kVtCodingUUID]]) {
			continue;
		}
		[uuidArray addObject: [serialisedDesktopDictionary valueForKey: kVtCodingUUID]];
		PNDesktop*	desktop	= [[PNDesktop alloc] initWithTags: [serialisedDesktopDictionary valueForKey: kVtCodingTags]
												   identifier: desktopId
														 uuid: [serialisedDesktopDictionary valueForKey: kVtCodingUUID]];  
		[desktop decodeFromDictionary: serialisedDesktopDictionary]; 
		
		// insert into our array of desktops 
		[self addInDesktops: desktop]; 
		
		// and release temporary instance 
		[desktop release]; 
		
		desktopId++; 
	}
	
	// if we still have zero desktops handy, we will trigger creation of 
	// our default desktops 
	if ([_desktops count] == 0)
		[self createDefaultDesktops]; 
	
	PNDesktop* activeDesktop = [[[self activeDesktop] retain] autorelease]; 
	
	// If we collected all windows on the last shutdown, try to reparent them now
	if (([[NSUserDefaults standardUserDefaults] boolForKey: VTWindowsCollectOnDelete]) && 
		([_desktops count] > 1)) {
		NSEnumerator *windowIter = [[activeDesktop windows] objectEnumerator];
		PNWindow *window = nil;
		while (window = [windowIter nextObject]) {
			NSEnumerator *desktopIter = [_desktops objectEnumerator];
			PNDesktop *desktop = nil;
			while (desktop = [desktopIter nextObject])
				[desktop attemptToReparentWindow:window];
		}
	}
	
	// bind to active desktop 
	[activeDesktop addObserver: self forKeyPath: @"desktopBackground" options: NSKeyValueObservingOptionNew context: NULL]; 
	
	// and apply settings of active desktop 
	mExpectingBackgroundChange = YES;
	[self applyDesktopBackground];
	
	[activeDesktop loadDesktopItems];
}

#pragma mark -
#pragma mark Per-desktop storage helper

+ (NSString *) activityStorePath {
	// Make sure we have someplace to store activity-related information all set to go
	static NSString *ms_ActivityFolder = nil;
	
	if (ms_ActivityFolder == nil) {
		ms_ActivityFolder = [[NSHomeDirectory() stringByAppendingPathComponent:@"Activities"] retain];
		
		// If it doesn't exist (e.g., first run), create it (with the right permissions)
		if ([[NSFileManager defaultManager] fileExistsAtPath:ms_ActivityFolder] == NO) {
			[[NSFileManager defaultManager] createDirectoryAtPath:ms_ActivityFolder
													   attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:(unsigned long)448]
																							  forKey:NSFilePosixPermissions]];
			
			// And decorate it
			NSImage *folderIcon = [NSImage imageNamed:@"activityFolder.tiff"];
			if (folderIcon)
				[[NSWorkspace sharedWorkspace] setIcon:folderIcon forFile:ms_ActivityFolder options:0];
		}
	}
	
	return [[ms_ActivityFolder copy] autorelease];
}


#pragma mark -
#pragma mark Notification sinks

- (void) onDesktopBackgroundChanged: (NSNotification*) notification {
	// ignore if we expected it because we triggered the change 
	if ( (mExpectingBackgroundChange == YES) || ([[self activeDesktop] showsBackground] == YES) || ([mDefaultDesktopBackgroundPath isEqualToString: [[VTDesktopBackgroundHelper sharedInstance] background]] == YES)) {
		mExpectingBackgroundChange = NO;
		return; 
	}		
		
	// otherwise get the background picture and set it as the default
	ZEN_ASSIGN_COPY(mDefaultDesktopBackgroundPath, [[VTDesktopBackgroundHelper sharedInstance] background]);
	[[VTDesktopBackgroundHelper sharedInstance] setDefaultBackground: mDefaultDesktopBackgroundPath];
	
	// Propagate 
	[[self desktops] makeObjectsPerformSelector: @selector(setDefaultDesktopBackgroundIfNeeded:) withObject: mDefaultDesktopBackgroundPath];
}

- (void) onUpdateDesktops: (NSTimer*) timer {
	[_desktops makeObjectsPerformSelector: @selector(updateDesktop)]; 
	[NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(onUpdateDesktops:) userInfo: nil repeats: NO]; 
}

- (void) onDesktopWillChange: (NSNotification*) notification {
	PNDesktop* desktop = [[[self activeDesktop] retain] autorelease]; 
	
	// propagate key change 
	[self willChangeValueForKey: @"activeDesktop"]; 
	
	// do not process further if the changed desktop is already the active one 
	if ([[notification object] isEqual: desktop])
		return; 
	
	// propagate key change for previous desktop 
	[self willChangeValueForKey: @"previousDesktop"]; 
	
	// remember the old desktop for the last desktop 
	ZEN_ASSIGN(mPreviousDesktop, [self activeDesktop]); 
	
	// propagate key change for previous desktop completed 
	[self didChangeValueForKey: @"previousDesktop"];
	
	// Ensure object consistency.
	if ([[self activeDesktop] showsBackground] == NO) {
		[[VTDesktopBackgroundHelper sharedInstance] setDefaultBackground: [[VTDesktopBackgroundHelper sharedInstance] background]];
	}
	
	// Move desktop items to the activity's store folder (after suspending file tagging!!)
	[[FSMonitorController sharedInstance] pauseTagging];
	[desktop storeDesktopItems];
  
	// unbind desktop 
	[desktop removeObserver: self forKeyPath: @"desktopBackground"];
}

- (void) onDesktopDidChange: (NSNotification*) notification {
	// bind desktop 
	[[self activeDesktop] addObserver: self forKeyPath: @"desktopBackground" options: NSKeyValueObservingOptionNew context: NULL];
	[[self activeDesktop] loadDesktopItems];
	[self applyDesktopBackground];
	[self didChangeValueForKey: @"activeDesktop"];
	
	NSLog(@"Switched to activity with tags: %@", [[self activeDesktop] displayName]);
}


#pragma mark -
#pragma mark KVO Sink 

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString: @"showsBackground"] || [keyPath isEqualToString: @"desktopBackground"]) {
		[self applyDesktopBackground];
	}
}

@end 

#pragma mark -
@implementation VTDesktopController (Private) 

- (void) createDefaultDesktops {
	NSArray* defaultDesktops;
	
	defaultDesktops = [NSArray arrayWithObjects: [NSArray array], nil];
	
	// now iterate and create desktops 
	NSEnumerator*	desktopTagsIter	= [defaultDesktops objectEnumerator]; 
	NSArray*		desktopTags		= nil; 
	int				desktopId		= [PNDesktop firstDesktopIdentifier]; 
	
	while (desktopTags = [desktopTagsIter nextObject]) {
		// create a nice desktop
		PNDesktop* desktop = [PNDesktop desktopWithTags: desktopTags identifier: desktopId];  
		// add it 
		[self insertObject: desktop inDesktopsAtIndex: [_desktops count]];
		
		// next id
		desktopId++; 
	}
	
	[self serializeDesktopsMovingContents:NO];
}

#pragma mark -
- (PNDesktop*) desktopForId: (int) identifier {
	NSEnumerator*	desktopIter	= [_desktops objectEnumerator]; 
	PNDesktop*		desktop		= nil; 
	
	while (desktop = [desktopIter nextObject]) {
		if ([desktop identifier] == identifier)
			return desktop; 
	}
	
	return nil; 	
}

#pragma mark -

- (void) doActivateDesktop: (PNDesktop*) desktop withDirection: (VTDirection) direction {
	if (direction == kVtDirectionNone)
		return;
	
	PNTransitionType type;
	PNTransitionOption option;
	float duration;
	
	// Make sure transition is enabled
	if ([[NSUserDefaults standardUserDefaults] boolForKey:VTDesktopTransitionEnabled]) {
		
		// fetch user default transition type, option and duration
		type     = [[NSUserDefaults standardUserDefaults] integerForKey: VTDesktopTransitionType];
		option   = [[NSUserDefaults standardUserDefaults] integerForKey: VTDesktopTransitionOptions];
		duration = [[NSUserDefaults standardUserDefaults] floatForKey:   VTDesktopTransitionDuration];
		
		// decide based on the direction 
		switch (direction) {
		case kVtDirectionWest: 
			option = kPnOptionRight; 
			break; 
		case kVtDirectionEast: 
			option = kPnOptionLeft; 
			break;

		default: 
			option = kPnOptionLeft; 
		}
		
		// decide type 
		if (type == kPnTransitionAny) {
			type = 1 + (random() % 9); 
		}
	} else {
		type = kPnTransitionNone;
		option = kPnOptionAny;
		duration = 0.0;
	}
	
	// now do it ;)
	[self doActivateDesktop: desktop 
			usingTransition: type 
				withOptions: option 
				andDuration: duration];
}

- (void) doActivateDesktop: (PNDesktop*) desktop usingTransition: (PNTransitionType) type withOptions: (PNTransitionOption) option andDuration: (float) duration {
	// again, do the check for the active desktop and do not allow any switch resulting in the 
	// same desktop 
	if (desktop == nil || [desktop isEqual: [self activeDesktop]])
		return;
	
	// we do not allow kPnOptionAny or kPnTransitionAny here (assuming we're doing any transition)
	if (type == kPnTransitionAny)
		return;
	if (option == kPnOptionAny && type != kPnTransitionNone)
		return;
	
	// Quickly, before we switch, snap a picture of the previous activity (for the overview/manager)
	[[self activeDesktop] captureThumbnail];
	
	// Also, do a quick update of the activity's windows (so that we're a little more up-to-date if we crash)
	[[self activeDesktop] updatePersistedWindowList];
			
	// if there was no transition type given or the duration is below our threshold, we 
	// switch without animation 
	if (type == kPnTransitionNone || duration < 0.1) {
		[desktop activate]; 
	} else {
		[desktop activateWithTransition: type option: option duration: duration]; 
	}
	
	// Finally, do a quick update of our prefs files (again, a crash-resistance measure)
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self serializeDesktopsMovingContents:NO];
}

- (void) applyDesktopBackground {
	mExpectingBackgroundChange = YES;
	[[self activeDesktop] applyDesktopBackground]; 
}

- (NSString*) applicationSupportFolder {
	NSString *applicationSupportFolder = nil;
	FSRef foundRef;
	OSErr err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, kDontCreateFolder, &foundRef);
	if (err != noErr) {
		NSRunAlertPanel(@"Alert", @"Can't find application support folder", @"Quit", nil, nil);
		[[NSApplication sharedApplication] terminate:self];
        NSLog(@"Giornata exit value: 4");
        exit(4);
	} else {
		unsigned char path[PATH_MAX];
		FSRefMakePath(&foundRef, path, sizeof(path));
		applicationSupportFolder = [NSString stringWithUTF8String:(char *)path];
		applicationSupportFolder = [applicationSupportFolder stringByAppendingPathComponent:[NSString stringWithFormat: @"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"]]];
	}
	return applicationSupportFolder;
}

@end 
