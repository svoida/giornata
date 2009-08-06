//
//  HUDWindow.h
//  HUDWindow
//
//  Created by Matt Gemmell on 12/02/2006.
//  Modified by Stephen Voida on 1/21/2006.
//  Copyright 2006 Magic Aubergine. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define HW_RADIUS 6.0

@interface HUDWindow : NSPanel {
    BOOL _forceDisplay;
	unsigned int _originalStyleMask;
	NSColor *_mainColor;
	NSColor *_titleColor;
	NSColor *_trimColor;
	float _opacity;
}

- (void)setMainColor:(NSColor *)mainColor;
- (NSColor *)mainColor;
- (void)setTrimColor:(NSColor *)trimColor;
- (NSColor *)trimColor;
- (void)setTitleColor:(NSColor *)titleColor;
- (NSColor *)titleColor;
- (void)setOpacity:(float)opacity;
- (float)opacity;

@end
