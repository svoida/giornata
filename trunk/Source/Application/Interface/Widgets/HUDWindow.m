//
//  HUDWindow.m
//  HUDWindow
//
//  Created by Matt Gemmell on 12/02/2006.
//  Modified by Stephen Voida on 1/21/2006.
//  Copyright 2006 Magic Aubergine. All rights reserved.
//

#import "HUDWindow.h"


#define HW_CLOSE_BUTTON_SIZE 13.0
#define HW_DEFAULT_MAIN_BRIGHTNESS 0.1
#define HW_DEFAULT_OPACITY 0.75
#define HW_DEFAULT_TRIM_BRIGHTNESS 0.25
#define HW_DECORATION_WIDTH 10.0
#define HW_DECORATION_HEIGHT 20.0
#define HW_TITLEBAR_HEIGHT 19.0


@interface HUDWindow(PrivateAPI)

- (NSColor *)_sizedHUDBackground;
- (void)_addCloseWidget;

@end


@implementation HUDWindow

- (id)initWithContentRect:(NSRect)contentRect 
                styleMask:(unsigned int)styleMask 
                  backing:(NSBackingStoreType)bufferingType 
                    defer:(BOOL)flag {
    if (self = [super initWithContentRect:contentRect 
                                styleMask:NSBorderlessWindowMask 
                                  backing:bufferingType 
                                    defer:flag]) {
        
		_originalStyleMask = styleMask;

        [self setAlphaValue:1.0];
        [self setOpaque:NO];
        [self setHasShadow:YES];
		[self setHidesOnDeactivate:NO];
		[self setLevel:NSFloatingWindowLevel];
		[self setMovableByWindowBackground:NO];

        _forceDisplay = NO;

		_mainColor = [[NSColor colorWithCalibratedWhite:HW_DEFAULT_MAIN_BRIGHTNESS alpha:1.0] retain]; 
		_trimColor = [[NSColor colorWithCalibratedWhite:HW_DEFAULT_TRIM_BRIGHTNESS alpha:1.0] retain];
		_titleColor = [[NSColor whiteColor] retain];
		_opacity = HW_DEFAULT_OPACITY;
		
		[self setBackgroundColor:[self _sizedHUDBackground]];
        
		if (_originalStyleMask & NSClosableWindowMask)
			[self _addCloseWidget];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(windowDidResize:) 
                                                     name:NSWindowDidResizeNotification 
                                                   object:self];
        
        return self;
    }
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:self];    
	
	[_mainColor release];
	[_trimColor release];
	[_titleColor release];
	
    [super dealloc];
}


// ----------------------------------------------------------------------------
//  Accessor methods
// ----------------------------------------------------------------------------
- (void)setMainColor:(NSColor *)mainColor {
	[mainColor retain];
	[_mainColor release];
	_mainColor = mainColor;
	
	_forceDisplay = YES;
	[self windowDidResize:nil];
	_forceDisplay = NO;
}

- (NSColor *)mainColor {
	return _mainColor;
}

- (void)setTrimColor:(NSColor *)trimColor {
	[trimColor retain];
	[_trimColor release];
	_trimColor = trimColor;
	
	_forceDisplay = YES;
	[self windowDidResize:nil];
	_forceDisplay = NO;
}

- (NSColor *)trimColor {
	return _trimColor;
}

- (void)setTitleColor:(NSColor *)titleColor {
	[titleColor retain];
	[_titleColor release];
	_titleColor = titleColor;
	
	_forceDisplay = YES;
	[self windowDidResize:nil];
	_forceDisplay = NO;
}

- (NSColor *)titleColor {
	return _titleColor;
}

- (void)setOpacity:(float)opacity {
	_opacity = opacity;
	
	_forceDisplay = YES;
	[self windowDidResize:nil];
	_forceDisplay = NO;
}

- (float)opacity {
	return _opacity;
}

// ----------------------------------------------------------------------------
//  NSPanel overrides
// ----------------------------------------------------------------------------
- (void)awakeFromNib {
	if (_originalStyleMask & (NSTitledWindowMask | NSClosableWindowMask))
		[self _addCloseWidget];
}

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)displayFlag animate:(BOOL)animationFlag {
    _forceDisplay = YES;
    [super setFrame:frameRect display:displayFlag animate:animationFlag];
    _forceDisplay = NO;
}

- (void)setTitle:(NSString *)value {
    [super setTitle:value];
    [self windowDidResize:nil];
}

- (void)windowDidResize:(NSNotification *)aNotification {
    [self setBackgroundColor:[self _sizedHUDBackground]];
    if (_forceDisplay) {
        [self display];
    }
}


// ----------------------------------------------------------------------------
//  Private API implementations
// ----------------------------------------------------------------------------
- (void)_addCloseWidget {
    NSButton *closeButton = [[NSButton alloc] initWithFrame:NSMakeRect(HW_RADIUS / 2.0, [self frame].size.height - (HW_TITLEBAR_HEIGHT - (HW_RADIUS / 2.0)), 
                                                                       HW_CLOSE_BUTTON_SIZE, HW_CLOSE_BUTTON_SIZE)];
    
    [[self contentView] addSubview:closeButton];
    [closeButton setBezelStyle:NSRoundedBezelStyle];
    [closeButton setButtonType:NSMomentaryChangeButton];
    [closeButton setBordered:NO];
    [closeButton setImage:[NSImage imageNamed:@"hud_titlebar-close"]];
    [closeButton setTitle:@""];
    [closeButton setImagePosition:NSImageBelow];
    [closeButton setTarget:self];
    [closeButton setFocusRingType:NSFocusRingTypeNone];
    [closeButton setAction:@selector(orderOut:)];
	[closeButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
    [closeButton release];
}

- (NSColor *)_sizedHUDBackground {
    NSImage *bg = [[NSImage alloc] initWithSize:[self frame].size];
    [bg lockFocus];
    
    // Make background path	
    NSRect bgRect = NSMakeRect(0, 0, [bg size].width, [bg size].height - HW_TITLEBAR_HEIGHT);
    int minX = NSMinX(bgRect);
    int midX = NSMidX(bgRect);
    int maxX = NSMaxX(bgRect);
    int minY = NSMinY(bgRect);
    int midY = NSMidY(bgRect);
    int maxY = NSMaxY(bgRect);
    NSBezierPath *bgPath = [NSBezierPath bezierPath];
    
    // Bottom edge and bottom-right curve
    [bgPath moveToPoint:NSMakePoint(midX, minY)];
    [bgPath appendBezierPathWithArcFromPoint:NSMakePoint(maxX, minY) 
                                     toPoint:NSMakePoint(maxX, midY) 
                                      radius:HW_RADIUS];
    
    [bgPath lineToPoint:NSMakePoint(maxX, maxY)];
    [bgPath lineToPoint:NSMakePoint(minX, maxY)];
    
    // Top edge and top-left curve
    [bgPath appendBezierPathWithArcFromPoint:NSMakePoint(minX, maxY) 
                                     toPoint:NSMakePoint(minX, midY) 
                                      radius:HW_RADIUS];
    
    // Left edge and bottom-left curve
    [bgPath appendBezierPathWithArcFromPoint:bgRect.origin 
                                     toPoint:NSMakePoint(midX, minY) 
                                      radius:HW_RADIUS];
    [bgPath closePath];
    
    // Composite main color into bg
	[[_mainColor colorWithAlphaComponent:_opacity] set];
    [bgPath fill];
    
	// Make titlebar path
	NSRect titlebarRect = NSMakeRect(0.0, [bg size].height - HW_TITLEBAR_HEIGHT, [bg size].width, HW_TITLEBAR_HEIGHT);
	minX = NSMinX(titlebarRect);
	midX = NSMidX(titlebarRect);
	maxX = NSMaxX(titlebarRect);
	minY = NSMinY(titlebarRect);
	midY = NSMidY(titlebarRect);
	maxY = NSMaxY(titlebarRect);
	NSBezierPath *titlePath = [NSBezierPath bezierPath];
	
	// Bottom edge and bottom-right curve
	[titlePath moveToPoint:NSMakePoint(minX, minY)];
	[titlePath lineToPoint:NSMakePoint(maxX, minY)];
	
	// Right edge and top-right curve
	[titlePath appendBezierPathWithArcFromPoint:NSMakePoint(maxX, maxY) 
										toPoint:NSMakePoint(midX, maxY) 
										 radius:HW_RADIUS];
	
	// Top edge and top-left curve
	[titlePath appendBezierPathWithArcFromPoint:NSMakePoint(minX, maxY) 
										toPoint:NSMakePoint(minX, minY) 
										 radius:HW_RADIUS];
	
	[titlePath closePath];
	
	if (_originalStyleMask & NSTitledWindowMask) {
		// Titlebar
		[[_trimColor colorWithAlphaComponent:_opacity] set];
		[titlePath fill];
		
		// Title
		NSFont *titleFont = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
		NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
		[paraStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
		[paraStyle setAlignment:NSCenterTextAlignment];
		[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		NSMutableDictionary *titleAttrs = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			titleFont, NSFontAttributeName,
			_titleColor, NSForegroundColorAttributeName,
			[[paraStyle copy] autorelease], NSParagraphStyleAttributeName,
			nil];
		
		NSSize titleSize = [[self title] sizeWithAttributes:titleAttrs];
		// We vertically centre the title in the titlbar area, and we also horizontally 
		// inset the title by 19px, to allow for the 3px space from window's edge to close-widget, 
		// plus 13px for the close widget itself, plus another 3px space on the other side of 
		// the widget.
		NSRect titleRect = NSInsetRect(titlebarRect, HW_TITLEBAR_HEIGHT, (titlebarRect.size.height - titleSize.height) / 2.0);
		[[self title] drawInRect:titleRect withAttributes:titleAttrs];
	} else {
		// Just draw the titlebar section using the main fill (effectively no titlebar region)
		[titlePath fill];
	}

    [bg unlockFocus];
    
    return [NSColor colorWithPatternImage:[bg autorelease]];
}

@end
