//
//  FSMonitorController.h
//  Giornata
//
//  Created by Stephen Voida on 2/12/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kFSFileChangedNotification	@"FSFileChangedNotification"
#define kFSFilePathKey				@"FSFilePathKey"

#define FSTaggingPauseDuration		1.5


@interface FSMonitorController : NSObject {
	NSTask *_task;
	NSPipe *_pipe;
	
	BOOL _taggingPaused;
	NSTimer *_resumptionTimer;
}

#pragma mark Lifetime 

+ (FSMonitorController *)sharedInstance; 

#pragma mark -
#pragma mark Startup/shutdown

- (void)startHelperTask;
- (void)stopHelperTask;

#pragma mark -
#pragma mark Task-related notification callbacks

- (void)dataReady:(NSNotification *)notification;
- (void)taskTerminated:(NSNotification *)notification;

#pragma mark -
#pragma mark Timer-related selectors/callbacks

- (void)pauseTagging;
- (void)resumeTagging:(NSTimer *)timer;

@end
