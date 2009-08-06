//
//  CPEntityCell.h
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CPEntity;

@interface CPEntityCell : NSTextFieldCell {
	CPEntity *_entity;
}

- (void)setEntity:(CPEntity *)newEntity;
- (CPEntity *)entity;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end
