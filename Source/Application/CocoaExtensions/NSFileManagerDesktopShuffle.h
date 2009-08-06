//
//  NSFileManagerDesktopShuffle.h
//  Giornata
//
//  Created by Stephen Voida on 2/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSFileManager (FSDesktopShuffle)

- (BOOL)moveDesktopItemsToFolder:(NSString *)destinationFolder storeLocations:(BOOL)storeLocations;
- (BOOL)moveItemsToDesktopFromFolder:(NSString *)sourceFolder;
- (unsigned)visibleItemsOnDesktop;

@end
