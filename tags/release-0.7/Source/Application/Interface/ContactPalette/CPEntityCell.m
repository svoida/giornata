//
//  CPEntityCell.m
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import "CPEntityCell.h"

#import "CPEntity.h"
#import "NSBezierPathWithRoundedRect.h"
#import "NSShadowWithOffset.h"

#define BADGE_HEIGHT_OFFSET 2.0
#define BADGE_WIDTH_OFFSET 6.0
#define ICON_SPACING 2
#define TOP_MARGIN 2

@implementation CPEntityCell

- (id) init {
	self = [super init];
	if (self != nil) {
		[super setAlignment:NSCenterTextAlignment];
		[super setFont:[NSFont systemFontOfSize:10.0]];
		
		_entity = nil;
	}
	
	return self;
}

- (void)setEntity:(CPEntity *)newEntity {
	_entity = newEntity;
}

- (CPEntity *)entity {
	return _entity;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, TOP_MARGIN + ICON_SPACING + ENTITY_ICON_SIZE, NSMinYEdge);
    [super editWithFrame:textFrame
				  inView:controlView
				  editor:textObj
				delegate:anObject
				   event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength {
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, TOP_MARGIN + ICON_SPACING + ENTITY_ICON_SIZE, NSMinYEdge);
    [super selectWithFrame:textFrame
					inView:controlView
					editor:textObj
				  delegate:anObject
					 start:selStart
					length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	NSRect imageFrame;

	NSDivideRect(cellFrame, &imageFrame, &cellFrame, TOP_MARGIN + ICON_SPACING + ENTITY_ICON_SIZE, NSMinYEdge);
	if ([self drawsBackground]) {
		[[self backgroundColor] set];
		NSRectFill(imageFrame);
	}

	imageFrame.size = NSMakeSize(ENTITY_ICON_SIZE, ENTITY_ICON_SIZE);

	if ([controlView isFlipped])
		imageFrame.origin.y += TOP_MARGIN + ENTITY_ICON_SIZE;
	else
		imageFrame.origin.y += ICON_SPACING;

	imageFrame.origin.x = ceil((cellFrame.size.width - ENTITY_ICON_SIZE) / 2);

	if (_entity) {
		NSImage *icon = [[_entity icon] copy];

		if ([_entity badgeCount] > 0) {
			NSBezierPath *path;
			NSAttributedString *iconString;
			NSRect iconRect;
			
			// Create a reusable attributes dictionary for our icon text.
			static NSDictionary *iconAttributes = nil;
			if (!iconAttributes) {
				iconAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
					[NSColor whiteColor], NSForegroundColorAttributeName,
					[NSFont boldSystemFontOfSize:7.0], NSFontAttributeName,
					NULL] retain];
			}
			
			// Create the attributed string.
			iconString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d", [_entity badgeCount]]
														  attributes:iconAttributes] autorelease];
			
			// Determine the size of the text's rect.
			iconRect.size.width = [iconString size].width + BADGE_WIDTH_OFFSET;
			iconRect.size.height = [iconString size].height + BADGE_HEIGHT_OFFSET;
			if (iconRect.size.width < iconRect.size.height) 
				iconRect.size.width = iconRect.size.height;
			iconRect.origin.x = [icon size].width - iconRect.size.width - 1.0;
			iconRect.origin.y = 1.0;
			
			/* Here's where all the drawing takes place. */
			[icon lockFocus];
			
			// Draw the background.
			[NSGraphicsContext saveGraphicsState];
			[[NSShadow shadowWithOffset:NSMakeSize(0, -2) blurRadius:2.0 color:[NSColor colorWithCalibratedWhite:0.0 alpha:0.8]] set];
			path = [NSBezierPath bezierPathWithRoundRectInRect:iconRect radius:iconRect.size.height / 2.0];
			[[NSColor colorWithCalibratedRed:0.776 green:0.0 blue:0.0 alpha:1.0] set];
			[path fill];	
			[NSGraphicsContext restoreGraphicsState];
			
			// Drawing with the shadow enabled seems to make the string thinner, so we're drawing it twice. 
			[NSGraphicsContext saveGraphicsState];
			[[NSShadow shadowWithOffset:NSMakeSize(0, -1) blurRadius:1.0 color:[NSColor colorWithCalibratedWhite:0.00 alpha:0.65]] set];
			[iconString drawAtPoint:NSMakePoint((iconRect.size.width - [iconString size].width) / 2.0 + NSMinX(iconRect),
												(iconRect.size.height - [iconString size].height) / 2.0 + NSMinY(iconRect))];
			[NSGraphicsContext restoreGraphicsState];
			[iconString drawAtPoint:NSMakePoint((iconRect.size.width - [iconString size].width) / 2.0 + NSMinX(iconRect),
												(iconRect.size.height - [iconString size].height) / 2.0 + NSMinY(iconRect))];
			
			[icon unlockFocus];
		}
		
		[icon compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
		[icon release];
	}

	[super drawWithFrame:cellFrame inView:controlView];	
}

- (NSSize)cellSize {
    NSSize cellSize = [super cellSize];
    cellSize.height += ENTITY_ICON_SIZE + TOP_MARGIN + ICON_SPACING;
    return cellSize;
}

@end
