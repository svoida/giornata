/******************************************************************************
* 
* VirtueDesktops 
*
* A desktop extension for MacOS X
*
* Copyright 2004, Thomas Staller playback@users.sourceforge.net
* Copyright 2005-2006, Tony Arnold tony@tonyarnold.com
*
* See COPYING for licensing details
* 
*****************************************************************************/ 

#import "VTDesktopIdTransformer.h"
#import "VTDesktopController.h"

@implementation VTDesktopIdTransformer

+ (Class) transformedValueClass { 
	return [PNDesktop class]; 
}

+ (BOOL) allowsReverseTransformation { 
	return YES; 
}

- (id) transformedValue: (id) value {
	if ([value isKindOfClass: [NSNumber class]] == NO)
		return nil; 
	
	return [[VTDesktopController sharedInstance] desktopWithIdentifier: [(NSNumber*)value intValue]]; 
}

- (id) reverseTransformedValue: (id) value {
	if ([value isKindOfClass: [PNDesktop class]] == NO) 
		return nil; 
	
	return [NSNumber numberWithInt: [(PNDesktop*)value identifier]]; 
}

@end
