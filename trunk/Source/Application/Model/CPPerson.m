//
//  CPPerson.m
//  ContactPalette
//
//  Created by Stephen Voida on 12/5/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import "CPPerson.h"
#import <AddressBook/AddressBook.h>

#define CPPersonEmailKey @"CPPersonEmail"


@implementation CPPerson

#pragma mark Lifecycle methods

- (id) initWithName:(NSString *)name editable:(BOOL)editable {
	self = [super initWithName:name
					  editable:editable];
	
	if (self) {
		// If created by name, email is nil
		_email = nil;
	}

	return self;
}

- (id)initWithEmail:(NSString *)email editable:(BOOL)editable {
	ABSearchElement *emailMatches = [ABPerson searchElementForProperty:kABEmailProperty
																 label:nil
																   key:nil
																 value:email
															comparison:kABEqualCaseInsensitive];
	NSArray *peopleFound = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:emailMatches];

	if ([peopleFound count] > 0) {
		ABPerson *person = [peopleFound objectAtIndex:0];
		NSString *nickname = [person valueForProperty:kABNicknameProperty];
		NSString *firstName = [person valueForProperty:kABFirstNameProperty];
		NSString *lastName = [person valueForProperty:kABLastNameProperty];
		NSString *company = [person valueForProperty:kABOrganizationProperty];

		if (company && ([[person valueForProperty:kABPersonFlags] intValue] & kABShowAsCompany))
			self = [self initWithName:company
							 editable:editable];
		else if (nickname)
			self = [self initWithName:[NSString stringWithFormat:@"%@ %@", nickname, lastName]
							 editable:editable];
		else if (firstName)
			self = [self initWithName:[NSString stringWithFormat:@"%@ %@", firstName, lastName]
							 editable:editable];
		else
			self = [self initWithName:[[email componentsSeparatedByString:@"@"] objectAtIndex:0]
							 editable:editable];

		if (self) {
			_email = [email copy];

			// Swap the custom icon in for the default one (if available)
			NSImage *customIcon = [[[NSImage alloc] initWithData:[person imageData]] autorelease];
			if (customIcon) {
				[_icon release];
				_icon = [[CPEntity scaledIcon:customIcon] retain];
			}
		}
	} else {
		self = [self initWithName:[[email componentsSeparatedByString:@"@"] objectAtIndex:0]
						 editable:editable];
		
		if (self) {
			_email = [email copy];
		}
	}
	
	return self;
}

- (id)initWithVCardRepresentation:(NSData *)vCardData editable:(BOOL)editable {
    ABPerson *ab = [[ABPerson alloc] initWithVCardRepresentation:vCardData];
    if (ab == nil)
        return nil;
    
    NSString *firstName = [ab valueForProperty:kABFirstNameProperty];
    NSString *nickName = [ab valueForProperty:kABNicknameProperty];
    NSString *lastName = [ab valueForProperty:kABLastNameProperty];
    ABMultiValue *emailList = (ABMultiValue *)[ab valueForProperty:kABEmailProperty];
    NSString *emailAddress = [emailList valueAtIndex:[emailList indexForIdentifier:[emailList primaryIdentifier]]];
    if (emailAddress == nil)
        return nil;
	
    // Cache the person's image if it's available
    NSImage *personImage = nil;
    if ([ab imageData])
        personImage = [[[NSImage alloc] initWithData:[ab imageData]] autorelease];
	
    if (lastName && [lastName length] > 0) {
        if (nickName && [nickName length] > 0)
			self = [self initWithName:[NSString stringWithFormat:@"%@ %@", nickName, lastName] editable:editable];
        else if (firstName && [firstName length] > 0)
            self = [self initWithName:[NSString stringWithFormat:@"%@ %@", firstName, lastName] editable:editable];
    } else
		self = [self initWithEmail:emailAddress editable:editable];

	if (self) {
		[_email release];
		_email = [emailAddress copy];
		
		if (personImage)
			[self setIcon:personImage];
	}
	
	return self;
}

- (void)dealloc {
	[_email release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark NSCoding compliance methods

- (id)initWithCoder:(NSCoder *)coder {
	[super initWithCoder:coder];
	
	_email = [[coder decodeObjectForKey:CPPersonEmailKey] copy];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[super encodeWithCoder:coder];
	[coder encodeObject:_email forKey:CPPersonEmailKey];
}


#pragma mark -
#pragma mark NSObject comparison overrides

- (unsigned)hash {
	return [[self description] hash];
}

- (BOOL)isEqual:(id)anObject {
	return (anObject &&
			[anObject isMemberOfClass:[CPPerson class]] &&
			[[anObject description] isEqual:[self description]]);
}


#pragma mark -
#pragma mark Output representation methods

- (NSString *)description {
	if ([self email])
		return [NSString stringWithFormat:@"%@ (%@)", [self name], [self email]];
	else
		return [self name];
}

- (NSString *)toolTipText {
	return [NSString stringWithFormat:@"%@\nUser", [self description]];
}

- (NSImage *)defaultIcon {
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForImageResource:@"person.png"];
	return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
}


#pragma mark -
#pragma mark Accessor methods

- (NSString *)email {
	return _email;
}

- (void)setEmail:(NSString *)email {
	if ([self isEditable]) {
		[_email release];
		_email = [email copy];
		
		// Notify the world that this entity has changed
		[[NSNotificationCenter defaultCenter] postNotificationName:kCPEntityChanged
															object:self];
	}
}

@end
