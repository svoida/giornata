//
//  CPGroup.h
//  ContactPalette
//
//  Created by Stephen Voida on 12/18/06.
//  Copyright 2006 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CPEntity.h"


@interface CPGroup : CPEntity {

}

- (NSArray *)memberEmails;
- (int)updateBadgeCountsUsingDictionary:(NSDictionary *)badgeDict;

@end
