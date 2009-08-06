//
//  ADTagDisplayTransformer.m
//  Giornata
//
//  Created by Stephen Voida on 2/13/07.
//  Copyright 2007 Georgia Institute of Technology. All rights reserved.
//

#import "ADTagDisplayTransformer.h"


@implementation ADTagDisplayTransformer

+ (Class) transformedValueClass { 
	return [NSString class]; 
}

+ (BOOL) allowsReverseTransformation { 
	return NO; 
}

- (id) transformedValue: (id) value {
	if ([value isKindOfClass: [NSString class]] == NO)
		return nil; 
	
	// Give a reasonable value if there aren't any tags placed yet.
	if ([value length] == 0)
		return NSLocalizedString(@"NSStringTaglessDisplayName", @"(untagged)");
	
	// Get the current desktop "name" (a space-delineated list of tag strings)
	NSMutableString *tagString = [[value mutableCopy] autorelease];	
	// Divvy it up into a multi-line string
	[tagString replaceOccurrencesOfString:@" " withString:@"\n" options:nil range:NSMakeRange(0, [tagString length])];
	
	return (NSString *)tagString; 
}

@end
