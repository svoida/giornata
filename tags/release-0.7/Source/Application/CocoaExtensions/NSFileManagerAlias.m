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
*******************************************************************************/ 

#import "NSFileManagerAlias.h"

@implementation NSFileManager(VTAlias) 


- (AliasHandle) makeAlias: (NSString*) path {
	FSRef		ref;
	NSURL*		url = [NSURL fileURLWithPath: path];
	AliasHandle alias;
	OSErr		err = noErr;
	
	if (CFURLGetFSRef((CFURLRef)url, &ref)) {
		err = FSNewAliasMinimal(&ref, &alias);
		if (noErr == err) {
			return alias;
		}
	}
	
	return nil; 
}

@end
