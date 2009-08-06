//
//  NSFileManagerExtendedAttributes.h
//  Giornata
//
//  Created by Stephen Voida on 2/12/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kFSColorLabelNone	0
#define kFSColorLabelRed	2
#define kFSColorLabelOrange 1
#define kFSColorLabelYellow	3
#define kFSColorLabelGreen	6
#define kFSColorLabelBlue	4
#define kFSColorLabelPurple	5
#define kFSColorLabelGray	7


@interface NSFileManager (FSExtendedAttributes)

#pragma mark -
#pragma mark Finder/Spotlight Comment accessors
- (NSString *)finderCommentAtPath:(NSString *)path;
- (void)setFinderComment:(NSString *)comment atPath:(NSString *)path;

#pragma mark -
#pragma mark File "tag" accessors (via Finder Comments)
- (NSArray *)fileTagsAtPath:(NSString *)path;
- (void)setFileTags:(NSArray *)tags atPath:(NSString *)path;
- (void)addFileTags:(NSArray *)additionalTags andRemoveFileTags:(NSArray *)extraneousTags atPath:(NSString *)path;
- (NSString *)nonTagCommentsAtPath:(NSString *)path;

#pragma mark -
#pragma mark Desktop position accessors
- (NSPoint)desktopPositionAtPath:(NSString *)path;
- (void)setDesktopPosition:(NSPoint)point atPath:(NSString *)path;

#pragma mark -
#pragma mark Color label accessors
- (int)labelIndexAtPath:(NSString *)path;
- (void)setLabelIndex:(int)labelIndex atPath:(NSString *)path;

@end
