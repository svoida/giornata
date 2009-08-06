/******************************************************************************
* 
* VirtueDesktops 
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller playback@users.sourceforge.net
* Copyright 2005-2006, Tony Arnold tony@tonyarnold.com
* 
* See COPYING for licensing details
* 
*****************************************************************************/ 

#import "VTPagerCell.h"

#import "NSScreenOverallScreen.h"
#import "NSBezierPathPlate.h"
#import "VTPagerAppletCell.h" 
#import "ZNMemoryManagementMacros.h"

enum
{
	kDefaultCellWidth		= 160,
    kDefaultCellRadius      = 18,
	kDefaultAppletSize		= 16,
	kDefaultInset			= 16,
	kDefaultNameSpacer		= 4,
	kDefaultAppletSpacer	= 4, 
}; 


@interface VTPagerCell(Private) 
- (void) createAppletCells; 

- (NSRect) frameAvailableForDesktopInFrame: (NSRect) aFrame;
- (NSRect) screenFrameToCellFrame: (NSRect) screenFrame ourFrame: (NSRect) frame;
@end 

#pragma mark -
@implementation VTPagerCell

#pragma mark -
#pragma mark Lifetime 
- (id) init {
	return [self initWithDesktop: nil]; 
}

- (id) initWithDesktop: (PNDesktop*) desktop {
	if (self = [super init]) {
		// attributes 
		[self setDesktop: desktop];
		
		// Desktop name text attributes
        NSMutableParagraphStyle *paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [paragraphStyle setAlignment:NSCenterTextAlignment];
        [paragraphStyle setLineBreakMode: NSLineBreakByTruncatingTail];
		
		mDesktopNameAttributes = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSColor whiteColor], NSForegroundColorAttributeName,
			[NSFont systemFontOfSize: 11], NSFontAttributeName,
            paragraphStyle, NSParagraphStyleAttributeName,
			nil] retain];

		// Subcell array 
		mAppletCells = [[NSMutableArray alloc] init]; 
		
		// Set our default colours
		[self setBackgroundColor: 
			[NSColor colorWithCalibratedRed: 0.00 
									  green: 0.00 
									   blue: 0.00 
									  alpha: 0.85]]; 
		
		[self setBackgroundHighlightColor: 
			[NSColor colorWithCalibratedRed: 0.22
									  green: 0.46 
									   blue: 0.84
									  alpha: 0.38]];
        
        [self setBorderColor: [NSColor whiteColor]];
		
		return self; 
	}
	
	return nil; 
}

- (void) dealloc {
	// bindings 
	[self unbind: @"title"]; 
	if (mDesktop)
		[mDesktop removeObserver: self forKeyPath: @"applications"]; 
	
	// attributes 
	ZEN_RELEASE(mDesktop); 
	ZEN_RELEASE(mDesktopNameAttributes); 
	ZEN_RELEASE(mAppletCells); 
	// colors 
	ZEN_RELEASE(mBackgroundColor); 
	ZEN_RELEASE(mBackgroundHighlightColor); 
	ZEN_RELEASE(mBorderColor); 
	
	[super dealloc]; 
}

#pragma mark -
#pragma mark Attributes 
- (void) setDesktop: (PNDesktop*) desktop {
	// undind desktop 
	[self unbind: @"title"]; 
	if (mDesktop)
		[mDesktop removeObserver: self forKeyPath: @"applications"]; 
	
	// assign desktop 
	ZEN_ASSIGN(mDesktop, desktop); 

	[self createAppletCells]; 

	// bind our title to the desktop name 
	if (mDesktop) {
		[self bind: @"title" toObject: mDesktop withKeyPath: @"displayName" options: nil]; 
		[mDesktop addObserver: self forKeyPath: @"applications" options: NSKeyValueObservingOptionNew context: NULL]; 
	}
}

- (PNDesktop*) desktop {
	return mDesktop; 
}

#pragma mark -
- (void) setDraggingTarget: (BOOL) flag {
	mDraggingTarget = flag; 
}

- (BOOL) isDraggingTarget {
	return mDraggingTarget; 
}


#pragma mark -

- (void) setTextColor: (NSColor*) color {
	[mDesktopNameAttributes setObject: color forKey: NSForegroundColorAttributeName]; 
}

- (void) setBackgroundColor: (NSColor*) color {
	ZEN_RELEASE(mBackgroundColor);
	
	// we are taking over the passed color and adjust a bit
    mBackgroundColor    = [color copy];
}

- (void) setBackgroundHighlightColor: (NSColor*) color {
	// completely take over color  
	ZEN_RELEASE(mBackgroundHighlightColor);
	
	mBackgroundHighlightColor			= [color copy];
}

- (void) setBorderColor: (NSColor*) color {
    ZEN_RELEASE(mBorderColor);
    
    mBorderColor                        = [color copy];
}

#pragma mark -
#pragma mark NSCell 

- (BOOL) isOpaque {
	return NO;
}

#pragma mark -

/**
 * @brief	Calculates the size needed to display the cell
 *
 * @todo	We have to introduce constants for those hard coded values and/or 
 *			use real values taken from the text and icon size...
 *
 */ 
- (NSSize) cellSize {
	NSSize neededSize; 
	NSSize screenSize	= [NSScreen overallFrame].size; 
	NSSize textSize		= [@"Doesn't really matter" sizeWithAttributes: mDesktopNameAttributes]; 
	
	neededSize.width = kDefaultCellWidth; 
	
	// the size depends on what we want to draw, but is generally dependant on the aspect 
	// ratio of the overall screen and the decorations we draw 
	float scaleHeight	= screenSize.height / screenSize.width;
	float neededHeight	= (neededSize.width - 2 * kDefaultInset) * scaleHeight; 
	
	neededHeight += kDefaultNameSpacer * 2 + textSize.height; 
	neededHeight += kDefaultAppletSpacer * 2 + kDefaultAppletSize; 
	
	// and set 
	neededSize.height = neededHeight; 
	
	return neededSize; 
}

#pragma mark -
- (void) drawWithFrame: (NSRect) frame inView: (NSView*) controlView {
	if ((mDesktop == nil) && (mDraggingTarget == NO))
		return; 
    
    // If we're smaller than we ought to be, then just render a miniaturized version and return
    // (this is kind of a hack to save the trouble of rewriting all of the cell renderer code)
    NSSize minimumSize = [self cellSize];
    if (frame.size.width < minimumSize.width ||
        frame.size.height < minimumSize.height) {
        NSImage *sourceImage = [self drawToImage];
        NSImage *flippedSourceImage = [[[NSImage alloc] initWithSize:[sourceImage size]] autorelease];
        [flippedSourceImage setFlipped: YES];
        [flippedSourceImage lockFocus];
        [sourceImage drawAtPoint: NSZeroPoint
                        fromRect: NSZeroRect
                       operation: NSCompositeSourceOver
                        fraction: 1.0];
        [flippedSourceImage unlockFocus];
        
        NSSize sourceSize = [sourceImage size];
        NSRect targetRect = NSMakeRect(frame.origin.x,
                                       frame.origin.y,
                                       frame.size.width,
                                       frame.size.height);
        if (sourceSize.width / sourceSize.height > targetRect.size.width / targetRect.size.height) {
            float newHeight = sourceSize.height * targetRect.size.width / sourceSize.width;
            targetRect.origin.y += (targetRect.size.height - newHeight) / 2.0;
            targetRect.size.height = newHeight;
        } else {
            float newWidth = sourceSize.width * targetRect.size.height / sourceSize.height;
            targetRect.origin.x += (targetRect.size.width - newWidth) / 2.0;
            targetRect.size.width = newWidth;
        }
        
		[flippedSourceImage drawInRect: targetRect
                       fromRect: NSZeroRect
                      operation: NSCompositeSourceOver
                       fraction: 1.0];
        
        return;
    }
    
    NSRect decorationFrame = NSMakeRect(frame.origin.x + 2,
                                        frame.origin.y + 2,
                                        frame.size.width - 4,
                                        frame.size.height - 4);
    NSBezierPath *decorationPath = [NSBezierPath bezierPathForRoundedRect: decorationFrame withRadius: kDefaultCellRadius];
    
	// fill the cell if the desktop is present and active
	if (mDesktop && (mDraggingTarget == NO) && [self isHighlighted]) {
        [mBackgroundHighlightColor set]; 

		[decorationPath fill]; 
	}
	
	// draw the border only if we're a drop target or if we're active
    if ([self isHighlighted] || mDraggingTarget) {
        [mBorderColor set]; 
        [decorationPath setLineWidth: 3]; 
        [decorationPath stroke]; 
    }
	
	// and continue for super 
	[super drawWithFrame: frame inView: controlView]; 
}

- (void) drawInteriorWithFrame: (NSRect) frame inView: (NSView*) controlView {
	// do not do anything if we have no desktop associated 
	if (mDesktop == nil)
		return; 
	
    // If we're smaller than we ought to be, just return (drawFrame already took care of it)
    NSSize minimumSize = [self cellSize];
    if (frame.size.width < minimumSize.width ||
        frame.size.height < minimumSize.height)
        return;
        
    // DRAWING COMPONENT: Desktop Name 
	// if this is the active desktop, we draw the name in bold 
	NSMutableDictionary* textAttributes = [[mDesktopNameAttributes mutableCopy] autorelease];
	if ([mDesktop visible]) {
		[textAttributes setObject: [NSFont boldSystemFontOfSize: 11] forKey: NSFontAttributeName];
	}
	
	NSSize  textSize	= [[mDesktop displayName] sizeWithAttributes: textAttributes];
    NSRect  textRect     = NSMakeRect(frame.origin.x + (kDefaultCellRadius / 2.0), frame.origin.y + kDefaultNameSpacer,
                                      frame.size.width - kDefaultCellRadius, textSize.height);
	
	[[mDesktop displayName] drawInRect: textRect withAttributes: textAttributes]; 
	
    // DRAWING COMPONENT: Desktop thumbnail (or the generic desktop icon if we don't have a snapshot yet)
	NSRect desktopFrameRect	= [self frameAvailableForDesktopInFrame: frame];
    
    if ([mDesktop thumbnail]) {
        NSSize thumbSize = [[mDesktop thumbnail] size];
        if (thumbSize.width / thumbSize.height > desktopFrameRect.size.width / desktopFrameRect.size.height) {
            float newHeight = thumbSize.height * desktopFrameRect.size.width / thumbSize.width;
            desktopFrameRect.origin.y += (desktopFrameRect.size.height - newHeight) / 2.0;
            desktopFrameRect.size.height = newHeight;
        } else {
            float newWidth = thumbSize.width * desktopFrameRect.size.height / thumbSize.height;
            desktopFrameRect.origin.x += (desktopFrameRect.size.width - newWidth) / 2.0;
            desktopFrameRect.size.width = newWidth;
        }
        
		[[mDesktop thumbnail] setFlipped: YES];
		[[mDesktop thumbnail] drawInRect: desktopFrameRect
								fromRect: NSZeroRect
							   operation: NSCompositeSourceOver
								fraction: 1.0];
	} else {
		NSImage *placeholder = [NSImage imageNamed:@"iconDesktopFolder.icns"];

        NSSize iconSize = [placeholder size];
        if (iconSize.width / iconSize.height > desktopFrameRect.size.width / desktopFrameRect.size.height) {
            float newHeight = iconSize.height * desktopFrameRect.size.width / iconSize.width;
            desktopFrameRect.origin.y += (desktopFrameRect.size.height - newHeight) / 2.0;
            desktopFrameRect.size.height = newHeight;
        } else {
            float newWidth = iconSize.width * desktopFrameRect.size.height / iconSize.height;
            desktopFrameRect.origin.x += (desktopFrameRect.size.width - newWidth) / 2.0;
            desktopFrameRect.size.width = newWidth;
        }

        [placeholder setFlipped: YES];
		[placeholder drawInRect: desktopFrameRect
					   fromRect: NSMakeRect(0.0, 0.0, iconSize.width, iconSize.height)
					  operation: NSCompositeSourceOver
					   fraction: 0.5];
	}
	
    // DRAWING COMPONENTS: Application icons
	NSEnumerator*	applicationIter = [mAppletCells objectEnumerator]; 
	NSImageCell*	applicationCell = nil; 
	
	NSPoint			currentPosition; 
	currentPosition.x	= frame.origin.x + 0.5 * (frame.size.width - ([mAppletCells count] * 16 + ([mAppletCells count] - 1) * kDefaultAppletSpacer)); 
	currentPosition.y	= frame.origin.y + (frame.size.height - kDefaultAppletSpacer - 16); 
	NSRect			currentRect; 
	
	while (applicationCell = [applicationIter nextObject]) {
		currentRect.origin = currentPosition; 
		currentRect.size   = NSMakeSize(16, 16); 
		
		[applicationCell drawWithFrame: currentRect inView: controlView]; 
		
		currentPosition.x += kDefaultAppletSize + kDefaultAppletSpacer;		
	}
}

- (NSImage*) drawToImage { 
	NSImage*			image	= nil; 
	NSRect				frame; 
	
	frame.size		= [self cellSize]; 
	frame.origin	= NSZeroPoint; 
	
	image = [[NSImage alloc] initWithSize: frame.size]; 
	[image setBackgroundColor: [NSColor clearColor]]; 
	
    [image setFlipped: YES]; 
	[image lockFocus]; 
	[self drawWithFrame: frame inView: [NSView focusView]]; 
	[self drawInteriorWithFrame: frame inView: [NSView focusView]]; 
	[image unlockFocus]; 
	
	return [image autorelease]; 
}

#pragma mark -
#pragma mark KVO Sink
- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context: (void*) context {
	if ([keyPath isEqualToString: @"applications"]) {
		[self createAppletCells]; 
	}
}

@end


#pragma mark -
@implementation VTPagerCell(Private) 

- (void) createAppletCells {
	[mAppletCells removeAllObjects]; 

	NSEnumerator*	appletIter	= [[mDesktop applications] objectEnumerator]; 
	PNApplication*	application	= nil; 
	
	while (application = [appletIter nextObject]) {
		// skip hidden applications from display 
		if ([application isHidden]) 
			continue; 
		
		VTPagerAppletCell* cell = [[VTPagerAppletCell alloc] initWithApplication: application]; 
		[mAppletCells addObject: cell]; 
		[cell release]; 
	}
}

#pragma mark -
- (void) resetTrackingRects {
}

- (NSRect) frameAvailableForDesktopInFrame: (NSRect) aFrame
{
	NSRect frameAvailable; 
	NSSize textSize = [[mDesktop displayName] sizeWithAttributes: mDesktopNameAttributes]; 
	
	// we do not restrict left orientation and the width except for spacers 
	frameAvailable.origin.x		= aFrame.origin.x + kDefaultInset; 
	frameAvailable.size.width	= aFrame.size.width - 2 * kDefaultInset; 
	// vertical orientation is restricted by the text size and spacers 
	frameAvailable.origin.y		= aFrame.origin.y + textSize.height + 2 * kDefaultNameSpacer;
	// hight is restricted also by icons 
	frameAvailable.size.height	= aFrame.size.height - textSize.height - 2 * kDefaultNameSpacer - kDefaultAppletSize - 2 * kDefaultAppletSpacer;
	
	return frameAvailable; 
}

- (NSRect) screenFrameToCellFrame: (NSRect) screenFrame ourFrame: (NSRect) frame
{
	NSSize screenSize		= [NSScreen overallFrame].size;
	NSRect frameAvailable	= [self frameAvailableForDesktopInFrame: frame]; 
	float  scaleWidth		= frameAvailable.size.width / screenSize.width; 
	
	// translate the passed screen frame to the scaled cell frame 	
	screenFrame.origin.x	= frameAvailable.origin.x + screenFrame.origin.x * scaleWidth;
	screenFrame.origin.y	= frameAvailable.origin.y + screenFrame.origin.y * scaleWidth;
	screenFrame.size.width  = screenFrame.size.width * scaleWidth;
	screenFrame.size.height = screenFrame.size.height * scaleWidth;
	
	return NSIntegralRect(screenFrame);
}

@end 
