#import "ActiveDesktop.h"

#import "ADTagDisplayTransformer.h"
#import "FSMonitorController.h"
#import "NSFileManagerExtendedAttributes.h"
#import "PNNotifications.h"
#import "PNWindow.h"
#import "VTNotifications.h"
#import "VTDesktopController.h"

#define CHANGE_TAGS_BUTTON_SIZE 72.0

#define ADFadeAnimationFrameRate    15.0
#define ADFadeAnimationDuration     0.5


@interface ActiveDesktop (Private)
- (void)_doFadeAnimationInThread:(id)sender;
@end


@implementation ActiveDesktop

#pragma mark -
#pragma mark Lifetime

- (id) init {
	self = [super init];
	if (self != nil) {
		if (![NSBundle loadNibNamed:@"ActiveDesktop" owner:self])
			NSLog(@"Error loading nib file for Active Desktop module");

		// Connect to the rest of the app
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileSystemChanged:) name:kFSFileChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(desktopChanged:) name:kVTOnApplicationStartedUp object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(desktopChanged:) name:kPnOnDesktopDidActivate object:nil];
	}
	
	return self;
}


- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if (_sharedSpace) {
		[_sharedSpace release];
		_sharedSpace = nil;
	}
	if (_desktopWindow) {
		[_desktopWindow release];
		_desktopWindow = nil;
	}
	
	[super dealloc];
}

- (void)awakeFromNib {
	// Set up the big AD window
	_fullSizeFrame = [[NSScreen mainScreen] frame];
	_desktopWindow = [[NSWindow alloc] initWithContentRect:_fullSizeFrame
												 styleMask:NSBorderlessWindowMask
												   backing:NSBackingStoreBuffered
													 defer:NO];
	[_desktopWindow setContentView:[_desktopLayout contentView]];
	[_desktopWindow setBackgroundColor:[NSColor clearColor]];
	[_desktopWindow setOpaque:NO];
	[_desktopWindow setIgnoresMouseEvents:YES];
	[_desktopWindow setLevel:kCGDesktopWindowLevel];
	
	// Make sure the tags don't paint a bunch of background everywhere
	[_tagDisplay setDrawsBackground:NO];
	
	// And set up the shared space box
	[_sharedSpace setGradientStartColor:[NSColor colorWithCalibratedRed:0.2 green:0.7 blue:0.2 alpha:0.75]];
	[_sharedSpace setGradientEndColor:[NSColor colorWithCalibratedRed:0.3 green:0.9 blue:0.3 alpha:0.75]];
	[_sharedSpace setBorderColor:[NSColor colorWithCalibratedRed:0.1 green:0.5 blue:0.1 alpha:1.0]];
	[self willChangeValueForKey:@"underlaysEnabled"];
	_underlaysEnabled = YES;
	[self didChangeValueForKey:@"underlaysEnabled"];
	
	[_desktopWindow orderBack:self];
	
	// Set up and display the tag icon as a UI for changing the tags
	_changeTagsButtonWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(20.0, _fullSizeFrame.size.height - 30.0 - CHANGE_TAGS_BUTTON_SIZE,
																			   CHANGE_TAGS_BUTTON_SIZE, CHANGE_TAGS_BUTTON_SIZE)
														  styleMask:NSBorderlessWindowMask
															backing:NSBackingStoreBuffered
															  defer:NO];
	[_changeTagsButtonWindow setBackgroundColor:[NSColor clearColor]];
	[_changeTagsButtonWindow setOpaque:NO];
	[_changeTagsButtonWindow setLevel:kCGDesktopWindowLevel + 1];
	
	// Add the button
	NSButton *changeTagsButton = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, CHANGE_TAGS_BUTTON_SIZE, CHANGE_TAGS_BUTTON_SIZE)];
	[changeTagsButton setBordered:NO];
	NSImage *scaledImage = [[NSImage alloc] initWithSize:NSMakeSize(CHANGE_TAGS_BUTTON_SIZE, CHANGE_TAGS_BUTTON_SIZE)];
	NSImage *buttonImage = [NSImage imageNamed:@"imageTags.png"];
	[scaledImage lockFocus];
	[buttonImage drawInRect:NSMakeRect(0.0, 0.0, CHANGE_TAGS_BUTTON_SIZE, CHANGE_TAGS_BUTTON_SIZE)
				   fromRect:NSMakeRect(0.0, 0.0, [buttonImage size].width, [buttonImage size].height)
				  operation:NSCompositeSourceOver
				   fraction:0.75];
	[scaledImage unlockFocus];
	[changeTagsButton setImage:scaledImage];
	[changeTagsButton setTarget:self];
	[changeTagsButton setAction:@selector(changeTags:)];
	[[_changeTagsButtonWindow contentView] addSubview:changeTagsButton];
	
	[_changeTagsButtonWindow orderBack:self];
	
	// Figure out what our active desktop is (and broadcast it)
	[self willChangeValueForKey:@"currentDesktop"];
	_currentDesktop = [[VTDesktopController sharedInstance] activeDesktop];
	[self didChangeValueForKey:@"currentDesktop"];
	
	// Connect the tag display to our active desktop (now that we know what it is)
	[_tagDisplay bind:@"value" toObject:self withKeyPath:@"currentDesktop.displayName"
			  options:[NSDictionary dictionaryWithObject:[[[ADTagDisplayTransformer alloc] init] autorelease] forKey:NSValueTransformerBindingOption]];
	
	// Register for notifications should the desktop change shape (which could wreak havoc on the active desktop!)
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(displayResized:)
												 name:NSApplicationDidChangeScreenParametersNotification
											   object:nil];
}

#pragma mark -
#pragma mark Accessors

- (BOOL)underlaysEnabled {
	return _underlaysEnabled;
}

- (PNDesktop *)currentDesktop {
	return _currentDesktop;
}

#pragma mark -
#pragma mark Action callbacks
- (IBAction)commitTagEdits:(id)sender {
	NSString *oldDisplayName = [[[VTDesktopController sharedInstance] activeDesktop] displayName];
	[[[VTDesktopController sharedInstance] activeDesktop] setTags:[_tagField objectValue]];
	if (sender)
		NSLog(@"Updated activity tags from \"%@\" to \"%@\"",
			  oldDisplayName, [[[VTDesktopController sharedInstance] activeDesktop] displayName]);
	else
		NSLog(@"RETROACTIVELY updated activity tags from \"%@\" to \"%@\"",
			  oldDisplayName, [[[VTDesktopController sharedInstance] activeDesktop] displayName]);
	
	[self desktopChanged:nil];
	
	[_tagEditingPanel orderOut:self];
}

- (IBAction)commitTagEditsRetroactively:(id)sender {
	NSArray *oldTags = [[[VTDesktopController sharedInstance] activeDesktop] tags];
	NSArray *newTags = [_tagField objectValue];

	// We also can't help out if there weren't any old tags
	if ([oldTags count] > 0) {
		// Figure out what the user added
		NSMutableArray *tagsToAdd = [[NSMutableArray alloc] init];
		NSEnumerator *tagEnumerator = [newTags objectEnumerator];
		NSString *tag;
		while (tag = [tagEnumerator nextObject])
			if (![oldTags containsObject:tag])
				[tagsToAdd addObject:tag];
		
		// Find all the files that we've tagged in the past and
		// add tags as required to bring them up to speed
		NSString *predicateHelper = [NSString stringWithFormat:@"(kMDItemFinderComment == '@%@'w)",
			[oldTags componentsJoinedByString:@"'w) && (kMDItemFinderComment == '@"]];
		
		MDQueryRef query;
		query = MDQueryCreate(kCFAllocatorDefault,
							  (CFStringRef)predicateHelper,
							  NULL,
							  NULL);
		MDQuerySetSearchScope(query, (CFArrayRef)[NSArray arrayWithObject:(id)kMDQueryScopeHome], 0);
		MDQueryExecute(query, kMDQuerySynchronous);
		
		int i = 0;
		while (i < MDQueryGetResultCount(query)) {
			MDItemRef item = (MDItemRef)MDQueryGetResultAtIndex(query, i++);
			NSString *filename = (NSString *)MDItemCopyAttribute(item, kMDItemPath);
			
			[[NSFileManager defaultManager] addFileTags:tagsToAdd
									  andRemoveFileTags:nil
												 atPath:filename];
		}
		
		CFRelease(query);
		query = NULL;
	}	
	
	// Now, go ahead and start updating the current desktop
	[self commitTagEdits:nil];
}

#pragma mark -
#pragma mark NotificationCenter callbacks

- (void)desktopChanged:(NSNotification*)notification {
	// If this notification is from an application start-up (e.g., not from a desktop becoming active), then pin the window
	if (![[notification object] isMemberOfClass:[PNDesktop class]]) {
		PNWindow *desktopWindow = [PNWindow windowWithNSWindow:_desktopWindow];
		
		[desktopWindow setIgnoredByExpose:YES];
		[desktopWindow setSticky:YES];
	}
	
	// Update our desktop pointer
	[self willChangeValueForKey:@"currentDesktop"];
	_currentDesktop = [[VTDesktopController sharedInstance] activeDesktop];
	[self didChangeValueForKey:@"currentDesktop"];
}

- (void)displayResized:(NSNotification *)notification {
     NSRect currentFrame = [[NSScreen mainScreen] frame];
	if (currentFrame.size.width == _fullSizeFrame.size.width &&
		currentFrame.size.height == _fullSizeFrame.size.height) {
		// Check to see if we're already on
		if (_underlaysEnabled == YES)
			return;

		// Do the swap!
		[self willChangeValueForKey:@"underlaysEnabled"];
		_underlaysEnabled = YES;
		[self didChangeValueForKey:@"underlaysEnabled"];
	} else {
		// Check to see if we're already off
		if (_underlaysEnabled = NO)
			return;
		
		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ADOverrideScreenChangeWarning"]) {			
			[_screenChangeWarningPanel orderFrontRegardless];
		}
		
		// Do the swap!
		[self willChangeValueForKey:@"underlaysEnabled"];
		_underlaysEnabled = NO;
		[self didChangeValueForKey:@"underlaysEnabled"];
	}
}

- (void)fileSystemChanged:(NSNotification*)notification {
	NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	NSString *desktopDataFile = [desktopPath stringByAppendingPathComponent:@".DS_Store"];
	NSString *filename = [[notification userInfo] objectForKey:kFSFilePathKey];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Check for changes on the Desktop
	if (_underlaysEnabled && [filename compare:desktopDataFile] == NSOrderedSame) {
		
		NSEnumerator *desktopItems = [[fileManager directoryContentsAtPath:desktopPath] objectEnumerator];
		NSString *desktopItem;
		while (desktopItem = [desktopItems nextObject]) {
			// Where is this dekstop item?
			NSString *fullPathToDesktopItem = [desktopPath stringByAppendingPathComponent:desktopItem];
			NSPoint locationOfDesktopItem = [fileManager desktopPositionAtPath:fullPathToDesktopItem];
			
			// Have to flip the y coordinate since it's using the opposite coordinate system
			locationOfDesktopItem.y = [[NSScreen mainScreen] frame].size.height - locationOfDesktopItem.y;
			
			// If it's in the shared box, make sure it's shared and update the highlight visualization
			if (NSPointInRect(locationOfDesktopItem, [_sharedSpace frame])) {
				// update sharing state for file: on
				// (this code was pulled from the deployed version for stability reasons)
				[fileManager setLabelIndex:kFSColorLabelGreen atPath:fullPathToDesktopItem];
			} else {
				// update sharing state for file: off
				// (this code was pulled from the deployed version for stability reasons)
				[fileManager setLabelIndex:kFSColorLabelNone atPath:fullPathToDesktopItem];
			}
		}
	}
	
	// The path has already been pre-screened for our tagging criteria (in FSMonitorController)
	[fileManager addFileTags:[[[[VTDesktopController sharedInstance] activeDesktop] tags] arrayByAddingObject:@"#TAGGED#"]
		   andRemoveFileTags:nil
					  atPath:filename];
}


#pragma mark -
#pragma mark ChangeTagsButton action callback

- (void)changeTags:(id)sender {
	// Set the tag editor's attributes and display it
	[_tagEditingPanel setFrameOrigin:NSMakePoint([NSEvent mouseLocation].x - 10.0,
												 [NSEvent mouseLocation].y - [_tagEditingPanel frame].size.height  + 10.0)];
	[_tagField setTokenizingCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[_tagField setObjectValue:[[[VTDesktopController sharedInstance] activeDesktop] tags]];

	[_tagEditingPanel makeKeyAndOrderFront:self];
}

#pragma mark -
#pragma mark Presentation Mode support

- (void)fadeToTransparent:(BOOL)toTransparent {
    _fadeToTransparent = toTransparent;
    
    // Spin this off as a new thread so we can do a quick, naive animation
    [NSThread detachNewThreadSelector:@selector(_doFadeAnimationInThread:)
                             toTarget:self
                           withObject:nil];
}

@end


@implementation ActiveDesktop (Private)

- (void)_doFadeAnimationInThread:(id)sender {
    NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init];
    
    // Double check that our constants haven't been set maliciously
    if (ADFadeAnimationDuration > 0.0 && ADFadeAnimationDuration > 0.0) {
        unsigned numberOfSteps = (unsigned)(ADFadeAnimationFrameRate * ADFadeAnimationDuration);
        float alphaStep = (_fadeToTransparent) ? (-1.0 / numberOfSteps) : (1.0 / numberOfSteps);
        float currentAlpha = (_fadeToTransparent) ? 1.0 : 0.0;
        
        unsigned currentStep = 0;
        while (currentStep < numberOfSteps) {
            currentStep++;
            currentAlpha += alphaStep;
            [_desktopWindow setAlphaValue:currentAlpha];
            [_changeTagsButtonWindow setAlphaValue:currentAlpha];
            
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(1.0 / ADFadeAnimationFrameRate)]];
        }
    }
    
    // Make sure we're set at the proper value when we stop
    if (_fadeToTransparent) {
        [_desktopWindow setAlphaValue:0.0];
        [_changeTagsButtonWindow setAlphaValue:0.0];
    } else {
        [_desktopWindow setAlphaValue:1.0];
        [_changeTagsButtonWindow setAlphaValue:1.0];
    }
    
    [tempPool release];
}

@end
