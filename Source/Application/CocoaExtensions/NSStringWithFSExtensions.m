//
//  NSStringWithFSExtensions.m
//
//  Incorporates HFSPathUtils code posted to CocoaBuilder.com by Bill Monk on 13 July 2005
//  (http://www.cocoabuilder.com/archive/message/cocoa/2005/7/13/141777)
//  

#import "NSStringWithFSExtensions.h"

@implementation NSString (FSExtensions) 

#pragma mark Path conversion utility functions

// 
// Convert a slash-delimited POSIX path to a colon-delimited HFS path. 
// Note the HFS path will be represented as Unicode characters 
// in an NSString. If intending to use the HFS path with Carbon, 
// then use the pascalString category method to obtain the ASCII 
// length-prefixed pascal string Carbon requires. 
// 
- (NSString *)HFSPathFromPOSIXPath { 
    CFURLRef url; 
    CFStringRef hfsPath = NULL; 
    BOOL isDirectoryPath = [self hasSuffix:@"/"]; 
	
	// Note that for the usual case of absolute paths, isDirectoryPath is 
	// completely ignored by CFURLCreateWithFileSystemPath. 
	// isDirectoryPath is only considered for relative paths. 
	// This code has not really been tested relative paths... 
	url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, 
										(CFStringRef)self, 
										kCFURLPOSIXPathStyle, 
										isDirectoryPath); 
    if (url != NULL) { 
        // Convert URL to a colon-delimited HFS path 
        // represented as Unicode characters in an NSString. 
        hfsPath = CFURLCopyFileSystemPath(url, kCFURLHFSPathStyle);
        if (hfsPath != NULL) { 
            [(NSString *)hfsPath autorelease]; 
        } 
        CFRelease(url); 
    } 
    return (NSString *)hfsPath; 
} 

//
// Fill the caller's buffer with a length-prefixed pascal-style ASCII string
// converted from the Uncode characters in an NSString.
//
- (BOOL)pascalString:(StringPtr)outPStringPtr
			  maxLen:(long)bufferSize {
    BOOL convertedOK = NO;
	
    if (outPStringPtr != NULL) {
        convertedOK = CFStringGetPascalString((CFStringRef)self,
											  outPStringPtr,
											  bufferSize,
											  CFStringGetSystemEncoding());
	}
	
    return convertedOK;
}

#pragma mark -
#pragma mark Tag handling for Finder Comments

// TODO: This doesn't do the extra work of parsing tags with quotes or tags with spaces
//       or not-tags inside other quoted material. It would probably be a good idea to
//       build a more robust regex engine to take that stuff at some point.
+ (NSArray *)tagsFromComment:(NSString *)comment {
	NSMutableArray *result = [[[NSMutableArray alloc] init] autorelease];
	unsigned i;
	
	NSArray *tokens = [comment componentsSeparatedByString:@" "];
	for (i = 0; i < [tokens count]; i++) {
		NSString *token = [tokens objectAtIndex:i];
		if ([token length] > 1 &&
			[token characterAtIndex:0] == '@')
			[result addObject:[token substringFromIndex:1]];
	}
	
	return result;
}

// TODO: This is also a naive implementation, which doesn't look for quotes (see
//       comment before validTags selector for more detail)
+ (NSString *)nontagDataFromComment:(NSString *)comment {
	NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
	unsigned i;
	
	NSArray *tokens = [comment componentsSeparatedByString:@" "];
	for (i = 0; i < [tokens count]; i++) {
		NSString *token = [tokens objectAtIndex:i];
		if ([token length] > 0 &&
			[token characterAtIndex:0] != '@')
			[result appendFormat:@"%@ ", token];
	}
	
	if ([result length] > 1)
		return [result substringToIndex:([result length] - 1)];
	else
		return result;
}

+ (NSString *)commentWithTags:(NSArray *)tags nontagData:(NSString *)data {
	NSMutableString *result = [[[NSMutableString alloc] initWithString:data] autorelease];
	unsigned i;
	
	for (i = 0; i < [tags count]; i++) {
		// Make sure we're concatenating strings...
		if (![[tags objectAtIndex:i] isKindOfClass:[NSString class]])
			continue;
		
		// ...and that they don't already have the '@' tag prefix prepended onto any of them
		NSString *tag = (NSString *)[tags objectAtIndex:i];
		if ([[tag substringToIndex:1] compare:@"@"] == NSOrderedSame)
			[result appendFormat:@" %@", tag];
		else
			[result appendFormat:@" @%@", tag];
	}
	
	return result;
}

@end 
