//
//  AutohideWindowView.h
//  PeoplePalette
//
//  Created by Stephen Voida on 1/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// User defaults key
#define kAWVAutohidingToLeft @"AWVAutohidingToLeft"


@protocol AutohideWindowViewDelegate
- (BOOL)windowWillHide:(NSWindow *)window;
- (BOOL)windowWillShow:(NSWindow *)window;
@end


@interface AutohideWindowView : NSView {
	float _hideDelay;
	float _showDelay;
	float _visibleWidth;
	float _hiddenWidth;
	BOOL _oneShot;
	BOOL _enabled;
	BOOL _locked;
	id _delegate;
	
	BOOL _hidden;
	float _preferredHeight;
	NSRect _visibleFrame;
	NSRect _hiddenFrame;
	NSTrackingRectTag _trackingTag;
	NSTimer *_timer;
}

- (id)initWithFrame:(NSRect)frameRect hideDelay:(float)hideDelay;
- (id)initWithFrame:(NSRect)frameRect hideDelay:(float)hideDelay showDelay:(float)showDelay visibleWidth:(float)visibleWidth hiddenWidth:(float)hiddenWidth initiallyHidden:(BOOL)initiallyHidden;

- (float)hideDelay;
- (void)setHideDelay:(float)delay;
- (float)showDelay;
- (void)setShowDelay:(float)delay;
- (BOOL)enabled;
- (void)setEnabled:(BOOL)enabled;
- (float)visibleWidth;
- (float)hiddenWidth;
- (BOOL)oneShot;

- (void)setDelegate:(id)delegate;
- (id)delegate;

- (void)lock;
- (void)unlock;
- (BOOL)isLocked;

- (BOOL)isAutohiding;

+ (BOOL)isAutohidingToLeft;

- (void)hide;
- (void)hideNow;
- (void)reveal;
- (void)revealNow;

- (void)recomputeFrames:(NSNotification *)notification;

@end
