//
//  CPRootGroup.m
//  ContactPalette
//
//  Created by Stephen Voida on 1/31/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import "CPRootGroup.h"

#import "CPPalette.h"
#import "CPPerson.h"
#import "VTPreferences.h"

#define DEFAULT_ROOTGROUP_NAME @"Contacts"


@implementation CPRootGroup

#pragma mark Lifecycle methods

- (id) init {
	// Root groups don't really need a name
	return [super initWithName:DEFAULT_ROOTGROUP_NAME editable:YES];
}


#pragma mark -
#pragma mark Child management methods

- (void)setContents:(NSMutableArray *)contents {
	// Stop listening to the contents we're replacing
	NSEnumerator *items = [_contents objectEnumerator];
	CPEntity *item;
	while (item = [items nextObject])
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:kCPEntityChanged
													  object:item];

	// Replace the contents
	[contents retain];
	[_contents release];
	_contents = contents;
	
	// Listen to our new contents
	items = [_contents objectEnumerator];
	while (item = [items nextObject])
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(childChanged:)
													 name:kCPEntityChanged
												   object:item];
	
	// Notify the world that this entity has changed
	[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
														object:self];
}

- (NSMutableArray *)contents {
	return _contents;
}


#pragma mark -
#pragma mark Capability specification methods

// Can hold other groups, too
- (BOOL)canAddChild:(CPEntity *)entity fromSource:(CPEntity *)source {
	if (entity &&
		![self containsChild:entity recursively:NO])
		return YES;
	else
		return NO;
}

- (BOOL)canMoveChild:(CPEntity *)entity toDestination:(unsigned)destinationIndex {
	return YES;
}

#pragma mark -
#pragma mark Badge maintenance method

- (int)updateVariableBadgeCounts {
    // Select the correct script depending on which mail client is active
    NSMutableString *scriptCommand;
    switch ([[NSUserDefaults standardUserDefaults] integerForKey:VTMailClient]) {
        case kVTMailClientEntourage:
            scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Get Unread Senders - Entourage.applescript"]];
            break;
        case kVTMailClientEudora:
            scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Get Unread Senders - Eudora.applescript"]];
            break;
        case kVTMailClientMail:
        default:
            scriptCommand = [NSMutableString stringWithContentsOfFile:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Get Unread Senders - Mail.applescript"]];
            break;
    }
    
	// Next, get a list of all unread email senders from the mail client (if it's available!)
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
	NSDictionary *errorDictionary;
	NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errorDictionary];
	[appleScript release];
	
	// Convert the AppleScript object that we get back into a dictionary that
	// maps actual, short e-mail addresses to the number of unread messages that person
	// has sent in the user's inbox
	if (result) {
		NSMutableDictionary *badgeDict = [NSMutableDictionary dictionary];

		// If there is stuff to put *in* the dictionary, do it
		if ([result numberOfItems] > 0) {
			NSAppleEventDescriptor *senderDescriptor;
			while (senderDescriptor = [result descriptorAtIndex:1]) {
				[result removeDescriptorAtIndex:1];
				NSString *senderString = [senderDescriptor stringValue];
				NSRange addyStart = [senderString rangeOfString:@"<"];
				if (addyStart.location != NSNotFound) {
					senderString = [senderString substringFromIndex:[senderString rangeOfString:@"<"].location + 1];
					senderString = [senderString substringToIndex:[senderString rangeOfString:@">"].location];
				}
                
				NSNumber *existingCount = [badgeDict objectForKey:senderString];
				if (existingCount == nil)
					[badgeDict setObject:[NSNumber numberWithInt:1] forKey:senderString];
				else
                    [badgeDict setObject:[NSNumber numberWithInt:([existingCount intValue] + 1)] forKey:senderString];
			}
		}
		
		// Finally, apply those counts over the variable parts of the root group
		return [self updateBadgeCountsUsingDictionary:badgeDict];
	}
	
	return 0;
}

@end
