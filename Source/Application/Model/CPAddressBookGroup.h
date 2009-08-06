//
//  CPAddressBookGroup.h
//  ContactPalette
//
//  Created by Stephen Voida on 1/21/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/ABGroup.h>
#import "CPGroup.h"


@interface CPAddressBookGroup : CPGroup {

}

// Factory method
+ (CPAddressBookGroup *)addressBookGroupFromAddressBook;

// Conversion method
- (CPGroup *)editableDuplicate;

@end
