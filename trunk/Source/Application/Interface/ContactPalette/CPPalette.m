//
//  CPPalette.m
//  ContactPalette
//
//  Created by Stephen Voida on 1/21/07.
//  Copyright 2007 Georgia Institute of Technology_. All rights reserved.
//

#import "CPPalette.h"

#import "CPEntityCell.h"
#import "CPModel.h"
#import "HUDWindow.h"
#import "PNWindow.h"
#import "NSStringWithFSExtensions.h"
#import "TransparentTableView.h"
#import "VTDesktopController.h"
#import "VTPreferences.h"

#define COLUMN_NAME @"PRIMARY_COLUMN"

#define CPPalettePboardType @"CPPalettePboardType"

#define kCPAutohideHideDelay	@"CPAutohideHideDelay"
#define kCPAutohideShowDelay	@"CPAutohideShowDelay"


static CPGroup *_draggedParent = nil;
static int _draggedIndex = -1;


@implementation CPPalette

+ (void)initialize {
	// create and register the default CP-related preferences 
	NSDictionary* defaultPreferences = [NSDictionary dictionaryWithObjectsAndKeys:
		
		// Autohide the root palette
		@"YES", kCPAutohideEnabled,
		
		// Autohide parameters
		@"3.0", kCPAutohideHideDelay,
		@"0.5", kCPAutohideShowDelay,
		
		// the end 
		nil
		];

	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultPreferences];
}

- (id)initWithGroup:(CPGroup *)representedGroup frame:(NSRect)frame parent:(CPPalette *)parent initiallyHidden:(BOOL)initiallyHidden {
	self = [super init];
	if (self != nil) {
		[representedGroup retain];
		_representedGroup = representedGroup;
		
		[parent retain];
		_parent = parent;
		
		// Are we a child?
		BOOL child = (parent != nil);
		
		// Do we have a child of our own? (No.)
		_child = nil;
		
		// Create a HUDWindow
		_window = [[HUDWindow alloc] initWithContentRect:frame
											   styleMask:((child) ? NSBorderlessWindowMask : NSTitledWindowMask) 
												 backing:NSBackingStoreBuffered 
												   defer:NO];
		
		NSScrollView *scrollView;
		_removeButton = nil;
		
		float contentsYOrigin = 5.0;
		float contentsHeight =  -2.0 * contentsYOrigin;
		
		if (child) {
			// Child windows are blue (default ones are greyish)
			[_window setMainColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.3 alpha:1.0]];
			[_window setTrimColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.75 alpha:1.0]];
			
			// Set up the window's in-place autohide properties
			AutohideWindowView *awv = [[[AutohideWindowView alloc] initWithFrame:[[_window contentView] frame]
																	   hideDelay:0.25] autorelease];
			[awv setDelegate:parent];
			[_window setContentView:awv];
		} else {
			[_window setTitle:@"Contacts"];
            
			// Carve out some additional space for the palette's titlebar
			contentsHeight -= 15.0;			// Space for a 19px titlebar when added to the existing 5px gutter

			// Set up the window's slide-off-screen autohide properties
			AutohideWindowView *awv = [[[AutohideWindowView alloc] initWithFrame:[[_window contentView] frame]
																	   hideDelay:[[NSUserDefaults standardUserDefaults] floatForKey:kCPAutohideHideDelay]
																	   showDelay:[[NSUserDefaults standardUserDefaults] floatForKey:kCPAutohideShowDelay]
																	visibleWidth:(frame.size.width - (HW_RADIUS / 2.0))
																	 hiddenWidth:3.0
                                                                 initiallyHidden:initiallyHidden] autorelease];
			// Monitor our own window so we know when we're about to be hidden if we're a root
			[awv setDelegate:self];
			[awv setEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:kCPAutohideEnabled]];
			[_window setContentView:awv];
			
			// Register for changes in the autohide display settings
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(userDefaultsChanged:)
														 name:NSUserDefaultsDidChangeNotification
													   object:nil];
		}
		
		// Display the currently-empty palette (so we can accurately compute its size)
		[_window orderFront:self];
		contentsHeight += [_window frame].size.height;
		
		// Create some content-manipulation buttons if the content is manipulable
		if ([representedGroup isEditable]) {
			NSBundle *bundle = [NSBundle bundleForClass:[self class]];
			NSString *imagePath = [bundle pathForImageResource:@"add.tif"];
			NSImage *addImage = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
			NSButton *addButton = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, [addImage size].width, [addImage size].height)] autorelease];
			[addButton setImage:addImage];
			imagePath = [bundle pathForImageResource:@"add-selected.tif"];
			[addButton setAlternateImage:[[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease]];
			[addButton setToolTip:@"Add a new group"];
			[addButton setBordered:NO];
			[addButton setTarget:self];
			[addButton setAction:@selector(addGroup:)];
			[addButton setEnabled:!child];
			[[_window contentView] addSubview:addButton];			
			
			imagePath = [bundle pathForImageResource:@"remove.tif"];
			NSImage *removeImage = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
			_removeButton = [[NSButton alloc] initWithFrame:NSMakeRect([_window frame].size.width - [removeImage size].width, 0.0,
																	   [removeImage size].width, [removeImage size].height)];
			[_removeButton setImage:removeImage];
			imagePath = [bundle pathForImageResource:@"remove-selected.tif"];
			[_removeButton setAlternateImage:[[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease]];
			[_removeButton setToolTip:@"Remove the selected group"];
			[_removeButton setEnabled:NO];
			[_removeButton setBordered:NO];
			[_removeButton setTarget:self];
			[_removeButton setAction:@selector(removeItem:)];
			[[_window contentView] addSubview:_removeButton];
			
			// Make sure we've set aside the appropriate display space for the buttons
			contentsYOrigin += 15.0;		// Space for 20px tall buttons when added to existing 5px gutter
			contentsHeight -= 15.0;
		}
		
		// Define the TransparentTableView and enclosing NSScrollView
		scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(2.5, contentsYOrigin, [_window frame].size.width - 5.0, contentsHeight)];
		[scrollView setBackgroundColor:[NSColor clearColor]];
		[scrollView setDrawsBackground:NO];
		[scrollView setHasVerticalScroller:YES];
		[scrollView setAutohidesScrollers:YES];
		[scrollView setAutoresizesSubviews:YES];
		[scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		
		_table = [[TransparentTableView alloc] init];
		[_table setHeaderView:nil];
		[_table setRowHeight:52.0];
		[_table setFocusRingType:NSFocusRingTypeNone];
		
		NSTableColumn *tableColumn = [[NSTableColumn alloc] initWithIdentifier:COLUMN_NAME];
		[tableColumn setWidth:80.0];
		CPEntityCell *entityCell = [[[CPEntityCell alloc] init] autorelease];
		[entityCell setEditable:YES];
		[tableColumn setDataCell:(NSCell *)entityCell];
		[_table addTableColumn:tableColumn];
		[tableColumn release];
		
		// Register to get callbacks from changing nodes in the represented group
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(groupUpdated:)
													 name:kCPEntityChanged
												   object:representedGroup];
		
		// Register to get our custom type and filenames for drops
		[_table registerForDraggedTypes:[NSArray arrayWithObjects:CPPalettePboardType, NSVCardPboardType, NSFilenamesPboardType, nil]];
		[_table setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
		[_table setDraggingSourceOperationMask:NSDragOperationAll_Obsolete forLocal:NO];
		
		// Enable vertical motion dragging by default
		[_table setVerticalMotionCanBeginDrag:YES];
		
		// Drop the table into the window
		[scrollView setDocumentView:_table];
		[[_window contentView] addSubview:scrollView];
		[scrollView release];
		
		// Connect everything together
		[_table setDataSource:self];
		[_table setDelegate:self];
		[_table setTarget:self];
		[_table setAction:@selector(tableClicked:)];
		
		// Make sure there's no initial selection
		[self resetSelection];
        
        // Finally, the root palette should be sticky and unaffected by Expose
        if (!child) {
            PNWindow *pnPalette = [PNWindow windowWithNSWindow:_window];
            [pnPalette setIgnoredByExpose:YES];
            [pnPalette setSticky:YES];
        }
	}
	
	return self;
}

- (void) dealloc {
    // Unlock and close any open windows
    [self close];
	
	[_child release];
	_child = nil;
	[_table release];
	_table = nil;
	[_removeButton release];
	_removeButton = nil;
	[_window release];
	_window = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_representedGroup release];
	[_parent release];

	[super dealloc];
}

- (NSWindow *)window {
	return _window;
}

- (void)resetSelection {
	[_table selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
}
	
#pragma mark -
#pragma mark NSTableView data source methods

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (rowIndex >= (int)[_representedGroup count])
		return nil;
	
    // Set up this paragraph style once (and then re-use it mercilessly)
	static NSDictionary *info = nil;
    if (nil == info) {
        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByTruncatingTail];
		[style setAlignment:NSCenterTextAlignment];
        info = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName,
			[NSColor whiteColor], NSForegroundColorAttributeName, nil];
        [style release];
    }

	return [[[NSAttributedString alloc] initWithString:[[_representedGroup childAtIndex:rowIndex] name]
											attributes:info] autorelease];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	if ([[_representedGroup childAtIndex:rowIndex] isEditable]) {
		[(CPEntity *)[_representedGroup childAtIndex:rowIndex] setName:(NSString *)anObject];
	}
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [_representedGroup count];
}

#pragma mark -
#pragma mark NSTableView delegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	int row = [_table selectedRow];
	
	// Kind of complicated logic...but it seems to work
	if ([_representedGroup isEditable] && row > -1) {
		if ([_representedGroup isMemberOfClass:[CPRootGroup class]] && row >= (int)[(CPRootGroup *)_representedGroup count])
			[_removeButton setEnabled:NO];
		else
			[_removeButton setEnabled:YES];
	} else
		[_removeButton setEnabled:NO];
}

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(int)row {
	if (row >= (int)[_representedGroup count])
		return;
	
	[(CPEntityCell *)cell setEntity:[_representedGroup childAtIndex:row]];
	
	[cell setEditable:[[_representedGroup childAtIndex:row] isEditable]];
}

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)column row:(int)row mouseLocation:(NSPoint)mouseLocation {
	return [(CPEntity *)[_representedGroup childAtIndex:row] toolTipText];
}

#pragma mark -
#pragma mark Drag-and-drop-related delegate methods

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard 
{
	_draggedParent = _representedGroup;
	_draggedIndex = [rowIndexes firstIndex];
	
    [pboard declareTypes:[NSArray arrayWithObject:CPPalettePboardType] owner:self];
    [pboard setData:[NSData data] forType:CPPalettePboardType];
	
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	// If the drag and drag is internal, use our model to resolve it
	if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:CPPalettePboardType]] &&
		_draggedParent &&
		_draggedIndex >= 0) {
		
		// Check move requests first
		CPEntity *source = [_draggedParent childAtIndex:_draggedIndex];
		if (row == (int)[_representedGroup count] || op == NSTableViewDropAbove) {
			if (_draggedParent == _representedGroup) {
				if ([_representedGroup canMoveChild:source toDestination:row])
					return NSDragOperationGeneric;
			} else if ([_representedGroup canAddChild:source fromSource:_draggedParent])
				return NSDragOperationCopy;

			return NSDragOperationNone;
		}
		
		// Then check add requests
		CPEntity *target = [_representedGroup childAtIndex:row];
		if ([target canAddChild:source fromSource:_draggedParent])
			return NSDragOperationCopy;
		
		// And fail if none of that works
		return NSDragOperationNone;
	}
	
	// Try to validate vCard drops next
	if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:NSVCardPboardType]]) {
		// Can't drop people on people; other combos are OK
		if (op == NSTableViewDropOn) {
			CPEntity *target = [_representedGroup childAtIndex:row];
			if ([target isKindOfClass:[CPPerson class]])
				return NSDragOperationNone;
		}
		
		return NSDragOperationCopy;
	}
	
	// Try to validate file drops last
	if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]) {
		// Figure out if the target is a legitimate file destination
		CPEntity *target = [_representedGroup childAtIndex:row];
		if ([target isKindOfClass:[CPPerson class]] ||
			[target isMemberOfClass:[CPGroup class]])
			return NSDragOperationCopy;
	}
	
	// All other cases, disapprove of it
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op {
	// If the drag and drag is internal, use our model to resolve it
	if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:CPPalettePboardType]] &&
		_draggedParent &&
		_draggedIndex >= 0) {

		// Handle move requests first
		CPEntity *source = [_draggedParent childAtIndex:_draggedIndex];
		if (row == (int)[_representedGroup count] || op == NSTableViewDropAbove) {
			if (_draggedParent == _representedGroup) {
				if ([_representedGroup canMoveChild:source toDestination:row]) {
					[_representedGroup moveChildFromIndex:_draggedIndex toIndex:row];
					
					_draggedParent = nil;
					_draggedIndex = -1;
					return YES;
				}
			} else if ([_representedGroup canAddChild:source fromSource:_draggedParent]) {
				[_representedGroup addChild:source fromSource:_draggedParent];
				
				_draggedParent = nil;
				_draggedIndex = -1;
				return YES;
			}
			
			_draggedParent = nil;
			_draggedIndex = -1;
			return NO;
		}
		
		// Then handle add requests
		CPEntity *target = [_representedGroup childAtIndex:row];
		if ([target canAddChild:source fromSource:_draggedParent]) {
			[target addChild:source fromSource:_draggedParent];

			_draggedParent = nil;
			_draggedIndex = -1;
			return YES;
		}
	}
	
	// Try to validate vCard drops next
	if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:NSVCardPboardType]]) {
		NSData *data = [[info draggingPasteboard] dataForType:NSVCardPboardType];
		if (data) {
			BOOL successFlag = NO;
			NSString *vCardText = [NSString stringWithUTF8String:[data bytes]];
			
			// Check to see if we've got a plist-ified version of the data (e.g., an AB group)
			if ([vCardText hasPrefix:@"<?xml"]) {
				NSObject *uncompressedData = [vCardText propertyList];
				if (uncompressedData) {
					@try {
						vCardText = [NSString stringWithUTF8String:[(NSData *)uncompressedData bytes]];
					}
					@catch (NSException *badCast) {
						return NO;
					}
				} else
					return NO;
			}
			
			NSRange searchRange = NSMakeRange(0, [vCardText length]);
			NSRange beginRange = [vCardText rangeOfString:@"BEGIN:VCARD" options:NSBackwardsSearch range:searchRange];
			while (beginRange.location != NSNotFound) {
				int singleVCardLength = searchRange.length - beginRange.location;
				NSString *singleVCardText = [vCardText substringWithRange:NSMakeRange(beginRange.location, singleVCardLength)];
				
				CPPerson *newPerson = [[CPPerson alloc] initWithVCardRepresentation:[singleVCardText dataUsingEncoding:NSUTF8StringEncoding] editable:NO];
				if (newPerson) {
					if (op == NSTableViewDropOn && [[_representedGroup childAtIndex:row] isKindOfClass:[CPGroup class]])
						[[_representedGroup childAtIndex:row] addChild:newPerson fromSource:nil];
					else
						[_representedGroup insertChild:newPerson atIndex:row fromSource:nil];
					
					successFlag = YES;
				}
				[newPerson release];
				
				searchRange.length = searchRange.length - singleVCardLength;
				beginRange = [vCardText rangeOfString:@"BEGIN:VCARD" options:NSBackwardsSearch range:searchRange];
			}
			
			if (successFlag)
				return YES;
		}
	}
		
	// Try to validate file drops last
	if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]) {
		// Figure out if the target is a legitimate file destination
		CPEntity *target = [_representedGroup childAtIndex:row];
		NSMutableArray *recipients = [NSMutableArray array];

		// Compile a recipient list
		if ([target isKindOfClass:[CPPerson class]]) {
			[recipients addObject:[(CPPerson *)target email]];
		} else if ([target isMemberOfClass:[CPGroup class]]) {
			[recipients addObjectsFromArray:[(CPGroup *)target memberEmails]];
		}

		// And then set up the send
		if ([recipients count] > 0) {
			// Get the filename list
			NSArray *attachments = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
            
            // And convert them to HFS if necessary (everyone except Apple Mail)
            if ([[NSUserDefaults standardUserDefaults] integerForKey:VTMailClient] != kVTMailClientMail) {
                NSMutableArray *fixedAttachments = [[[NSMutableArray alloc] init] autorelease];
                unsigned counter;
                for (counter = 0; counter < [attachments count]; counter++)
                    [fixedAttachments addObject:[(NSString *)[attachments objectAtIndex:counter] HFSPathFromPOSIXPath]];
                attachments = fixedAttachments;
            }
            
			NSString *attachmentList = [NSString stringWithFormat:@"\"%@\"", [attachments componentsJoinedByString:@"\", \""]];
			
			// Get the recipient list
			NSString *recipientList = [NSString stringWithFormat:@"\"%@\"", [recipients componentsJoinedByString:@"\", \""]];
			
			// Do some AppleScript magic!
            // Select the correct script depending on which mail client is active
            NSMutableString *scriptCommand;
            switch ([[NSUserDefaults standardUserDefaults] integerForKey:VTMailClient]) {                
                case kVTMailClientEntourage:
                    scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Send an Email - Entourage.applescript"]];
                    break;
                case kVTMailClientEudora:
                    scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Send an Email - Eudora.applescript"]];
                    break;
                case kVTMailClientMail:
                default:
                    scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Send an Email - Mail.applescript"]];
                    break;
            }
            
			[scriptCommand replaceOccurrencesOfString:@"%RECIPIENTS%"
										   withString:recipientList
											  options:nil
												range:NSMakeRange(0, [scriptCommand length])];
			[scriptCommand replaceOccurrencesOfString:@"%FILES%"
										   withString:attachmentList
											  options:nil
												range:NSMakeRange(0, [scriptCommand length])];
			
            // Do the heavy lifting in another thread
            [NSThread detachNewThreadSelector:@selector(runScriptMultithreaded:)
                                     toTarget:self
                                   withObject:scriptCommand];
			
			return YES;
		}
	}
	
	// All other cases, do nothing
	return NO;
}

#pragma mark -
#pragma mark NSTableView action method

- (void)tableClicked:(id)sender {
    int row = [_table selectedRow];
    
	if (row >= (int)[_representedGroup count])
		return;
	
	if ([[_representedGroup childAtIndex:row] isKindOfClass:[CPGroup class]] &&
		[(CPGroup *)[_representedGroup childAtIndex:row] count] > 0)
		[self expandRow:row];
	
	if ([[_representedGroup childAtIndex:row] isKindOfClass:[CPPerson class]]) {
		NSMenu *simpleMenu = [[[NSMenu alloc] initWithTitle:@"SimpleMenu"] autorelease];
        [simpleMenu setAutoenablesItems:NO];
        
		NSMenuItem *simpleMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Display Address Book card..."
																 action:@selector(showABCard:)
														  keyEquivalent:@""] autorelease];
		[simpleMenuItem setTarget:self];
		[simpleMenu addItem:simpleMenuItem];

		simpleMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Display E-mail messages..."
													 action:@selector(showEmail:)
											  keyEquivalent:@""] autorelease];
		[simpleMenuItem setTarget:self];
		[simpleMenu addItem:simpleMenuItem];

        // Since Eudora and Entourage can't generate the filtered inbox view, disable this menu item if using either of those clients
        if ([[NSUserDefaults standardUserDefaults] integerForKey:VTMailClient] != kVTMailClientMail)
            [simpleMenuItem setEnabled:NO];
        
		[NSMenu popUpContextMenu:simpleMenu
					   withEvent:[NSApp currentEvent]
						 forView:_table];
	}
}

#pragma mark -
#pragma mark NSButton action methods

- (void)addGroup:(id)sender {
	unsigned newItemIndex = [_representedGroup addChild:[[[CPGroup alloc] initWithName:@"New group" editable:YES] autorelease]
											 fromSource:nil];
	
	[_window makeFirstResponder:_table];
	[_table editColumn:[_table columnWithIdentifier:COLUMN_NAME]
												row:newItemIndex
										  withEvent:nil
											 select:YES];
	
	[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:newItemIndex]
		byExtendingSelection:NO];
}

- (void)removeItem:(id)sender {
	[_representedGroup removeChildAtIndex:[_table selectedRow]];
	
	// Make sure there's no selection after the delete
	[self resetSelection];
}

#pragma mark -
#pragma mark NSMenu action methods

- (void)showABCard:(id)sender {
	CPEntity *target = [_representedGroup childAtIndex:[_table selectedRow]];
	if ([target isKindOfClass:[CPPerson class]]) {
		NSString *targetEmail = [(CPPerson *)target email];
		
		// Do some AppleScript magic!
		NSMutableString *scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Find Address Book Card.applescript"]];
		[scriptCommand replaceOccurrencesOfString:@"%EMAIL%"
									   withString:targetEmail
										  options:nil
											range:NSMakeRange(0, [scriptCommand length])];
		NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
		NSDictionary *errorDictionary;
        [appleScript executeAndReturnError:&errorDictionary];
		[appleScript release];
	}
}

- (void)showEmail:(id)sender {
    // Entourage and Eudora can't handle this command (and in fact, execution should never make it here
    // if one of those two clients are active, so just bail out unless we're currently connecting to Apple Mail
    if ([[NSUserDefaults standardUserDefaults] integerForKey:VTMailClient] != kVTMailClientMail)
        return;
    
	CPEntity *target = [_representedGroup childAtIndex:[_table selectedRow]];
	if ([target isKindOfClass:[CPPerson class]]) {
		// Make sure the email client will be visible when this happens
		// It's a dirty hack, but it works!
		[[VTDesktopController sharedInstance] temporarilyFollowApplicationChanges];
		
		NSString *targetEmail = [(CPPerson *)target email];

        // Do some AppleScript magic!
        NSMutableString *scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Filter Inbox - Mail.applescript"]];
		[scriptCommand replaceOccurrencesOfString:@"%EMAIL%"
									   withString:targetEmail
										  options:nil
											range:NSMakeRange(0, [scriptCommand length])];
		NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
		NSDictionary *errorDictionary;
        [appleScript executeAndReturnError:&errorDictionary];
		[appleScript release];
	}
}

#pragma mark -

- (void)expandRow:(int)row {
	NSRect newFrame = [_window frame];
	
	// Tier out in the right direction
	if ([AutohideWindowView isAutohidingToLeft])
		newFrame.origin.x += (newFrame.size.width - HW_RADIUS);
	else
		newFrame.origin.x -= (newFrame.size.width - HW_RADIUS);
	
	newFrame.origin.y = MAX(0.0, newFrame.origin.y - 2 * HW_RADIUS);
	
	if (_child != nil)
		[_child release];
	if (_anchorRectTag > 0)
		[_table removeTrackingRect:_anchorRectTag];
	
	_anchorRect = [_table frameOfCellAtColumn:0 row:row];
	_child = [[CPPalette alloc] initWithGroup:(CPGroup *)[_representedGroup childAtIndex:row]
                                        frame:newFrame
                                       parent:self
                              initiallyHidden:NO];
	
	// While the child's out, let's lock ourselves open and watch for comings and goings on the anchor cell
    [self preventAutohiding:nil];
	
	[_table addTrackingRect:_anchorRect
					  owner:self
				   userData:NULL
			   assumeInside:NO];	
}

- (void)userDefaultsChanged:(NSNotification *)notification {
	AutohideWindowView *awv = (AutohideWindowView *)[_window contentView];
	[awv setHideDelay:[[NSUserDefaults standardUserDefaults] floatForKey:kCPAutohideHideDelay]];
	[awv setShowDelay:[[NSUserDefaults standardUserDefaults] floatForKey:kCPAutohideShowDelay]];
	
	// If we need to pop it open, do it before we lock it down!
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kCPAutohideEnabled] == NO)
		[awv revealNow];
	
	[awv setEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:kCPAutohideEnabled]];
}

- (void)groupUpdated:(NSNotification *)notification {
	// Refresh the display to reflect the changes
	[_table reloadData];
}

- (void)close {
    if (_child)
        [_child close];
    
    [self allowAutohiding:nil];
    [_window orderOut:nil];
}

- (void)preventAutohiding:(id)sender {
    [(AutohideWindowView *)[_window contentView] lock];
}

- (void)allowAutohiding:(id)sender {
    [(AutohideWindowView *)[_window contentView] unlock];
}

- (BOOL)isHidden {
    return [(AutohideWindowView *)[_window contentView] isAutohiding];
}

- (BOOL)windowWillHide:(NSWindow *)window {
	// Handle child windows first and foremost
	if (window != _window) {
		NSPoint cursorInTableCoords = [_table convertPoint:[_window convertScreenToBase:[NSEvent mouseLocation]] fromView:nil];
		if (NSPointInRect(cursorInTableCoords, _anchorRect))
			return NO;
		else {
			// If the hide is valid, we should also unlock our window, and stop tracking the anchor rect
			if (_anchorRectTag > 0) {
				[_table removeTrackingRect:_anchorRectTag];
				_anchorRectTag = 0;
			}
			
            [self allowAutohiding:nil];
			[_child release];
			_child = nil;
			
			return YES;
		}
	}

	// Otherwise, it's our window; just deselect whatever might be selected
	[self resetSelection];

	return YES;
}

- (void)runScriptMultithreaded:(NSString *)scriptCommand {
    NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init];
    
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptCommand];
    NSDictionary *errorDict;
    [script executeAndReturnError:&errorDict];
    [script release];
    
    [tempPool release];
}

- (void)setAlphaRecursively:(float)alpha {
    [_window setAlphaValue:alpha];
    
    if (_child)
        [_child setAlphaRecursively:alpha];
}

#pragma mark -

// Merely a formality
- (BOOL)windowWillShow:(NSWindow *)window {
	return YES;
}

- (void)mouseEntered:(NSEvent*)event {
	// Don't care
}

- (void)mouseExited:(NSEvent *)event {
	if (_child)
        [_child allowAutohiding:nil];
}


@end
