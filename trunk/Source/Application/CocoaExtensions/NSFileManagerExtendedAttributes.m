//
//  NSFileManagerExtendedAttributes.m
//  Giornata
//
//  Created by Stephen Voida on 2/12/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import "NSFileManagerExtendedAttributes.h"

#import "NSStringWithFSExtensions.h"


@interface NSFileManager (FSExtendedAttributesPrivateAPI)

- (NSString *)fullHFSPathFromPath:(NSString *)path;

@end


#pragma mark -

@implementation NSFileManager (FSExtendedAttributes)

#pragma mark -
#pragma mark Finder/Spotlight Comment accessors

- (NSString *)finderCommentAtPath:(NSString *)path {
	if (!path)
		return nil;

	// Convert the file's pathname to be AppleScript-friendly
	NSString *hfsPath = [self fullHFSPathFromPath:path];
	
	// Run the script
	NSString *scriptCommand = [NSString stringWithFormat:@"on run\r tell application \"Finder\"\r  get comment of item \"%@\"\r end tell\rend run\r", hfsPath];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
	NSDictionary *errorDictionary;
	NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errorDictionary];
	[appleScript release];
	
	// Check and return the result
	if (result)
		return [result stringValue];
	else
		return nil;
}

- (void)setFinderComment:(NSString *)comment atPath:(NSString *)path {
	if (!path)
		return;
	if (!comment)
		comment = @"";

	// Convert the file's pathname to be AppleScript-friendly
	NSString *hfsPath = [path HFSPathFromPOSIXPath];
	
	// Run the script
	NSString *scriptCommand = [NSString stringWithFormat:@"on run\r tell application \"Finder\"\r  set comment of item \"%@\" to \"%@\"\r end tell\rend run\r", hfsPath, comment];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
	NSDictionary *errorDictionary;
    [appleScript executeAndReturnError:&errorDictionary];
	[appleScript release];
}

#pragma mark -
#pragma mark File "tag" accessors (via Finder Comments)

- (NSArray *)fileTagsAtPath:(NSString *)path {
	return [NSString tagsFromComment:[self finderCommentAtPath:path]];
}

- (void)setFileTags:(NSArray *)tags atPath:(NSString *)path {
	[self setFinderComment:[NSString commentWithTags:tags nontagData:[self nonTagCommentsAtPath:path]] atPath:path];
}

- (void)addFileTags:(NSArray *)additionalTags andRemoveFileTags:(NSArray *)extraneousTags atPath:(NSString *)path {
	BOOL didMakeChanges = NO;
	
	// Fetch the current tags
	NSMutableArray *fileTags = [[self fileTagsAtPath:path] mutableCopy];
	
	// Add the additional tags
	if (additionalTags) {
		NSEnumerator *tags = [additionalTags objectEnumerator];
		NSString *tag;
		while (tag = [tags nextObject]) {
			if (![fileTags containsObject:tag]) {
				[fileTags addObject:tag];
				didMakeChanges = YES;
			}
		}
	}

	// Remove the extraneous tags
	if (extraneousTags) {
		NSEnumerator *tags = [extraneousTags objectEnumerator];
		NSString *tag;
		while (tag = [tags nextObject]) {
			[fileTags removeObject:tag];
			didMakeChanges = YES;
		}
	}
	
	// Commit the tags if anything changed
	if (didMakeChanges)
		[self setFileTags:fileTags atPath:path];
}

- (NSString *)nonTagCommentsAtPath:(NSString *)path {
	return [NSString nontagDataFromComment:[self finderCommentAtPath:path]];
}

#pragma mark -
#pragma mark Desktop position accessors

- (NSPoint)desktopPositionAtPath:(NSString *)path {
	if (!path)
		return NSZeroPoint;
	
	// Convert the file's pathname to be AppleScript-friendly
	NSString *hfsPath = [self fullHFSPathFromPath:path];
	
	// Run the script
	NSString *scriptCommand = [NSString stringWithFormat:@"on run\r tell application \"Finder\"\r  get desktop position of item \"%@\" as list\r end tell\rend run\r", hfsPath];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
	NSDictionary *errorDictionary;
	NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errorDictionary];
	[appleScript release];

	// Check and return the result
	if ([result numberOfItems] == 2)
		return NSMakePoint((float)[[result descriptorAtIndex:1] int32Value], (float)[[result descriptorAtIndex:2] int32Value]);
	
	return NSZeroPoint;
}

- (void)setDesktopPosition:(NSPoint)point atPath:(NSString *)path {
	if (!path)
		return;

	// Convert the file's pathname to be AppleScript-friendly
	NSString *hfsPath = [path HFSPathFromPOSIXPath];
	int x = (int)roundf(point.x);
	int y = (int)roundf(point.y);
	
	// Run the script
	NSString *scriptCommand = [NSString stringWithFormat:@"on run\r tell application \"Finder\"\r  set desktop position of item \"%@\" to {%d, %d}\r end tell\rend run\r", hfsPath, x, y];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
	NSDictionary *errorDictionary;
	[appleScript executeAndReturnError:&errorDictionary];
	[appleScript release];
}

#pragma mark -
#pragma mark Color label accessors

- (int)labelIndexAtPath:(NSString *)path {
	if (!path)
		return nil;
	
	// Convert the file's pathname to be AppleScript-friendly
	NSString *hfsPath = [self fullHFSPathFromPath:path];
	
	// Run the script
	NSString *scriptCommand = [NSString stringWithFormat:@"on run\r tell application \"Finder\"\r  get label index of item \"%@\"\r end tell\rend run\r", hfsPath];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
	NSDictionary *errorDictionary;
	NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errorDictionary];
	[appleScript release];
	
	// Check and return the result
	if (result)
		return (int)[result int32Value];
	else
		return nil;
}

- (void)setLabelIndex:(int)labelIndex atPath:(NSString *)path {
	if (!path || labelIndex < 0 || labelIndex > 7)
		return;
	
	// Convert the file's pathname to be AppleScript-friendly
	NSString *hfsPath = [path HFSPathFromPOSIXPath];
	
	// Run the script
	NSString *scriptCommand = [NSString stringWithFormat:@"on run\r tell application \"Finder\"\r  set label index of item \"%@\" to %d\r end tell\rend run\r", hfsPath, labelIndex];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptCommand];
	NSDictionary *errorDictionary;
    [appleScript executeAndReturnError:&errorDictionary];
	[appleScript release];
}

@end


#pragma mark -

@implementation NSFileManager (FSExtendedAttributesPrivateAPI)

- (NSString *)fullHFSPathFromPath:(NSString *)path {
	if (path) {
		if ([path isAbsolutePath])
			return [path HFSPathFromPOSIXPath];
		else
			return [[[self currentDirectoryPath] stringByAppendingPathComponent:path] HFSPathFromPOSIXPath];
	}
	
	return nil;
}

@end


