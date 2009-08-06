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

#import "VTPagerView.h"
#import "VTPagerCell.h"

#import "NSBezierPathPlate.h"
#import "NSUserDefaultsControllerKeyFactory.h"
#import "VTDesktopController.h"
#import "ZNMemoryManagementMacros.h"

#define kVtDragTypeSource		@"VTDragTypeSourceIndex"
#define kVtDragDataSourceIndex	@"VTDragSourceIndex"
#define kVtDragDataSourceUUID	@"VTDragSourceUUID"
#define kVtDraggable			@"VTDraggable"

enum
{
	kRoundedRadius      = 25,
    kCellSpacing        = 10,
    kHorizontalMargin   = 20
};


@interface VTPagerMatrix : NSMatrix {
	VTPagerCell*	mMouseDownCell; 
}

- (VTPagerCell*) mouseDownCell; 

@end 

@interface VTPagerView (Private) 
- (void) synchronizeDesktopLayout: (BOOL) rebuildCells; 
- (void) rebuildTrackingRects; 
@end 

#pragma mark -
@implementation VTPagerView

#pragma mark -
#pragma mark Lifetime 

- (id) initWithFrame: (NSRect) frame forLayout: (VTDesktopLayout*) layout {
	if (self = [super initWithFrame: frame]) {
		// attributes 
		ZEN_ASSIGN(mLayout, layout); 
		mTrackingRects = [[NSMutableArray alloc] init]; 
		
		// create matrix 
		NSSize cellSpacing = NSMakeSize(kCellSpacing, kCellSpacing); 
		
		// create the cell matrix 
		mPagerCells = [[VTPagerMatrix alloc] initWithFrame: frame]; 
		
		[mPagerCells setCellClass: [VTPagerCell class]]; 
        [mPagerCells setIntercellSpacing: cellSpacing]; 
		[mPagerCells setMode: NSRadioModeMatrix];
		[mPagerCells setAllowsEmptySelection: YES]; 
		[mPagerCells setSelectionByRect: NO];  
		[mPagerCells setDelegate: self]; 
        [mPagerCells setAutosizesCells:YES];
		
		[self addSubview: mPagerCells]; 
				
		// and listen for changes to the layout 
		[mLayout addObserver: self forKeyPath: @"desktops" options: NSKeyValueObservingOptionNew context: NULL]; 
		
		// default colors
		[self setBackgroundColor: [NSColor colorWithCalibratedRed: 0.0 green: 0.0 blue: 0.0 alpha: 0.85]]; 
		[self setBackgroundHighlightColor: [NSColor colorWithCalibratedRed: 0.5 green: 0.5 blue: 1.0 alpha: 0.50]]; 
		[self setTextColor: [NSColor whiteColor]]; 
		
		mCurrentDraggingTarget		= nil; 
			
		// and build up initial pager cells 
		[self synchronizeDesktopLayout: YES]; 
	
		[self registerForDraggedTypes: [NSArray arrayWithObjects: kVtDragTypeSource, nil]]; 
		
		return self; 
	}
	
	return nil; 
}

- (void) dealloc {
	// no notifications please 
	[mLayout removeObserver: self forKeyPath: @"desktops"]; 
	
	// remove all tracking rects 
	while ([mTrackingRects count] > 0) 
		[self removeTrackingRect: [[mTrackingRects objectAtIndex: 0] intValue]]; 
	
	ZEN_RELEASE(mTrackingRects); 
	ZEN_RELEASE(mLayout); 
	ZEN_RELEASE(mPagerCells); 
	ZEN_RELEASE(mBackgroundColor); 
	
	[super dealloc]; 
}

#pragma mark Attributes 
#pragma mark -
- (void) setSelectedDesktop: (PNDesktop*) desktop {
	// if we got passed nil, we deselect the currently selected desktop
	if (desktop == nil) {
		[mPagerCells deselectAllCells];
        
        // and get ready to re-select the current desktop!
		desktop = [[VTDesktopController sharedInstance] activeDesktop]; 
	}
	
	// find the cell that contains the desktop
	NSEnumerator*	cellIter	= [[mPagerCells cells] objectEnumerator]; 
	VTPagerCell*	cell		= nil;
	BOOL			found		= NO; 
	
	while ((found == NO) && (cell = [cellIter nextObject])) {
		if ([cell desktop] != nil && [[cell desktop] isEqualTo: desktop]) {
			found = YES; 
			break; 
		}
	}
	
	int row; 
	int col; 
	
	// highlight the new selected cell 
	[mPagerCells getRow: &row column: &col ofCell: cell]; 
	[mPagerCells highlightCell: YES atRow: row column: col]; 
	// select the cell 
	[mPagerCells selectCell: cell]; 	
}

- (PNDesktop*) selectedDesktop {
	if ([mPagerCells selectedCell] == nil)
		return nil; 
	
	return [(VTPagerCell*)[mPagerCells selectedCell] desktop];
}

#pragma mark -
- (NSMatrix*) desktopCollectionMatrix {
	return mPagerCells; 
}

#pragma mark -
- (void) setTextColor: (NSColor*) color {
	ZEN_ASSIGN(mTextColor, color); 
	[[mPagerCells cells] makeObjectsPerformSelector: @selector(setTextColor:) withObject: color]; 
	[self setNeedsDisplay: YES]; 
}

- (NSColor*) textColor {
	return mTextColor; 
}

- (void) setBackgroundColor: (NSColor*) color {
	// cache 
	ZEN_ASSIGN(mBackgroundColor, color); 
	// set for all cells 
	[[mPagerCells cells] makeObjectsPerformSelector: @selector(setBackgroundColor:) withObject: color]; 
	[mPagerCells setCellBackgroundColor: mBackgroundColor]; 
	[mPagerCells setBackgroundColor: mBackgroundColor]; 
	[mPagerCells setDrawsBackground: YES]; 
	[mPagerCells setDrawsCellBackground: YES]; 
	// and update ourselves 
	[self setNeedsDisplay: YES]; 
}

- (NSColor*) backgroundColor {
	return mBackgroundColor; 
}

- (void) setBackgroundHighlightColor: (NSColor*) color {
	ZEN_ASSIGN(mBackgroundHighlightColor, color); 
	[[mPagerCells cells] makeObjectsPerformSelector: @selector(setBackgroundHighlightColor:) withObject: color]; 
	[self setNeedsDisplay: YES]; 
}

- (NSColor*) backgroundHighlightColor {
	return mBackgroundHighlightColor; 
}


#pragma mark -
#pragma mark NSResponder 

- (BOOL) canBecomeKeyView {
	return YES; 	
}

- (BOOL) acceptsFirstResponder { 
	return YES;
} 

- (BOOL) becomeFirstResponder { 
	[[self window] setAcceptsMouseMovedEvents: YES];
	return YES;
} 

- (BOOL) resignFirstResponder { 
	[[self window] setAcceptsMouseMovedEvents: NO];	
	return YES;
} 

#pragma mark -

- (void) keyDown: (NSEvent*) event {
	// if we do not have any desktop selected, we will select the active one
		if ([self selectedDesktop] == nil) {
		[self setSelectedDesktop: [[VTDesktopController sharedInstance] activeDesktop]]; 
	}
	
	// first give it a shot on our own; we cannot use interpretKeyEvents: for our
	// purposes, as it seems to fail if we pressed some nice combination of keys,
	// like cmd+opt+uparrow; there we do not get any command selector called. is 
	// there a way to tell interpretKeyEvents: to ignore those modifiers? 
	NSString* characters	= [event charactersIgnoringModifiers]; 
		
	if ([characters length] == 0)
		return; 
	
	if ([characters characterAtIndex: 0] == NSLeftArrowFunctionKey) {
		[self moveLeft: event]; 
		return; 
	}
	if ([characters characterAtIndex: 0] == NSRightArrowFunctionKey) {
		[self moveRight: event]; 
		return; 
	}
	if ([characters characterAtIndex: 0] == NSTabCharacter) {
        [self moveRight: event]; 
		return; 
	}
    if ([characters characterAtIndex: 0] == NSBackTabCharacter) {
        [self moveLeft: event];
        return;
    }
	
	// cant handle the event, foward it... pass on to next responder 
	[[self window] keyDown: event];
}

#pragma mark -

- (void) moveLeft: (id) sender {
	// let the layout decide on the new desktop to select 
	[self setSelectedDesktop: [mLayout desktopInDirection: kVtDirectionWest ofDesktop: [self selectedDesktop]]]; 
}

- (void) moveRight: (id) sender {
	// let the layout decide on the new desktop to select 
	[self setSelectedDesktop: [mLayout desktopInDirection: kVtDirectionEast ofDesktop: [self selectedDesktop]]]; 
}

#pragma mark -

/**
 * TODO: Fixme 
 * Note that this is a workaround, as I thought events not handled by an NSResponder 
 * walk up the responder chain automagically. Did I do something in here to break the
 * chain? I suspect the keyDown: method is swallowing our flag keys, but I am not 
 * sure on how to work around that... 
 *
 */ 
- (void) flagsChanged: (NSEvent*) event {
	// pass on to next responder 
	[[self window] flagsChanged: event];
}

#pragma mark -

- (void) mouseEntered: (NSEvent*) event {
	// get the cell the mouse just entered and set it highlighted
	// it will stay highlighted until another cell is selected  
	int			trackingTag		= [event trackingNumber]; 
	NSCell*		trackedCell		= [mPagerCells cellWithTag: trackingTag]; 
	
	int row; 
	int col; 
	
	[mPagerCells getRow: &row column: &col ofCell: trackedCell]; 
	[mPagerCells highlightCell: YES atRow: row column: col]; 
	
	// and select the new cell 
	[mPagerCells selectCellWithTag: trackingTag]; 
}

- (void) mouseExited: (NSEvent*) event {
	// if we got no selected cell, return 
	if ([mPagerCells selectedCell] == nil)
		return; 
	
	// fetch the selected cell and unselect it 
	int			trackingTag		= [event trackingNumber]; 
	NSCell*		trackedCell		= [mPagerCells cellWithTag: trackingTag]; 
	
	if (trackedCell == [mPagerCells selectedCell])
		[self setSelectedDesktop:nil];
}

#pragma mark -
#pragma mark NSView

- (void) drawRect: (NSRect) aRect {
	// draw background 
	[[NSGraphicsContext currentContext] saveGraphicsState]; 
	NSBezierPath* backgroundPath = [NSBezierPath bezierPathForRoundedRect: aRect withRadius: kRoundedRadius]; 
    [mBackgroundColor set];
    [backgroundPath fill];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (void) resetCursorRects {
	[self rebuildTrackingRects]; 
	// remove all tracking rects we got 
	// remove all tracking rects 
	while ([mTrackingRects count] > 0) 
		[self removeTrackingRect: [[mTrackingRects objectAtIndex: 0] intValue]]; 
	[mTrackingRects removeAllObjects]; 
	
	// now create the new ones 
	NSEnumerator*	cellIter	= [[mPagerCells cells] objectEnumerator]; 
	VTPagerCell*	cell		= nil; 
		
	while (cell = [cellIter nextObject]) {
		if ([cell desktop] == nil)
			continue; 
		
		int row; 
		int col; 
				
		[mPagerCells getRow: &row column: &col ofCell: cell]; 
				
		NSRect cellFrame		= [mPagerCells cellFrameAtRow: row column: col]; 
		NSRect cellFrameView	= [mPagerCells convertRect: cellFrame toView: self]; 
				
		// add the new one 
		NSTrackingRectTag trackingRect = [self addTrackingRect: cellFrameView owner: self userData: self assumeInside: NO]; 
				
		[cell setTag: trackingRect]; 
	}
}

#pragma mark -
#pragma mark KVO Sink 

- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context: (void*) context {
	if ([keyPath isEqualToString: @"desktops"]) {
		[self synchronizeDesktopLayout: YES]; 
		[self rebuildTrackingRects]; 
	}
}

@end

#pragma mark -
@implementation VTPagerView (Private) 

- (void) synchronizeDesktopLayout: (BOOL) rebuildCells {
    int numberOfDesktops	= [[mLayout desktops] count]; 
    
	if (rebuildCells == YES) {
        while ([mPagerCells numberOfColumns] > 0) 
			[mPagerCells removeColumn: 0]; 
		
		// create cell layout 
		[mPagerCells renewRows: 1 columns: numberOfDesktops]; 
		
		// iterate over all desktops and assign them the to the cells 
		int desktopIndex  = 0; 
		
		for (desktopIndex = 0; desktopIndex < numberOfDesktops; desktopIndex++) {
			VTPagerCell*	cell	= [mPagerCells cellAtRow: 0 column: desktopIndex]; 
			PNDesktop*		desktop	= [[VTDesktopController sharedInstance] desktopWithUUID: [[mLayout desktops] objectAtIndex: desktopIndex]]; 

			[cell setDesktop: desktop]; 
			[cell setBackgroundColor: mBackgroundColor]; 
			[cell setBackgroundHighlightColor: mBackgroundHighlightColor]; 
			[cell setTextColor: mTextColor];
		}
		
		// and select the first cell
		[mPagerCells selectCellAtRow: 0 column: 0]; 
    }
	
    // Force the cells we've now got to fill out the matrix
    [mPagerCells sizeToFit];
    
    // now get the ideal size for the pager
    NSSize pagerSize    = [mPagerCells frame].size;
    
    // scale it down if it's too large to fit onscreen
    float maxWidth = [[NSScreen mainScreen] visibleFrame].size.width - kRoundedRadius - 2 * kHorizontalMargin;
    if (pagerSize.width > maxWidth) {
        pagerSize.height = pagerSize.height * maxWidth / pagerSize.width;
        pagerSize.width = maxWidth;
    }
    
	// since we draw a neat frame around that, we resize the window accordingly 
	NSSize viewSize		= pagerSize; 
	viewSize.width		= viewSize.width + kRoundedRadius; 
    viewSize.height		= viewSize.height + kRoundedRadius; 

	// we also need to set the frame of the pager cells accordingly 
	NSRect viewFrame	= [self frame]; 
	viewFrame.size		= viewSize; 
	NSRect pagerFrame   = NSMakeRect(kRoundedRadius / 2,
                                     kRoundedRadius / 2,
                                     pagerSize.width,
                                     pagerSize.height); 
    
	[mPagerCells setFrame: pagerFrame]; 
	[self setFrame: viewFrame]; 
	
	[[self window] setContentSize: viewSize];
	[self setNeedsDisplay: YES];
}

- (void) rebuildTrackingRects {
	// remove all tracking rects we got 
	// remove all tracking rects 
	while ([mTrackingRects count] > 0) 
		[self removeTrackingRect: [[mTrackingRects objectAtIndex: 0] intValue]]; 
	[mTrackingRects removeAllObjects]; 
	
	// now create the new ones 
	NSEnumerator*	cellIter	= [[mPagerCells cells] objectEnumerator]; 
	VTPagerCell*	cell		= nil; 
		
	while (cell = [cellIter nextObject]) {
		if ([cell desktop] == nil)
			continue; 
			
		int row; 
		int col; 
				
		[mPagerCells getRow: &row column: &col ofCell: cell]; 
				
		NSRect cellFrame		= [mPagerCells cellFrameAtRow: row column: col]; 
		NSRect cellFrameView	= [mPagerCells convertRect: cellFrame toView: self]; 
				
		// add the new one 
		NSTrackingRectTag trackingRect = [self addTrackingRect: cellFrameView owner: self userData: self assumeInside: NO]; 
				
		[cell setTag: trackingRect]; 
	}
}

#pragma mark -
#pragma mark Dragging 
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	return NSDragOperationCopy; 
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
	int row		= -1;
	int column	= -1; 
	
	if ([mPagerCells getRow: &row column: &column forPoint: [mPagerCells convertPoint: [sender draggingLocation] fromView: nil]] && 
		[[mPagerCells cellAtRow: row column: column] isEnabled]) { 
		
		VTPagerCell* cell = [mPagerCells cellAtRow: row column: column]; 
		if ([cell isEqual: mCurrentDraggingTarget]) 
			return NSDragOperationCopy; 
		
		if (mCurrentDraggingTarget) {
			[mCurrentDraggingTarget setDraggingTarget: NO];
			[mPagerCells updateCell: mCurrentDraggingTarget]; 
		}
		
		if ([cell isEqual: [(VTPagerMatrix*)mPagerCells mouseDownCell]]) {
			ZEN_RELEASE(mCurrentDraggingTarget); 
			return NSDragOperationNone; 
		}
		
		[cell setDraggingTarget: YES]; 
		[mPagerCells updateCell: cell]; 
		
		ZEN_ASSIGN(mCurrentDraggingTarget, cell); 
		
		return NSDragOperationCopy; 
	}
	
	if (mCurrentDraggingTarget) {
		[mCurrentDraggingTarget setDraggingTarget: NO]; 
		[mPagerCells updateCell: mCurrentDraggingTarget]; 
		
		ZEN_RELEASE(mCurrentDraggingTarget); 
	}
	
	return NSDragOperationNone; 
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
	NSDictionary* dataDictionary = [[sender draggingPasteboard] propertyListForType: kVtDragTypeSource]; 
	
	int row; 
	int col; 
	
	[mPagerCells getRow: &row column: &col ofCell: mCurrentDraggingTarget]; 

	// we will fetch indices of dragged cell and the target cell and exchange them 
	int			sourceIndex	= [[dataDictionary objectForKey: kVtDragDataSourceIndex] intValue]; 
	int			targetIndex = (row * [mPagerCells numberOfColumns]) + col; 
	
	[mCurrentDraggingTarget setDraggingTarget: NO]; 
	ZEN_RELEASE(mCurrentDraggingTarget); 
	
	[mLayout swapDesktopAtIndex: sourceIndex withIndex: targetIndex]; 
    
    // Reset selection
    [self setSelectedDesktop: nil];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {	
	return YES; 
}

- (NSDragOperation) draggingSourceOperationMarkForLocal: (BOOL) flag {
	return NSDragOperationCopy; 
} 

@end 

#pragma mark -
@implementation VTPagerMatrix 

- (id) initWithFrame: (NSRect) rect {
	if (self = [super initWithFrame: rect]) {
		mMouseDownCell = nil;
		
		return self; 
	}
	
	return nil; 
}

#pragma mark -
#pragma mark Attributes
- (VTPagerCell*) mouseDownCell {
	return mMouseDownCell; 
}

#pragma mark -
#pragma mark NSView 
- (BOOL) acceptsFirstMouse: (NSEvent *) theEvent { 
	return YES; 
}

- (void) mouseDown: (NSEvent*) event {
	int row		= -1;
	int column	= -1; 
	
	if ([self getRow: &row column: &column forPoint: [self convertPoint: [event locationInWindow] fromView: nil]] && 
			[[self cellAtRow: row column: column] isEnabled]) { 
			[self selectCellAtRow: row column: column]; 
		
		ZEN_ASSIGN(mMouseDownCell, [self cellAtRow: row column: column]); 
		
		return; 
	}
	
	[super mouseDown: event]; 
}

- (void) mouseUp: (NSEvent*) event {
	int row		= -1;
	int column	= -1; 
	
	if ([self getRow: &row column: &column forPoint: [self convertPoint: [event locationInWindow] fromView: nil]] && 
		[[self cellAtRow: row column: column] isEqual: mMouseDownCell]) { 
		
		ZEN_RELEASE(mMouseDownCell); 
		[[self cellAtRow: row column: column] performClick: self]; 
		
		return; 
	}
	
}

- (void) copyToPasteboard: (NSPasteboard*) pasteboard { 
	int selectedRow; 
	int selectedCol; 
	// get the selected row and cell to compute the index 
	[self getRow: &selectedRow column: &selectedCol ofCell: [self selectedCell]]; 
	
	NSString*		sourceUUID	= [[(VTPagerCell*)[self selectedCell] desktop] uuid]; 
	int				sourceIndex	= (selectedRow * [self numberOfColumns]) + selectedCol; 
		
	NSDictionary*	dataDict	= [NSDictionary dictionaryWithObjectsAndKeys: 
		[NSNumber numberWithInt: sourceIndex], kVtDragDataSourceIndex, 
		sourceUUID, kVtDragDataSourceUUID, 
		nil]; 
	
	[pasteboard declareTypes: [NSArray arrayWithObjects: kVtDragTypeSource, nil] owner: self]; 
	[pasteboard setPropertyList: dataDict forType: kVtDragTypeSource]; 
} 

- (void) mouseDragged: (NSEvent*) event {	
	NSPasteboard*	pboard; 
	NSImage*		image		= nil; 
	NSImage*		translucent	= nil; 
	NSPoint			dragPoint	= NSZeroPoint; 
	
	pboard = [NSPasteboard pasteboardWithName: NSDragPboard]; 
	[self copyToPasteboard: pboard]; 
	
	image		= [((VTPagerCell*)[self selectedCell]) drawToImage]; 
	dragPoint	= [self convertPoint: [event locationInWindow] fromView: nil]; 
	dragPoint.x -= ([image size].width * 0.5); 
	dragPoint.y += ([image size].height * 0.5); 
	
	translucent = [[[NSImage alloc] initWithSize: [image size]] autorelease]; 
	[translucent lockFocus]; 
	[image dissolveToPoint: NSZeroPoint fraction: 0.5]; 
	[translucent unlockFocus]; 
	
	[self dragImage: translucent 
				 at: dragPoint 
			 offset: NSZeroSize 
			  event: event 
		 pasteboard: pboard 
			 source: [self superview] 
		  slideBack: YES];
}

@end 
