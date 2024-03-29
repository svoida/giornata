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

#import <Carbon/Carbon.h> 
#import "NSStringWithModifiers.h" 

@implementation NSString(ZNKeyModifiers)

+ (NSString*) unicodeToString: (unichar) character {
	return [NSString stringWithCharacters: &character length: 1]; 
}

+ (NSString*) stringWithModifiers: (int) modifiers {
	NSMutableString* stringValue = [NSMutableString string];
	
	// handle modifiers and append them to the resulting string representation
	if (modifiers & NSControlKeyMask) 
		[stringValue appendString: [NSString unicodeToString: kControlUnicode]]; 
	if (modifiers & NSShiftKeyMask) 
		[stringValue appendString: [NSString unicodeToString: kShiftUnicode]]; 			
	if (modifiers & NSAlternateKeyMask) 
		[stringValue appendString: [NSString unicodeToString: kOptionUnicode]]; 			
	if (modifiers & NSCommandKeyMask) 
		[stringValue appendString: [NSString unicodeToString: kCommandUnicode]]; 			
	
	return [NSString stringWithString: stringValue]; 
}

@end
