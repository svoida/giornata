//
//  CPPerson.h
//  ContactPalette
//
//  Created by Stephen Voida on 12/5/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CPEntity.h"


@interface CPPerson : CPEntity {
	NSString *_email;
}

// Lifetime methods
- (id)initWithEmail:(NSString *)email editable:(BOOL)editable;
- (id)initWithVCardRepresentation:(NSData *)vCardData editable:(BOOL)editable;

// Accessor methods
- (NSString *)email;
- (void)setEmail:(NSString *)email;

@end
