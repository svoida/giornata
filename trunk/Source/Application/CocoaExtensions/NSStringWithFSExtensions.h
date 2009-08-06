//
//  NSStringWtihFSExtensions.h
//
//  Incorporates HFSPathUtils code posted to CocoaBuilder.com by Bill Monk on 13 July 2005
//  (http://www.cocoabuilder.com/archive/message/cocoa/2005/7/13/141777)
//  

#import <Cocoa/Cocoa.h>

@interface NSString (FSExtensions) 

#pragma mark Path conversion utility functions

- (NSString *)HFSPathFromPOSIXPath; 
- (BOOL)pascalString:(StringPtr)outPStringPtr
			  maxLen:(long)bufferSize;

#pragma mark -
#pragma mark Tag handling for Finder Comments

+ (NSArray *)tagsFromComment:(NSString *)comment;
+ (NSString *)nontagDataFromComment:(NSString *)comment;
+ (NSString *)commentWithTags:(NSArray *)tags nontagData:(NSString *)data;

@end 
