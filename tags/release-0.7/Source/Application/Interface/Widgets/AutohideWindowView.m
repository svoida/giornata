//
//  AutohideWindowView.m
//  PeoplePalette
//
//  Created by Stephen Voida on 1/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "AutohideWindowView.h"

// Setting this larger makes for a smaller minimum palette, but
// prevents it overlapping the Dock on small screens
#define MIN_WINDOW_VERTICAL_MARGINS 50.0

static BOOL _autohideToLeft;


@interface AutohideWindowView(PrivateAPI)

- (void)_timerExpired:(NSTimer *)timer;
- (void)_clearTimer;

@end


@implementation AutohideWindowView

+ (void)initialize {
    if (self == [AutohideWindowView class]) {
		// This only gets loaded once per session
		_autohideToLeft = [[NSUserDefaults standardUserDefaults] boolForKey:kAWVAutohidingToLeft];
    }
}

- (id)initWithFrame:(NSRect)frameRect hideDelay:(float)hideDelay {	
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_hideDelay = hideDelay;
		_showDelay = 0.0;
		_oneShot = YES;
		_delegate = nil;
		_enabled = YES;
		_locked = NO;
		
		_hidden = NO;
		_trackingTag = 0;
		_timer = nil;
		
		// Be stretchy
		[self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	}
	
	return self;	
}

- (id)initWithFrame:(NSRect)frameRect hideDelay:(float)hideDelay showDelay:(float)showDelay visibleWidth:(float)visibleWidth hiddenWidth:(float)hiddenWidth initiallyHidden:(BOOL)initiallyHidden {
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_hideDelay = hideDelay;
		_showDelay = showDelay;
		_visibleWidth = visibleWidth;
		_hiddenWidth = hiddenWidth;
		_oneShot = NO;
		_delegate = nil;
		_enabled = YES;
		_locked = NO;
	
		_hidden = initiallyHidden;
		_preferredHeight = 0.0;
		_trackingTag = 0;
		_timer = nil;
		
		// Be stretchy
		[self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		[self setAutoresizesSubviews:YES];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(recomputeFrames:)
													 name:NSApplicationDidChangeScreenParametersNotification
												   object:nil];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self _clearTimer];
	
	if (_trackingTag > 0)
		[self removeTrackingRect:_trackingTag];
	
	[super dealloc];
}

- (float)hideDelay {
	return _hideDelay;
}

- (void)setHideDelay:(float)delay {
	// Won't take effect until the next time the timer is generated!
	_hideDelay = delay;
}

- (float)showDelay {
	return _showDelay;
}

- (void)setShowDelay:(float)delay {
	// Won't take effect until the next time the timer is generated!
	_showDelay = delay;
}

- (BOOL)enabled {
	return _enabled;
}

- (void)setEnabled:(BOOL)enabled {
	_enabled = enabled;
	
	if (enabled && !NSPointInRect([NSEvent mouseLocation], [[self window] frame]))
		[self hide];
	else if (!enabled)
		[self revealNow];
}

- (float)visibleWidth {
	return _visibleWidth;
}

- (float)hiddenWidth {
	return _hiddenWidth;
}

- (BOOL)oneShot {
	return _oneShot;
}

- (void)lock {
    [self revealNow];
	_locked = YES;
	
	[self _clearTimer];
}

- (void)unlock {
	_locked = NO;
    
	[self _clearTimer];
	if (!NSPointInRect([NSEvent mouseLocation], [[self window] frame]))
		[self hide];
}

- (BOOL)isLocked {
	return _locked;
}

- (BOOL)isAutohiding {
    return _hidden;
}

+ (BOOL)isAutohidingToLeft {
	return _autohideToLeft;
}

- (void)setDelegate:(id)delegate {
	if (delegate &&
		[delegate conformsToProtocol:@protocol(AutohideWindowViewDelegate)])
		_delegate = delegate;
}

- (id)delegate {
	return _delegate;
}

- (void)hide {
	if ([self window] && _enabled && !_locked && !_hidden && _timer == nil) {
		_timer = [[NSTimer scheduledTimerWithTimeInterval:_hideDelay target:self selector:@selector(_timerExpired:) userInfo:nil repeats:NO] retain]; 
	}
}

- (void)hideNow {
	if ([self window] && _enabled && !_locked && !_hidden) {
		// Check to see if the delegate overrides the hide (if there is one)
		if (_delegate && ![_delegate windowWillHide:[self window]])
			return;
		
		if (_oneShot)
			[[self window] orderOut:self];
		else
			[[self window] setFrame:_hiddenFrame display:YES animate:YES];
		
		_hidden = YES;
	}
	
	[self _clearTimer];
}

- (void)reveal {
	if ([self window] && _enabled && _hidden && _timer == nil) {
		_timer = [[NSTimer scheduledTimerWithTimeInterval:_showDelay target:self selector:@selector(_timerExpired:) userInfo:nil repeats:NO] retain];
	}
}

- (void)revealNow {
	if ([self window] && _enabled && _hidden) {
		// Check to see if the delegate overrides the show (if there is one)
		if (_delegate && ![_delegate windowWillShow:[self window]])
			return;
		
		// Can't come back from a one-shot hide (but you can clear a timer)
		if (!_oneShot) {
			[[self window] setFrame:_visibleFrame display:YES animate:YES];

			_hidden = NO;
		}
	}
	
	[self _clearTimer];
	
	if (!NSPointInRect([NSEvent mouseLocation], [[self window] frame]))
		[self hide];
}

- (void)recomputeFrames:(NSNotification *)notification {
	if ([self window] && !_oneShot) {
		NSRect originalFrame = [[self window] frame];
        
        // Find the relevant screen and its display dimensions
        NSScreen *cpScreen = [NSScreen mainScreen];     // A safe default?
        if (_autohideToLeft) {
            float minmaxCoordinate, currentCoordinate;
            unsigned screenIterator;
            int bestScreen = -1;
            NSArray *screenArray = [NSScreen screens];

            minmaxCoordinate = MAXFLOAT;
            for (screenIterator = 0; screenIterator < [screenArray count]; screenIterator++) {
                currentCoordinate = [[screenArray objectAtIndex:screenIterator] frame].origin.x;
                if (currentCoordinate < minmaxCoordinate) {
                    minmaxCoordinate = currentCoordinate;
                    bestScreen = (int)screenIterator;
                }
            }
            if (bestScreen > -1)
                cpScreen = [screenArray objectAtIndex:bestScreen];
        } else {
            float minmaxCoordinate, currentCoordinate;
            unsigned screenIterator;
            int bestScreen = -1;
            NSArray *screenArray = [NSScreen screens];

            minmaxCoordinate = -1.0 * MAXFLOAT;
            for (screenIterator = 0; screenIterator < [screenArray count]; screenIterator++) {
                currentCoordinate = [[screenArray objectAtIndex:screenIterator] frame].origin.x +
                                    [[screenArray objectAtIndex:screenIterator] frame].size.width;
                if (currentCoordinate > minmaxCoordinate) {
                    minmaxCoordinate = currentCoordinate;
                    bestScreen = (int)screenIterator;
                }
            }
            if (bestScreen > -1)
                cpScreen = [screenArray objectAtIndex:bestScreen];
        }
        NSRect screenFrame = [cpScreen frame];
		NSRect screenVisibleFrame = [cpScreen visibleFrame];

		// If this is the first time, remember our preferred height for subsequent recomputations
		if (_preferredHeight == 0.0)
			_preferredHeight = originalFrame.size.height;
		
		float optimizedHeight = fminf(_preferredHeight, screenVisibleFrame.size.height - (2 * MIN_WINDOW_VERTICAL_MARGINS));
		float optimizedYCoord = screenFrame.origin.y + (screenFrame.size.height - optimizedHeight) / 2.0;
		
		if (_autohideToLeft) {
			_visibleFrame = NSMakeRect(screenFrame.origin.x + _visibleWidth - originalFrame.size.width, optimizedYCoord,
									   originalFrame.size.width, optimizedHeight);
			_hiddenFrame = NSMakeRect(screenFrame.origin.x + _hiddenWidth - originalFrame.size.width, optimizedYCoord,
									  originalFrame.size.width, optimizedHeight);
		} else {
			_visibleFrame = NSMakeRect(screenFrame.origin.x + screenFrame.size.width - _visibleWidth, optimizedYCoord,
									   originalFrame.size.width, optimizedHeight);
			_hiddenFrame = NSMakeRect(screenFrame.origin.x + screenFrame.size.width - _hiddenWidth, optimizedYCoord,
									  originalFrame.size.width, optimizedHeight);
		}
		
		// Position the window where it needs to go quickly
		if (_hidden)
			[[self window] setFrame:_hiddenFrame display:YES animate:NO];
		else
			[[self window] setFrame:_visibleFrame display:YES animate:NO];
		
		// Finally, scoot ourselves to where we need to be
		[self setNeedsDisplay:YES];
	}
}

- (void)viewDidMoveToWindow {
    if ([self window]) {
		[self recomputeFrames:nil];
		
		_trackingTag = [self addTrackingRect:[self frame] owner:self userData:nil assumeInside:NO];
		
		if (!NSPointInRect([NSEvent mouseLocation], [[self window] frame]))
			[self hide];
		
		[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    }
}

- (void)viewDidEndLiveResize {
	[super viewDidEndLiveResize];
	
	// Recompute our tracking rectangle
	[self removeTrackingRect:_trackingTag];
	_trackingTag = [self addTrackingRect:[self frame] owner:self userData:nil assumeInside:NO];
}

- (void)mouseEntered:(NSEvent*)event {
	if ([self window] && _enabled && _hidden && !_locked)
		[self reveal];
	else
		[self _clearTimer];
	
	[[self window] makeKeyWindow];
}

- (void)mouseExited:(NSEvent *)event {
	[self hide];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if (_hidden)
		[self revealNow];
		
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
	if (_enabled && !NSPointInRect([NSEvent mouseLocation], [[self window] frame]))
		[self hide];
}

- (void)_timerExpired:(NSTimer *)timer {
    NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init];
    
	if (_hidden)
		[self revealNow];
	else
		[self hideNow];
    
    [tempPool release];
}

- (void)_clearTimer {
    if ([_timer isValid])
        [_timer invalidate];
    [_timer release];
    _timer = nil;
}

@end
