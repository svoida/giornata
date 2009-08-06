//
//  CPRootGroup.h
//  ContactPalette
//
//  Created by Stephen Voida on 1/31/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CPGroup.h"


@interface CPRootGroup : CPGroup {

}

- (void)setContents:(NSMutableArray *)contents;
- (NSMutableArray *)contents;

- (int)updateVariableBadgeCounts;

@end
