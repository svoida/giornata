/******************************************************************************
*
* Peony.Virtue
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller <playback@users.sourceforge.net>
* Copyright 2006, Tony Arnold <tony@tonyarnold.com>
*
* See COPYING for licensing details
*
*****************************************************************************/

#import "PNDesktop.h"

#import "CPModel.h"
#import "GLGrab.h"
#import "NSFileManagerDesktopShuffle.h"
#import "PNApplication.h"
#import "PNNotifications.h"
#import "PNStickyWindowCollection.h"
#import "PNWindow.h"
#import "VTDesktopBackgroundHelper.h"
#import "VTDesktopController.h"
#import "ZNMemoryManagementMacros.h"


@interface PNDesktop(Private)
- (id) _initWithId: (int) desktopId andTags: (NSArray*) tags uuid: (NSString*) uuid update: (BOOL) update;
+ (NSString*) _generateUID;
- (NSString*) _descriptiveActivityStoreFolderName;
- (NSString*) _activityStoreFolderCreatingIfNecessary:(BOOL)createFolder;
@end

#pragma mark -
@interface PNDesktop (ApplicationList)
- (void) detachApplication: (PNApplication*) application;
- (void) attachApplication: (PNApplication*) application;
@end

#pragma mark -
@implementation PNDesktop

#pragma mark -
#pragma mark Lifetime

+ (id) desktopWithIdentifier: (int) identifier {
	return [PNDesktop desktopWithTags: nil identifier: identifier];
}

+ (id) desktopWithTags: (NSArray*) tags identifier: (int) identifier {
	return [[[PNDesktop alloc] initWithTags: tags identifier: identifier uuid: nil] autorelease];
}

#pragma mark -

/**
* @brief We do not allow initialisation of a non-connected desktop proxy
 *
 */
- (id) init 
{
	// generate "erroneous" desktop identifier
	int sDefaultIdentifier = kPnDesktopInvalidId;
	
	// generate default name
	NSArray *sDefaultTags = [[NSArray array] autorelease];
	
	// Pass on initialisation to designated initialiser
	return [self initWithTags: sDefaultTags identifier: sDefaultIdentifier uuid: nil];
}

/**
* @brief Public face of designated intializer
 *
 */
- (id) initWithTags: (NSArray*) tags identifier: (int) identifier uuid: (NSString*) uuid {
	return [self _initWithId: identifier andTags: tags uuid: uuid update: YES];
}

- (void) dealloc 
{
	ZEN_RELEASE(mDesktopBackgroundImagePath);
	ZEN_RELEASE(mUUID);
	ZEN_RELEASE(mThumbnail);
	ZEN_RELEASE(mContacts);
	ZEN_RELEASE(mDesktopTags);
	ZEN_RELEASE(mWindows);
	ZEN_RELEASE(mApplications);
	
	// Delegate deallocation to superclass
	[super dealloc];
}

#pragma mark -
#pragma mark NSCopying
- (id) copyWithZone: (NSZone*) zone 
{
	PNDesktop* desktop = [[PNDesktop alloc] _initWithId: mDesktopId andTags: mDesktopTags uuid: mUUID update: NO];
	
	desktop->mWindows				= [mWindows retain];
	desktop->mApplications			= [mApplications retain];
	desktop->mContacts				= [mContacts retain];
	desktop->mPersistedWindowList	= [mPersistedWindowList retain];
	desktop->mThumbnail				= [mThumbnail retain];
	
	return desktop;
}

#pragma mark -
#pragma mark NSCoding

- (id) initWithCoder: (NSCoder*) coder {
	if (self = [super init]) {
		[self setShowsBackground: [coder decodeBoolForKey: kVtCodingShowsBackgroundImage]];
		
		if ([self showsBackground])
			[self setDesktopBackground: [coder decodeObjectForKey: kVtCodingBackgroundImage]];
		
		[self setTags: [coder decodeObjectForKey: kVtCodingTags]];
		
		// Need to decode these eventually
		mContacts = [[NSMutableArray alloc] init];
		
		mPersistedWindowList = [[coder decodeObjectForKey: kVtCodingPersistedWindowList] mutableCopy];
		if (mPersistedWindowList == nil)
			mPersistedWindowList = [[NSMutableArray alloc] init];
		
		mThumbnail = nil;
		mUnreadCount = kPnDesktopUnknownUnreadCount;
		
		return self;
	}
	
	return nil;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeBool: [self showsBackground] forKey: kVtCodingShowsBackgroundImage];
	
	if ([self showsBackground])
		[coder encodeObject: [self desktopBackground] forKey: kVtCodingBackgroundImage];
	
	[coder encodeObject: [self tags] forKey: kVtCodingTags];
	
	// Need to encode contacts
	
	if (mPersistedWindowList && [mPersistedWindowList count] > 0)
		[coder encodeObject: mPersistedWindowList forKey: kVtCodingPersistedWindowList];
}

- (void) encodeToDictionary: (NSMutableDictionary*) dictionary {
	if ([self showsBackground] && [self desktopBackground])
		[dictionary setObject: [self desktopBackground] forKey: kVtCodingBackgroundImage];
	
	[dictionary setObject: [NSNumber numberWithBool: [self showsBackground]] forKey: kVtCodingShowsBackgroundImage];
	[dictionary setObject: [self tags] forKey: kVtCodingTags];
	[dictionary setObject: [self uuid] forKey: kVtCodingUUID];
	
	[dictionary setObject: [NSKeyedArchiver archivedDataWithRootObject: mContacts]
				   forKey: kVtCodingContacts];
	
	if (mPersistedWindowList && [mPersistedWindowList count] > 0)
		[dictionary setObject: mPersistedWindowList forKey: kVtCodingPersistedWindowList];
}

- (id) decodeFromDictionary: (NSDictionary*) dictionary {
	[self setTags: [dictionary objectForKey: kVtCodingTags]];
	[self setShowsBackground: [[dictionary objectForKey: kVtCodingShowsBackgroundImage] boolValue]];
	
	if ([self showsBackground]) {
		[self setDesktopBackground: [dictionary objectForKey: kVtCodingBackgroundImage]];
	}
	
	mUUID = [[dictionary objectForKey: kVtCodingUUID] copy];

	mContacts = nil;
	NSData *data = [dictionary objectForKey: kVtCodingContacts];
	if (data != nil) {
		NSMutableArray *tempContacts = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData: data];
		if (tempContacts != nil)
			mContacts = [tempContacts mutableCopy];
	}
	if (mContacts == nil)
		mContacts = [[NSMutableArray alloc] init];
	
	mPersistedWindowList = [[dictionary objectForKey: kVtCodingPersistedWindowList] mutableCopy];
	if (mPersistedWindowList == nil)
		mPersistedWindowList = [[NSMutableArray alloc] init];
	
	mThumbnail = nil;
	mUnreadCount = kPnDesktopUnknownUnreadCount;
	
	return self;
}

#pragma mark -
#pragma mark Attributes

/**
* @brief		Returns the id of the desktop that is currently shown
 *
 * @return	The workspace id of the currently shown desktop or kPnDesktopInvalidId if there was an error.
 */
+ (int) activeDesktopIdentifier
{
	// Get a connection to the CoreGraphics server
	CGSConnection oConnection = _CGSDefaultConnection();
	
	// Fetch the active desktop id and return nil in case of an error
	int iWorkspaceId;
	
	OSStatus oResult = CGSGetWorkspace(oConnection, &iWorkspaceId);
	if (oResult)
	{
		NSLog(@"PNDesktop cannot access current workspace [Error: %i]", oResult);
		return kPnDesktopInvalidId;
	}
	
	return iWorkspaceId;
}

/**
* @brief Returns the lowest possible valid desktop id
 *
 */
+ (int) firstDesktopIdentifier 
{
	return 1;
}

#pragma mark -
- (int) identifier 
{
	return mDesktopId;
}

- (void) setIdentifier: (int) identifier 
{
	mDesktopId = identifier;
	
	[self updateDesktop];
}


#pragma mark -
- (NSString*) displayName
{
	if ([mDesktopTags count] == 0)
		return NSLocalizedString(@"NSStringTaglessDisplayName", @"(untagged)");
	else
		return [mDesktopTags componentsJoinedByString:@" "];
}

- (NSArray*) tags 
{
	return mDesktopTags;
}

- (void) setTags: (NSArray*) tags 
{
	if (tags) {
		NSString *oldFolder = [self _activityStoreFolderCreatingIfNecessary:YES];
		
		[mDesktopTags autorelease];
		mDesktopTags = [tags copy];
		
		// Update the associated activity store folder (if necessary)
		NSString *newFolder = [self _activityStoreFolderCreatingIfNecessary:NO];
		if (![newFolder isEqualToString:oldFolder])
			[[NSFileManager defaultManager] movePath:oldFolder
											  toPath:newFolder
											 handler:NULL];
	}
}

#pragma mark -

- (NSString*) uuid {
	return [[mUUID copy] autorelease];
}

#pragma mark -

- (void) setDesktopBackground: (NSString*) path {
	if ([self showsBackground] == NO || path == nil)
		return;
	
	ZEN_ASSIGN_COPY(mDesktopBackgroundImagePath, path);
}

- (NSString*) desktopBackground {
	if (mDesktopBackgroundImagePath == nil) {
		ZEN_ASSIGN_COPY(mDesktopBackgroundImagePath, [[VTDesktopBackgroundHelper sharedInstance] defaultBackground]);
	}
	
	return [[mDesktopBackgroundImagePath copy] autorelease];
}

- (void) setDefaultDesktopBackgroundIfNeeded: (NSString*) path {
	if ( ([self showsBackground] == YES) || path == nil )
		return;
	
	ZEN_ASSIGN_COPY(mDesktopBackgroundImagePath, path);
}

#pragma mark -

- (void) setShowsBackground: (BOOL) showsBackground {
	mShowsBackground = showsBackground;
	[self applyDesktopBackground];
}

- (BOOL) showsBackground {
	return mShowsBackground;
}

#pragma mark -

/**
* @brief KVO compliant list of windows contained in the desktop
 *
 */
- (NSArray*) windows 
{
	return mWindows;
}

/**
* @brief KVO compliant list of applications contained in the desktop
 *
 */
- (NSArray*) applications 
{
	return [mApplications allValues];
}

#pragma mark -

/**
* @brief Checks if the desktop is currently shown to the user
 *
 * @return	Returns @c YES if the desktop is the one the user is currently working on, @c NO if it is not.
 *
 */
- (BOOL) visible 
{
	CGSConnection oConnection = _CGSDefaultConnection();
	
	int iActiveWorkspace;
	OSStatus oResult = CGSGetWorkspace(oConnection, &iActiveWorkspace);
	if (oResult) {
		NSLog(@"[Desktop %i] Failed getting active workspace [Error: %i]", mDesktopId, oResult);
		return NO;
	}
	
	return (mDesktopId == iActiveWorkspace);
}

#pragma mark -

- (void) captureThumbnail
{
	if (mThumbnail)
		[mThumbnail release];
	
	NSScreen *display = [NSScreen mainScreen];
	NSRect bounds = [[NSScreen mainScreen] frame];
	
    NSParameterAssert(display != NULL);
	
	NSNumber *displayID = [[display deviceDescription] objectForKey:@"NSScreenNumber"];
	CGRect rect = CGRectMake(bounds.origin.x, bounds.origin.y, 
							 bounds.size.width, bounds.size.height);
	CGImageRef src = grabViaOpenGL((CGDirectDisplayID)[displayID intValue], rect);
	
	int		pixels_wide = CGImageGetWidth(src);
	int		pixels_high = CGImageGetHeight(src);
	int 	bps = CGImageGetBitsPerComponent(src);
	int 	spp = CGImageGetBitsPerPixel(src) / bps;
	BOOL 	has_alpha = (CGImageGetAlphaInfo(src) != kCGImageAlphaNone);
	
	NSBitmapImageRep *bitmap_rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																			pixelsWide:pixels_wide
																			pixelsHigh:pixels_high
																		 bitsPerSample:bps
																	   samplesPerPixel:spp
																			  hasAlpha:has_alpha
																			  isPlanar:NO
																		colorSpaceName:NSDeviceRGBColorSpace
																		   bytesPerRow:0
																		  bitsPerPixel:0] autorelease];
	CGColorSpaceRef 	dst_colorspaceref = CGColorSpaceCreateDeviceRGB();
	CGImageAlphaInfo 	dst_alphainfo = has_alpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone;
	CGContextRef 		dst_contextref = CGBitmapContextCreate([bitmap_rep bitmapData],
															   pixels_wide,
															   pixels_high,
															   bps,
															   [bitmap_rep bytesPerRow],
															   dst_colorspaceref,
															   dst_alphainfo);
	
	rect = CGRectMake(0, 0, pixels_wide, pixels_high);
	CGContextDrawImage(dst_contextref, rect, src);
	
	CGImageRelease(src);
	CGContextRelease(dst_contextref);
	CGColorSpaceRelease(dst_colorspaceref);
	
	mThumbnail = [[NSImage alloc] initWithSize:NSMakeSize(pixels_wide, pixels_high)];
	[mThumbnail addRepresentation:bitmap_rep];
}

- (NSImage*) thumbnail
{
	return mThumbnail;
}

#pragma mark -

- (void) setUnreadCount: (int) unreadCount {
	mUnreadCount = unreadCount;
}

- (int) unreadCount {
	return mUnreadCount;
}

#pragma mark -

- (void) updatePersistedWindowList {
	[mPersistedWindowList removeAllObjects];
	
	NSEnumerator*	windowIter	= [mWindows objectEnumerator];
	PNWindow*		window		= nil;
	
	while (window = [windowIter nextObject]) {
		// get the owning process name
		CFStringRef strProcessName;
		ProcessSerialNumber psn = [window ownerPsn];
		CopyProcessName(&psn, &strProcessName); 
		NSString *processName = (NSString*)strProcessName;
		if ([processName compare:@"Giornata"] == NSOrderedSame)
			continue;
		
		NSString *reparentKey = [NSString stringWithFormat:@"%@ ::: %@", processName, [window name]];
		[mPersistedWindowList addObject: reparentKey];
	}
}

- (BOOL) attemptToReparentWindow: (PNWindow*) window {
	// get the owning process name
	CFStringRef strProcessName;
	ProcessSerialNumber psn = [window ownerPsn];
	CopyProcessName(&psn, &strProcessName); 
	NSString *processName = (NSString*)strProcessName;
	if ([processName compare:@"Giornata"] == NSOrderedSame)
		return NO;
	
	NSString *reparentKey = [NSString stringWithFormat:@"%@ ::: %@", processName, [window name]];
	if ([mPersistedWindowList containsObject:reparentKey]) {
		[window setDesktop: self];
		return YES;
	}
	
	return NO;
}


#pragma mark -
#pragma mark NSObject

- (BOOL) isEqual: (id) other 
{
    if (other == nil || [other isKindOfClass: [PNDesktop class]] == NO)
		return NO;
	
	return (mDesktopId == [(PNDesktop*)other identifier]);
}

- (NSString*) description 
{
	return [self displayName];
}

#pragma mark -
#pragma mark Activation

/**
* @brief Activates the desktop using the default transition and duration settings
 *
 */
- (void) activate 
{
	// delegate to the more sophisticated activation method using default values
	[self activateWithTransition: kPnTransitionAny option: kPnOptionAny duration: kPnTransitionDurationDefault];
}

/**
* @brief Activates the desktop using the passed transition and duration
 *
 * @param transition	The transition to use while switching
 * @param option		Option parameterizing the transition
 * @param duration	The duration the transition should take in seconds
 *
 * The passed transition type has to be different from TransitionAny. If TransitionAny is passed, TransitionNone will be used as the type passed to CGS.
 *
 * @notify		kPnOnDesktopWillActivate
 *					'object'	self
 * @notify		kPnOnDesktopDidActivate
 *					'object'	self
 *
 * @distnotify	kPnOnDesktopWillActivate
 *					'desktop' self.desktopId
 * @distnotify	kPnOnDesktopDidActivate
 *					'desktop' self.desktopId
 */
- (void) activateWithTransition: (PNTransitionType) transition option: (PNTransitionOption) option duration: (float) seconds 
{
	NSDictionary* infoDict = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt: mDesktopId], @"desktop", nil];
	
	// Notify clients that we will soon be the active desktop
	[[NSNotificationCenter defaultCenter] postNotificationName: kPnOnDesktopWillActivate object: self];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: kPnOnDesktopWillActivate object: nil userInfo: infoDict];
	
	// Get the connection to the CoreGraphics server
	CGSConnection cgs = _CGSDefaultConnection();
	
	if ((int)transition == -1) {
		transition = CGSNone;
		seconds = 0;
	}
	
	// Set-up the transition "effect" first
	int handle;
	
	// Set the colour of the backdrop for the CGSTransition
	float rgb[3] = { 0.0, 0.0, 0.0 };
	
	CGSTransitionSpec spec;
	spec.unknown1	= 0;
	spec.type		= transition;
	spec.option		= option;
	spec.wid		= 0;
	spec.backColour	= rgb;
	
	// Create the transition, freezing all on-screen activity		
	CGSNewTransition(cgs, &spec, &handle);
	
	// Now switch the workspace while the screen is frozen, setting up the transition target
	CGSSetWorkspace(cgs, mDesktopId);
	
	// Notify listeners that we are now the active desktop
	[[NSNotificationCenter defaultCenter] postNotificationName: kPnOnDesktopDidActivate object: self];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: kPnOnDesktopDidActivate object: nil userInfo: infoDict];
	
	// tony@tonyarnold.com: Previously, I would insert a usleep(100000); here, so that the desktop picture had time to update before the transition was released. I think we need to find a faster way to set the desktop picture and get it onscreen - or accept the fact that desktop picture transitions are something that will only display properly on fast machines.
	
	// Run the transition	
	CGSInvokeTransition(cgs, handle, seconds);
	
	// We need to wait for the length of the transition before releasing
	usleep((useconds_t)(seconds*1000000));
	
	// Now release the transition from memory
	CGSReleaseTransition(cgs, handle);
	
	handle = 0;
}

#pragma mark -
#pragma mark Window operations

- (void) moveAllWindowsToDesktop: (PNDesktop*) desktop 
{
	// Update to ensure all our windows are listed and current
	[self updateDesktop];
	
	// Now go through the window list and move them to the new desktop
	NSEnumerator*	windowIter	= [mWindows objectEnumerator];
	PNWindow*		window		= nil;
	
	// TODO: Move functionality to use a PNWindowList for mass-window operations
	while (window = [windowIter nextObject]) {
		[window setDesktop: desktop];
	}
}

/**
* @brief Orders the passed window to the front of the current desktop
 *
 * @param window	Window to bring to the front
 *
 */
- (void) orderWindowFront: (PNWindow*) window {
	if ([mWindows count] == 0)
		return;
	if ([mWindows objectAtIndex: 0] == window)
		return;
	
	PNWindow* referenceWindow = [mWindows objectAtIndex: 0];
	[window orderAbove: referenceWindow];
}

/**
* @brief Orders the passed window to the back of the current desktop
 *
 * @param window	Window to bring to the back
 *
 */
- (void) orderWindowBack: (PNWindow*) window {
	if ([mWindows count] == 0)
		return;
	
	PNWindow* bmWindow = [self bottomMostWindow];
	
	if (!bmWindow)
		return;
	
	if (bmWindow == window)
		return;
	
	[window orderBelow: bmWindow];
}

/**
* @brief Sends the window under point behind all windows on the desktop
 *
 */
- (void) sendWindowUnderPointerBack
{
	if (![self visible])
		return;
	
	NSPoint mouseLoc = [NSEvent mouseLocation];
	NSSize screenSize = [[NSScreen mainScreen] frame].size;
	mouseLoc.y = screenSize.height - mouseLoc.y;
	PNWindow* wcpWindow = [self windowContainingPoint: mouseLoc];
	if (!wcpWindow)
		return;
	
	[self orderWindowBack: wcpWindow];
}


#pragma mark -
#pragma mark Updating

/**
* @brief Clear the list of windows and fetch all windows in the workspace
 *
 * Queries windows for the wrapped desktop and adds new windows not yet contained
 * in the internal list of windows. Windows that are contained in the internal list
 * but were not returned by the windows query, will be removed from the internal
 * list. We also try to validate all sticky windows in this run and remove invalid
 * sticky windows (those that were closed) from the sticky window list.
 *
 * @note	This method is inherently costly, it should not be called every ms and
 *			the caller should be prepared to wait a bit here.
 *
 * @notify	kPnOnWindowRemoved
 *			Called if a window is no longer living on this desktop or was closed
 *
 * @todo	Optimize a bit here
 *
 */
- (void) updateDesktop 
{
	if (mDesktopId < 0)
		return;
	
	// get connection
	CGSConnection oConnection = _CGSDefaultConnection();
	OSStatus oResult;
	
	int				iNumberOfWindows		= 0;
	NSMutableData*	oWindows				= NULL;
	BOOL			didChangeWindows		= NO;
	BOOL			didChangeApplications	= NO;
	
	// first we have to query for the number of windows in our workspace
	oResult = CGSGetWorkspaceWindowCount(oConnection, mDesktopId, &iNumberOfWindows);
	if (oResult) {
		NSLog(@"[Desktop %i] CGSGetWorkspaceWindowCount failed [%i]", mDesktopId, oResult);
		return;
	}
	
	// if the number of desktops is 0, we will skip fetching windows
	if (iNumberOfWindows > 0)
	{
		// query the list of windows in our workspace
		oWindows  = [NSMutableData dataWithCapacity: iNumberOfWindows * sizeof(int)];
		oResult   = CGSGetWorkspaceWindowList(oConnection, mDesktopId, iNumberOfWindows, [oWindows mutableBytes], &iNumberOfWindows);
		if (oResult) 
		{
			NSLog(@"[Desktop %i] CGSGetWorkspaceWindowList failed [%i]", mDesktopId, oResult);
			return;
		}
	}
	
	
	// Copy the current list of windows for cross checking
	NSMutableArray* previousWindows = [NSMutableArray arrayWithArray: mWindows];
	
	int i                       = 0;
	unsigned currentListIndex	= 0;
	
	// heya, now we can start synchronizing.. we will iterate over all windows and check if we already know about them. If we find a window we do not know, we will add it. we will also remove windows we found from the copy.
	for ( i = 0; i < iNumberOfWindows; i++ ) {
		// get entry from list of fetched windows
		CGSWindow iWindowId = ((int*)[oWindows mutableBytes])[i];
		
		// get the window proxy
		PNWindow* window = [[PNWindow windowWithWindowId: iWindowId] retain];
		
		// ignore menus
		if (([window level] == NSPopUpMenuWindowLevel) ||
			([window level] == NSSubmenuWindowLevel) ||
			([window level] == NSMainMenuWindowLevel)) {
			ZEN_RELEASE(window);
			continue;
		}
		
		// get application container
		PNApplication* application = [mApplications objectForKey: [NSNumber numberWithInt: [window ownerPid]]];    
		
		// if the application container does not contain a reference to the application, create a new one
		if (application == nil) {
			didChangeApplications = YES;
			
			application = [[PNApplication alloc] initWithPid: [window ownerPid] onDesktop: self];
			// and attach
			[self attachApplication: application];
			// and release application
			ZEN_RELEASE(application);
		}
		
		// if the window is special, we do not include it in our list
		if ([window isSpecial]) {
			ZEN_RELEASE(window);
			continue;
		}
		
		
		// If it is a utility palette, we should make it sticky, so palettes don't get lost across desktops
		if (([window level] == kCGUtilityWindowLevelKey) ||
			([window level] == kCGBackstopMenuLevelKey) ||
			([window level] == kCGFloatingWindowLevelKey))
		{
			[window setSticky: YES];
		}
		
		
		
		// check if the window is in our list and add it if it isn't
		if ([mWindows containsObject: window] == NO) {
			// add the window to the list of known windows and mark ourselves as dirty
			didChangeWindows = YES;
			[mWindows insertObject: window atIndex: currentListIndex];
		}
		else {
			// we already knew about this window, and it apparently still exists, so we will remove it from the list of previous windows
			[previousWindows removeObject: window];
			
			// and check if the position of the window changed
			if (currentListIndex != [mWindows indexOfObject: window])
			{
				didChangeWindows = YES;
				
				// now we move the window to the new index
				[mWindows removeObject: window];
				[mWindows insertObject: window atIndex: currentListIndex];
			}
		}
		
		// Bind the window to it's parent application
		[application bindWindow: window];
		
		ZEN_RELEASE(window);
		// increment the list index
		currentListIndex++;
	}
	
	// now handle sticky windows, this will only change the window list, if we are not the active desktop
	NSArray*		stickyWindowsCopy	= [NSMutableArray arrayWithArray: [[PNStickyWindowCollection stickyWindowCollection] windows]];
	NSEnumerator*	stickyIter			= [stickyWindowsCopy objectEnumerator];
	PNWindow*		stickyWindow		= nil;
	
	while (stickyWindow = [stickyIter nextObject]) {
		
		// we take the chance and remove all the sticky windows that are no longer valid
		if ([stickyWindow isValid] == NO)
		{
			// remove from the sticky window list as this window seems to be gone
			[[PNStickyWindowCollection stickyWindowCollection] delWindow: stickyWindow];
			// and also remove it from the application list if necessary
			PNApplication* application = [mApplications objectForKey: [NSNumber numberWithInt: [stickyWindow ownerPid]]];
			if (application != nil) {
				if ([application isValid] == YES)
					[application unbindWindow: stickyWindow];
				else {
					didChangeApplications = YES;
					// detach application
					[self detachApplication: application];
				}
			}
			
			if ([previousWindows containsObject: stickyWindow] == NO) {
				// and post notification that the window was removed
				[[NSNotificationCenter defaultCenter] postNotificationName: kPnOnWindowRemoved object: stickyWindow];
			}
		}
		else
		{
			// remove from previous list if it is there
			[previousWindows removeObject: stickyWindow];
			
			if (([stickyWindow isSpecial] == NO) && ([mWindows containsObject: stickyWindow] == NO)) {
				didChangeWindows = YES;
				[mWindows addObject: stickyWindow];
				
				PNApplication*	application = [mApplications objectForKey: [NSNumber numberWithInt: [stickyWindow ownerPid]]];
				// if the application container does not contain a reference to the
				// application, create a new one
				if (application == nil) {
					didChangeApplications = YES;
					
					application = [[PNApplication alloc] initWithPid: [stickyWindow ownerPid] onDesktop: self];
					// and attach application
					[self attachApplication: application];
					// safe to release it now
					ZEN_RELEASE(application);
				}
				
				[application bindWindow: stickyWindow];
			}
		}
	}
	
	// All windows that are still left in the copied window list were not touched by the loop above and are no longer on the desktop, so we will remove them from the list of windows
	NSEnumerator*	previousWindowsIter = [previousWindows objectEnumerator];
	PNWindow*		checkWindow = nil;
	
	while (checkWindow = [previousWindowsIter nextObject]) {
		// remove…
		didChangeWindows = YES;
		
		[mWindows removeObject: checkWindow];
		
		// handle application windows
		PNApplication* application = [mApplications objectForKey: [NSNumber numberWithInt: [checkWindow ownerPid]]];
		if (application != nil) {
			// check if the application is still valid
			if ([application isValid]) {
				[application unbindWindow: checkWindow];
				// check if there are still windows contained in the application wrappers and
				// remove the application if there are none...
				if ([[application windows] count] == 0) {
					didChangeApplications = YES;
					[self detachApplication: application];
				}
			}
			else {
				didChangeApplications = YES;
				[self detachApplication: application];
			}
		}
		
		// and post notification that the window was removed
		[[NSNotificationCenter defaultCenter] postNotificationName: kPnOnWindowRemoved object: checkWindow];
	}
	
	// clear the list of previous windows
	[previousWindows removeAllObjects];
	
	// now post KVO notification
	if (didChangeWindows == YES) {
		// should not get performance issues as i doubt someone will have 1000 windows
		// open on his desktop. so we just post notification for whole array
		[self willChangeValueForKey: @"windows"];
		[self didChangeValueForKey: @"windows"];
	}
	if (didChangeApplications == YES) {
		[self willChangeValueForKey: @"applications"];
		[self didChangeValueForKey: @"applications"];
	}
}


#pragma mark -
#pragma mark Queries

/**
* @brief Finds the topmost window in the hierarchy containing the passed point
 *
 * @param point Point to search for
 *
 * The method will skip windows marked as special and windows not living on the
 * kCGNormalWindowLevel window level
 *
 */
- (PNWindow*) windowContainingPoint: (NSPoint) point 
{
	// iterate windows until we find a window containing the passed
	// point or we reached the end of the list. we will not consider
	// windows that were marked as special
	
	NSEnumerator*	windowIter	= [mWindows objectEnumerator];
	PNWindow*		window		= nil;
	
	while (window = [windowIter nextObject]) {
		//if ([window isSpecial])
		//	continue;
		//if ([window level] != kCGNormalWindowLevel)
		//	continue;
		
		// fetch the screen rect to check
		NSRect	windowRect = [window screenRectangle];
		
		if (NSMouseInRect(point, windowRect, NO)) {
			return window;
		}
	}
	
	return nil;
}

/**
* @brief Searches for the application with the passed pid
 *
 * @param pid Process id for the application to return
 *
 * @return	Returns the application instance matching the passed pid or @c nil
 *			if the desktop does not contain an application with the passed pid
 *
 */
- (PNApplication*) applicationForPid: (pid_t) pid 
{
	return [mApplications objectForKey: [NSNumber numberWithInt: pid]];
}

/**
* @brief Searches for the window with the passed window id
 *
 * @param window	Window to search for
 *
 * @return	Returns the window instance matching the passed id or @c nil if
 *			the desktop does not contain a window with the passed id
 *
 */
- (PNWindow*) windowForId: (CGSWindow) window 
{
    // iterate through the list of windows until we find the passed window id
    NSEnumerator*	windowIter      = [mWindows objectEnumerator];
    PNWindow*		currentWindow	= nil;
    
    while ((currentWindow = [windowIter nextObject])) {
        if ([currentWindow nativeWindow] == window)
            return currentWindow;
    }
    
    return nil;
}

/**
* @brief Searches for the bottom-most window
 *
 * @return	Returns the bottom-most window if any or nil
 *
 */
- (PNWindow*) bottomMostWindow {
	int nWindows = [mWindows count];
	if (nWindows == 0)
		return nil;
	
	PNWindow* window = (PNWindow*) [mWindows objectAtIndex: (nWindows - 1)];
	
	if (!window)
		return nil;
	
	return window;
}

#pragma mark -
#pragma mark Contact management

- (void)storeContacts:(NSMutableArray *)contacts {
	contacts = [contacts retain];
	ZEN_RELEASE(mContacts);
	mContacts = contacts;
}

- (NSMutableArray *)loadContacts {
	return mContacts;
}

#pragma mark -
#pragma mark Desktop contents management

- (void)storeDesktopItems {
	NSString *destinationPath = [self _activityStoreFolderCreatingIfNecessary:YES];
	BOOL result = [[NSFileManager defaultManager] moveDesktopItemsToFolder:destinationPath storeLocations:YES];
	if (!result) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText: NSLocalizedString(@"VTDesktopCleanFailed", @"Alert title")];
		[alert addButtonWithTitle: NSLocalizedString(@"VTDesktopCleanFailedOKButton", @"Quit the program")];
		[alert setInformativeText: [NSString stringWithFormat:NSLocalizedString(@"VTDesktopCleanFailedMessage", @"Your files couldn't be moved and might be in %@"), destinationPath]];
		[alert setAlertStyle: NSCriticalAlertStyle];
		[alert runModal];
		[[NSApplication sharedApplication] terminate:self];
        NSLog(@"Giornata exit value: 3");
        exit(3);
	}
}

- (void)loadDesktopItems {
	NSString *sourcePath = [self _activityStoreFolderCreatingIfNecessary:YES];
	BOOL result = [[NSFileManager defaultManager] moveItemsToDesktopFromFolder:sourcePath];
	if (!result) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText: NSLocalizedString(@"VTDesktopCleanFailed", @"Alert title")];
		[alert addButtonWithTitle: NSLocalizedString(@"VTDesktopCleanFailedOKButton", @"Quit the program")];
		[alert setInformativeText: [NSString stringWithFormat:NSLocalizedString(@"VTDesktopPopulateFailedMessage", @"Your files couldn't be moved and might be in %@"), sourcePath]];
		[alert setAlertStyle: NSCriticalAlertStyle];
		[alert runModal];
		[[NSApplication sharedApplication] terminate:self];
        NSLog(@"Giornata exit value: 3");
        exit(3);
	}
}

#pragma mark -
#pragma mark Desktop background

- (void) applyDesktopBackground {
	if ([self showsBackground]) {
		[[VTDesktopBackgroundHelper sharedInstance] setBackground: [self desktopBackground]];
	} else {
		[[VTDesktopBackgroundHelper sharedInstance] setBackground: [[VTDesktopBackgroundHelper sharedInstance] defaultBackground]];
	}
}

@end

#pragma mark -
#pragma mark Private API bits

@implementation PNDesktop (PrivateAPI)

- (id) _initWithId: (int) desktopId andTags: (NSArray*) tags uuid: (NSString*) uuid update: (BOOL) update 
{
	if (self = [super init]) {
		// initialise attributes
		mDesktopId			= desktopId;
		
		if (tags)
			mDesktopTags	= [tags copy];
		else
			mDesktopTags	= [[NSMutableArray array] retain];
		
		mWindows			= [[NSMutableArray array] retain];
		mApplications		= [[NSMutableDictionary dictionary] retain];
		
		if (uuid)
			mUUID			= [uuid copy];
		else
			mUUID			= [[PNDesktop _generateUID] retain];
		
		mDesktopBackgroundImagePath	= nil;
		mShowsBackground            = NO;
		
		mContacts					= [[NSMutableArray alloc] init];
		mPersistedWindowList		= [[NSMutableArray alloc] init];
		mThumbnail					= nil;
		mUnreadCount				= kPnDesktopUnknownUnreadCount;
		
		// build up list of windows we got in our workspace
		if (update == YES)
			[self updateDesktop];
		
		return self;
	}
	
	return nil;
}

+ (NSString*) _generateUID {
	NSCalendarDate *timeNow = [NSCalendarDate date];
	[timeNow setCalendarFormat:@"%Y-%m-%d %H-%M-%S"];
	return [NSString stringWithFormat:@"Activity %@", timeNow];
}

- (NSString*) _descriptiveActivityStoreFolderName {
	// Can't help you out if it's not a "real" activity
	if (mUUID == nil)
		return nil;
	
	// If there are no tags, fall back to the UUID
	if (mDesktopTags == nil || [mDesktopTags count] == 0)
		return mUUID;
	
	// Otherwise, construct a prettier name
	NSMutableString *tidyTagString = [[mDesktopTags componentsJoinedByString:@" "] mutableCopy];
	NSCharacterSet *nonlegalCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_ "] invertedSet];
	NSRange untidyRange = [tidyTagString rangeOfCharacterFromSet:nonlegalCharacters];
	while (untidyRange.location != NSNotFound) {
		[tidyTagString deleteCharactersInRange:untidyRange];
		untidyRange = [tidyTagString rangeOfCharacterFromSet:nonlegalCharacters];
	}
	
	return [NSString stringWithFormat:@"%@ (%@)", tidyTagString, [mUUID substringFromIndex:[@"Activity " length]]];
}

- (NSString*) _activityStoreFolderCreatingIfNecessary:(BOOL)createFolder {
	if (mUUID == nil)
		return nil;
	
	NSFileManager *fileman = [NSFileManager defaultManager];
	
	// First, check if there's a "pretty" version already established
	NSString *desktopStorage = [[VTDesktopController activityStorePath] stringByAppendingPathComponent:[self _descriptiveActivityStoreFolderName]];
	if ([fileman fileExistsAtPath:desktopStorage] == YES)
		return desktopStorage;
	
	// Then, check if there's an "old school" folder kicking around (for backwards compatibility)
	NSString *alternateDesktopStorage = [[VTDesktopController activityStorePath] stringByAppendingPathComponent:mUUID];
	if ([fileman fileExistsAtPath:alternateDesktopStorage] == YES) {
		// If there is, update it
		[fileman movePath:alternateDesktopStorage
				   toPath:desktopStorage
				  handler:NULL];
		
		return desktopStorage;
	}

	// If neither exists yet and the caller requested a bona-fide, created folder, then create it!
	if (createFolder)
		[fileman createDirectoryAtPath:desktopStorage attributes:nil];	
	
	return desktopStorage;
}

@end


#pragma mark -
@implementation PNDesktop (ApplicationList)
- (void) detachApplication: (PNApplication*) application 
{
	if (application == nil)
		return;
	if ([application bundlePath] == nil)
		return;
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		application, PNApplicationInstanceParam,
		self, PNApplicationDesktopParam,
		nil];
	
	[mApplications removeObjectForKey: [NSNumber numberWithInt: [application pid]]];
	
	// and post notification
	[[NSNotificationCenter defaultCenter] postNotificationName: PNApplicationWasRemoved object: [application bundlePath] userInfo: userInfo];
}

- (void) attachApplication: (PNApplication*) application 
{
	if (application == nil)
		return;
	if ([application bundlePath] == nil)
		return;
    
    // Don't add ourselves!!
    ProcessSerialNumber giornataPSN, appPSN;
    OSErr result = GetCurrentProcess(&giornataPSN);
    appPSN = [application psn];
    if (!result) {
        Boolean same;
        result = SameProcess(&appPSN, &giornataPSN, &same);
        if (!result && same == TRUE)
            return;
    }
    
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: application, PNApplicationInstanceParam, self, PNApplicationDesktopParam, nil];
	
	[mApplications setObject: application forKey: [NSNumber numberWithInt: [application pid]]];
	
	// and post notification
	[[NSNotificationCenter defaultCenter] postNotificationName: PNApplicationWasAdded object: [application bundlePath] userInfo: userInfo];
}

@end
