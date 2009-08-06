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
******************************************************************************/ 

#import <Cocoa/Cocoa.h>


@interface NSFileManager(VTAlias)

- (AliasHandle) makeAlias: (NSString*) path; 

@end
