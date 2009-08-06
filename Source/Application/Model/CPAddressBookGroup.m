//
//  CPAddressBookGroup.m
//  ContactPalette
//
//  Created by Stephen Voida on 1/21/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import "CPAddressBookGroup.h"
#import "CPPerson.h"
#import <AddressBook/AddressBook.h>

#define CP_ADDRESS_BOOK_GROUP_DEFAULT_NAME @"Address Book"


@interface CPAddressBookGroup (PrivateAPI)
- (void)populateWithABGroupContents:(id)object;
@end


@implementation CPAddressBookGroup

#pragma mark Capability specification methods

// This group can contain other groups, and it will only accept adds from itself
- (BOOL)canAddChild:(CPEntity *)entity fromSource:(CPEntity *)source {
	if (entity &&
		source == self &&
		![self containsChild:entity recursively:NO])
		return YES;
	else
		return NO;
}

- (BOOL)canRemoveChild:(CPEntity *)entity {
	return NO;
}


#pragma mark -
#pragma mark Badge maintenance method

- (int)updateBadgeCountsUsingDictionary:(NSDictionary *)badgeDict {
	// Address Book groups shouldn't annotate their contents with unread counts
	// (it doesn't seem relevant to do so)
	return 0;
}


#pragma mark -
#pragma mark Factory method

+ (CPAddressBookGroup *)addressBookGroupFromAddressBook {
	CPAddressBookGroup *result;
	
    result = [[[CPAddressBookGroup alloc] initWithName:CP_ADDRESS_BOOK_GROUP_DEFAULT_NAME
                                              editable:NO] autorelease];
    
    // Set up the main AB icon
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForImageResource:@"ab.png"];
    [result setIcon:[[[NSImage alloc] initWithContentsOfFile:path] autorelease]];
    
    // Fill it out (multithreaded version)
    [NSThread detachNewThreadSelector:@selector(populateWithABGroupContents:)
                             toTarget:result
                           withObject:nil];
    
    return result;
}

#pragma mark -
#pragma mark Conversion methods

- (CPGroup *)editableDuplicate {
	// Duplicate ourselves
	CPGroup *result = [[[CPGroup alloc] initWithName:[self name] editable:YES] autorelease];
	
	// And then duplicate our contents, making sure that any subgroups become editable as well
	NSEnumerator *children = [_contents objectEnumerator];
	CPEntity *child;
	while (child = (CPEntity *)[children nextObject]) {
		if ([child isMemberOfClass:[CPAddressBookGroup class]])
			[result addChild:[(CPAddressBookGroup *)child editableDuplicate] fromSource:self];
		else
			[result addChild:child fromSource:self];
	}
	
	return result;
}

@end


#pragma mark -
#pragma mark Private methods

@implementation CPAddressBookGroup (PrivateAPI)

- (void)populateWithABGroupContents:(id)object {
    NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init];
    NSMutableArray *people;
	
	if (object == nil) {
		// Traverse the subgroups first
		NSMutableArray *subgroups = [[[ABAddressBook sharedAddressBook] groups] mutableCopy];
		NSSortDescriptor *primary = [[NSSortDescriptor alloc] initWithKey:kABGroupNameProperty ascending:YES];
		[subgroups sortUsingDescriptors:[NSArray arrayWithObject:primary]];
		[primary release];
		
		NSEnumerator *subgroupList = [subgroups objectEnumerator];
		ABGroup *subgroup;
		while (subgroup = (ABGroup *)[subgroupList nextObject]) {
            CPAddressBookGroup *newGroup = [[CPAddressBookGroup alloc] initWithName:[subgroup valueForProperty:kABGroupNameProperty]
                                                                           editable:NO];
            [newGroup populateWithABGroupContents:subgroup];
			[self addChild:newGroup fromSource:self];
            [newGroup release];
		}
		[subgroups release];
		
		people = [[[ABAddressBook sharedAddressBook] people] mutableCopy];
	} else
		people = [[(ABGroup *)object members] mutableCopy];
	
	// Find the "me" card's primary email address, so we can exclude that from consideration
	NSString *myEmail = nil;
	ABPerson *me = [[ABAddressBook sharedAddressBook] me];
	if (me != nil) {
		ABMultiValue *myEmails = [me valueForProperty:kABEmailProperty];
		if (myEmails != nil)
			myEmail = [myEmails valueAtIndex:[myEmails indexForIdentifier:[myEmails primaryIdentifier]]];
	}
	
	// Get and sort the people in the AB group
	NSSortDescriptor *primary = [[NSSortDescriptor alloc] initWithKey:kABLastNameProperty ascending:YES];
	NSSortDescriptor *secondary = [[NSSortDescriptor alloc] initWithKey:kABFirstNameProperty ascending:YES];
	NSSortDescriptor *tertiary = [[NSSortDescriptor alloc] initWithKey:kABOrganizationProperty ascending:YES];
	[people sortUsingDescriptors:[NSArray arrayWithObjects:primary, secondary, tertiary, nil]];
	[primary release];
	[secondary release];
	[tertiary release];
	
	// Add them, one by one
	NSEnumerator *peopleList = [people objectEnumerator];
	ABPerson *abperson;
	while (abperson = (ABPerson *)[peopleList nextObject]) {
		ABMultiValue *emails = [abperson valueForProperty:kABEmailProperty];
		if (emails != nil) {
			NSString *primaryEmail = [emails valueAtIndex:[emails indexForIdentifier:[emails primaryIdentifier]]];
			if (myEmail == nil || [primaryEmail caseInsensitiveCompare:myEmail] != NSOrderedSame)
				[self addChild:[[[CPPerson alloc] initWithEmail:primaryEmail
                                                       editable:NO] autorelease]
					  fromSource:self];
		}
	}
	
	[people release];
    [tempPool release];
}

@end
