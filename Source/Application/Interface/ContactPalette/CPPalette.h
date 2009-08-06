//
//  CPPalette.h
//  ContactPalette
//
//  Created by Stephen Voida on 1/21/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AutohideWindowView.h"
@class CPGroup;
@class HUDWindow;

#define kCPAutohideEnabled	@"CPAutohideEnabled"

#define kVTMailClientMail       1
#define kVTMailClientEntourage  2
#define kVTMailClientEudora     3


@interface CPPalette : NSObject <AutohideWindowViewDelegate> {
	CPGroup *_representedGroup;
	HUDWindow *_window;
	NSButton *_removeButton;
	NSTableView *_table;
	
	CPPalette *_parent;
	CPPalette *_child;
	NSRect _anchorRect;
	NSTrackingRectTag _anchorRectTag;
}

- (id)initWithGroup:(CPGroup *)representedGroup frame:(NSRect)frame parent:(CPPalette *)parent initiallyHidden:(BOOL)initiallyHidden;
- (NSWindow *)window;
- (void)resetSelection;
- (void)tableClicked:(id)sender;
- (void)addGroup:(id)sender;
- (void)removeItem:(id)sender;
- (void)showABCard:(id)sender;
- (void)showEmail:(id)sender;
- (void)expandRow:(int)row;
- (void)userDefaultsChanged:(NSNotification *)notification;
- (void)groupUpdated:(NSNotification *)notification;
- (void)close;
- (void)preventAutohiding:(id)sender;
- (void)allowAutohiding:(id)sender;
- (BOOL)isHidden;
- (BOOL)windowWillHide:(NSWindow *)window;
- (BOOL)windowWillShow:(NSWindow *)window;
- (void)runScriptMultithreaded:(NSString *)scriptCommand;
- (void)setAlphaRecursively:(float)alpha;

@end
