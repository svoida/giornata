//
//  GiornataController.h
//  Giornata
//
//  Created by Development on 8/15/09.
//  Copyright 2009 Stephen Voida. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GiornataController : NSObject {
	NSMutableArray *plugIns;
}

- (NSMutableArray *)allPlugInBundles;
- (BOOL)plugInClassIsValid:(Class)plugInClass;
- (void)loadAllPlugIns;

@end
