//
//  FSMonitorController.m
//  Giornata
//
//  Created by Stephen Voida on 2/12/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import "FSMonitorController.h"
#import <Security/Authorization.h>
#import <Security/AuthorizationTags.h>


@interface FSMonitorController (PrivateAPI)

- (void)disseminateFileChangeNotification:(NSData *)data;
- (BOOL)shouldTagFile:(NSString *)path;
- (void)clearResumptionTimer;

@end


@interface NSString (FSMonitorControllerExtensions)

- (BOOL)isPathInvisible;
- (BOOL)arePathContentsInvisible;

@end


@implementation FSMonitorController

#pragma mark Lifetime

+ (FSMonitorController *)sharedInstance {
	static FSMonitorController* ms_INSTANCE = nil; 
	
	if (ms_INSTANCE == nil)
		ms_INSTANCE = [[FSMonitorController alloc] init]; 
	
	return ms_INSTANCE; 
}

#pragma mark -

- (id) init {
	self = [super init];
	if (self != nil) {
		[self startHelperTask];
	}
	return self;
}

- (void) dealloc {
	[self stopHelperTask];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Startup/shutdown

- (void)startHelperTask {
	if (_task != nil)
		[self stopHelperTask];
	
	_task = [[NSTask alloc] init];
	_pipe = [[NSPipe alloc] init];
	_taggingPaused = NO;
	_resumptionTimer = nil;
	
	// Get the auxiliary task all set up
	[_task setLaunchPath:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"fsmonitor"]];
	[_task setStandardOutput:_pipe];
	
	// Set up auxiliary task-related notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(dataReady:)
												 name:NSFileHandleReadCompletionNotification
											   object:[_pipe fileHandleForReading]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(taskTerminated:)
												 name:NSTaskDidTerminateNotification
											   object:_task];
	
	// Get the pipe reading in the background
	[[_pipe fileHandleForReading] readInBackgroundAndNotify];
	
	// Launch the task
	[_task launch];
}

- (void)stopHelperTask {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if (_task && [_task isRunning])
		[_task terminate];
	
	[_pipe release];
	_pipe = nil;
	
	[_task release];
	_task = nil;
	
	[self clearResumptionTimer];
}

#pragma mark -
#pragma mark Task-related notification callbacks

- (void)dataReady:(NSNotification *)notification {
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
	[self disseminateFileChangeNotification:data];
	
	// Restart reading in background after each notification
	[[_pipe fileHandleForReading] readInBackgroundAndNotify];
}

- (void)taskTerminated:(NSNotification *)notification {
	if ([_task terminationStatus] == 13) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText: NSLocalizedString(@"FSMonPermsNeedsAttention", @"Alert title")];
		[alert addButtonWithTitle: NSLocalizedString(@"FSMonPermsOKButton", @"Go ahead and fix permissions")];
		[alert setInformativeText: NSLocalizedString(@"FSMonPermsMessage", @"Longer description about what will happen")];
		[alert setAlertStyle: NSWarningAlertStyle];
		[alert setDelegate: self];
		[alert runModal];
		
		[self stopHelperTask];
		
		AuthorizationRef authorizationRef;
		AuthorizationRights rights;
		AuthorizationItem items[1];
		items[0].name = kAuthorizationRightExecute;
		items[0].value = (void *)[[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"fsmonitor"] cString];
		items[0].valueLength = strlen(items[0].value);
		items[0].flags = 0;
		rights.count = 1;
		rights.items = items;
		AuthorizationFlags flags = kAuthorizationFlagDefaults | 
			kAuthorizationFlagInteractionAllowed | 
			kAuthorizationFlagExtendRights;
		
		OSStatus status = AuthorizationCreate (NULL,
											   kAuthorizationEmptyEnvironment, 
											   kAuthorizationFlagDefaults,
											   &authorizationRef);
		
		if (status != errAuthorizationSuccess) {
			NSLog(@"couldn't preauthorize: %d", status);
			return;
		}
		
		status = AuthorizationCopyRights(authorizationRef,
										 &rights,
										 kAuthorizationEmptyEnvironment,
										 flags,
										 NULL);
		if (status != errAuthorizationSuccess) {
			NSLog(@"authorization request failed: %d", status);
			return;
		}
		
		char *fsArgs[2];
		fsArgs[0] = "--self-repair";
		fsArgs[1] = NULL;
		
		status = AuthorizationExecuteWithPrivileges(authorizationRef,
													[[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"fsmonitor"] cString],
													kAuthorizationFlagDefaults,
													fsArgs,
													NULL);
		
		if (status != errAuthorizationSuccess)
			NSLog(@"trouble: not authorized: %d", status);
		else
			NSLog(@"successfully reset tool rights");
		
		if (authorizationRef != NULL)		
			AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
		
		// Wait for one second for the helper tool to reset and the filesystem locks to let go
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
		
		// Try again!
		[self startHelperTask];
	} else {
		// Flush data still in the pipe first
		NSData *leftInPipe = [[_pipe fileHandleForReading] readDataToEndOfFile];
		if (leftInPipe)
			[self disseminateFileChangeNotification:leftInPipe];
	}
}

#pragma mark -
#pragma mark Timer-related selectors/callbacks

- (void)pauseTagging {
	_taggingPaused = YES;
	
	// Clear old timer (if there is one); this effectively extends any existing pause
	[self clearResumptionTimer];

	_resumptionTimer = [[NSTimer scheduledTimerWithTimeInterval:FSTaggingPauseDuration
														target:self
													  selector:@selector(resumeTagging:)
													  userInfo:nil
													   repeats:NO] retain];
}

- (void)resumeTagging:(NSTimer *)timer {
	_taggingPaused = NO;

	[self clearResumptionTimer];
}

@end


@implementation FSMonitorController (PrivateAPI)

- (void)disseminateFileChangeNotification:(NSData *)data {
	if (data && !_taggingPaused) {
		NSString *bigString = [[NSString alloc] initWithData:data
													encoding:NSUTF8StringEncoding];
		
		NSArray *strings = [bigString componentsSeparatedByString:@"\n"];
		unsigned i;
		for (i = 0; i < [strings count]; i++) {
			if ([[strings objectAtIndex:i] isNotEqualTo:@""]) {
				// Filter to changes inside the home directory but outside of the Library folder
				NSArray *eventData = [[strings objectAtIndex:i] componentsSeparatedByString:@":"];
				NSString *path = [eventData lastObject];
				
				if ([self shouldTagFile:path]) {
					// Post it to the notification center
					[[NSNotificationCenter defaultCenter] postNotificationName:kFSFileChangedNotification
																		object:self
																	  userInfo:[NSDictionary dictionaryWithObject:path forKey:kFSFilePathKey]];
					
				}
			}
		}
		
		[bigString release];
	}
}

- (BOOL)shouldTagFile:(NSString *)path {
	NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	NSString *desktopDataFile = [desktopPath stringByAppendingPathComponent:@".DS_Store"];
	
	// Is it in our home directory?
	if (![path hasPrefix:NSHomeDirectory()])
		return NO;
	
	// Is it our home directory?
	if ([path compare:NSHomeDirectory()] == NSOrderedSame)
		return NO;
	
	// Is it in our Library folder?
	// TODO: Need to extend this to deal with emails!
	if ([path hasPrefix:[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]])
		return NO;
	
	// Is it the Desktop file? (Need to let that one through in any case...)
	if ([path compare:desktopDataFile] == NSOrderedSame)
		return YES;
	
	// Is the item itself invisible?
	if ([path isPathInvisible])
		return NO;
	
	// Are all of the parent components visible and expandable, too?
	// (We don't want to tag things inside of bundles, for example)
	NSArray *pathParts = [path pathComponents];
	NSString *partialPath = [NSString pathWithComponents:[NSArray arrayWithObject:[pathParts objectAtIndex:0]]];
	unsigned partialPathLength = 1;
	while (partialPathLength < [pathParts count]) {
		if ([partialPath arePathContentsInvisible])
			return NO;
		
		partialPath = [partialPath stringByAppendingPathComponent:[pathParts objectAtIndex:partialPathLength]];
		partialPathLength++;
	}
	
	// Everything looks happy...tag it.
	return YES;
}

- (void)clearResumptionTimer {
    if ([_resumptionTimer isValid])
        [_resumptionTimer invalidate];

    [_resumptionTimer release];
    _resumptionTimer = nil;
}

@end


@implementation NSString (FSMonitorControllerExtensions)

- (BOOL)isPathInvisible {
	LSItemInfoRecord itemInfo;
	
	if ([[self lastPathComponent] hasPrefix:@"."])
		return YES;
	
	CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)self, kCFURLPOSIXPathStyle, false);
	LSCopyItemInfoForURL(url, kLSRequestAllFlags, &itemInfo);
	
	return (itemInfo.flags & kLSItemInfoIsInvisible);
}

- (BOOL)arePathContentsInvisible {
	LSItemInfoRecord itemInfo;
	
	if ([[self lastPathComponent] hasPrefix:@"."])
		return YES;
	
	CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)self, kCFURLPOSIXPathStyle, false);
	LSCopyItemInfoForURL(url, kLSRequestAllFlags, &itemInfo);
	
	return (itemInfo.flags & (kLSItemInfoIsInvisible | kLSItemInfoIsPackage));
}

@end
