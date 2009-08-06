//
//  NSFileManagerDesktopShuffle.m
//  Giornata
//
//  Created by Stephen Voida on 2/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSFileManagerDesktopShuffle.h"
#import "NSFileManagerExtendedAttributes.h"

#define FSDesktopLayoutFile @".DesktopLayout"


@implementation NSFileManager (FSDesktopShuffle)


- (BOOL)moveDesktopItemsToFolder:(NSString *)destinationFolder storeLocations:(BOOL)storeLocations {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *desktopFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	
	NSMutableData *locationData = nil;
	NSKeyedArchiver *locationArchiver = nil;
	if (storeLocations) {
		locationData = [NSMutableData data];
		locationArchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:locationData];
	}
	
	BOOL overallResult = YES;
	
	NSEnumerator *desktopItems = [[fileManager directoryContentsAtPath:desktopFolder] objectEnumerator];

	if ([fileManager fileExistsAtPath:destinationFolder] == NO)
		[fileManager createDirectoryAtPath:destinationFolder attributes:nil];
	
	NSString *desktopItem;
	while (overallResult && (desktopItem = [desktopItems nextObject])) {
		// Skip invisible items
		if ([[desktopItem substringToIndex:1] compare:@"."] == NSOrderedSame)
			continue;
		
		NSString *sourcePath = [desktopFolder stringByAppendingPathComponent:desktopItem];
		NSString *destinationPath = [destinationFolder stringByAppendingPathComponent:desktopItem];
		
		// (Optionally) Store location of item before moving it
		if (storeLocations)
			[locationArchiver encodePoint:[fileManager desktopPositionAtPath:sourcePath]
								   forKey:desktopItem];
		
		// Preserve finder comments during move (it's unclear that this happens automatically...)
		NSString *comments = [fileManager finderCommentAtPath:sourcePath];
		
		BOOL moveResult = [fileManager movePath:sourcePath
										 toPath:destinationPath
										handler:NULL];
		// If there was a failure, note it to return to the caller
		if (moveResult == NO) {
			NSLog(@"ERROR: Problem moving Desktop item \"%@\" to folder \"%@\"", desktopItem, destinationFolder);
			overallResult = NO;
		} else
			// Otherwise, apply stored finder comments to moved file
			[fileManager setFinderComment:comments atPath:destinationPath];
	}

	// So long as we didn't hit a snag, record the location data
	if (storeLocations && overallResult) {
           [locationArchiver finishEncoding];
           [locationData writeToFile:[destinationFolder stringByAppendingPathComponent:FSDesktopLayoutFile] atomically:YES];
       }

    [locationArchiver release];
	return overallResult;
}


- (BOOL)moveItemsToDesktopFromFolder:(NSString *)sourceFolder {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *desktopFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	
	if ([fileManager fileExistsAtPath:sourceFolder] == NO)
		return NO;

	NSData *locationData;
	NSKeyedUnarchiver *locationUnarchiver = nil;
	if ([fileManager fileExistsAtPath:[sourceFolder stringByAppendingPathComponent:FSDesktopLayoutFile]]) {
		locationData = [NSData dataWithContentsOfFile:[sourceFolder stringByAppendingPathComponent:FSDesktopLayoutFile]];
		locationUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:locationData];
	}

	BOOL overallResult = YES;
	
	NSEnumerator *sourceItems = [[[NSFileManager defaultManager] directoryContentsAtPath:sourceFolder] objectEnumerator];
	
	NSString *sourceItem;
	while (overallResult && (sourceItem = [sourceItems nextObject])) {
		// Skip invisible items
		if ([[sourceItem substringToIndex:1] compare:@"."] == NSOrderedSame)
			continue;
		
		NSString *sourcePath = [sourceFolder stringByAppendingPathComponent:sourceItem];
		NSString *destinationPath = [desktopFolder stringByAppendingPathComponent:sourceItem];
		
		// Preserve finder comments during move (it's unclear that this happens automatically...)
		NSString *comments = [fileManager finderCommentAtPath:sourcePath];

		BOOL moveResult = [[NSFileManager defaultManager] movePath:sourcePath
															toPath:destinationPath
														   handler:NULL];
		// If there was a failure, note it to return to the caller
		if (moveResult == NO) {
			NSLog(@"ERROR: Problem moving item \"%@\" to Desktop folder", sourcePath);
			overallResult = NO;
		} else {
			// Otherwise, if we know where this item was originally positioned on the desktop, make sure it goes back there
			if ([locationUnarchiver containsValueForKey:sourceItem])
				[fileManager setDesktopPosition:[locationUnarchiver decodePointForKey:sourceItem]
										 atPath:destinationPath];
			
			// Apply stored finder comments to moved file
			[fileManager setFinderComment:comments atPath:destinationPath];	
		}
	}
	
	[locationUnarchiver finishDecoding];
	[locationUnarchiver release];
	return overallResult;	
}

- (unsigned)visibleItemsOnDesktop {
	NSString *desktopFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	NSEnumerator *desktopItems = [[[NSFileManager defaultManager] directoryContentsAtPath:desktopFolder] objectEnumerator];
	
	int visibleCount = 0;
	NSString *desktopItem;
	while (desktopItem = [desktopItems nextObject])
		if ([[desktopItem substringToIndex:1] compare:@"."] != NSOrderedSame)
			visibleCount++;
	
	return visibleCount;
}

@end
