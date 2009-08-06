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

#import <Cocoa/Cocoa.h>
#import <Foundation/NSDebug.h>

int main(int argc, char *argv[]) {
	
	// Optionally, redirect all program output to a log file (for data collection purposes)
	if (argc > 1 && strcmp(argv[1], "-nolog") == 0) {
		NSLog(@"Logging messages to the console (for debugging). No permanent log file will be created.");
	} else {
		char *val_buf, path_buf[155];
		val_buf = getenv("HOME");
		sprintf(path_buf,"%s/Library/Logs/Giornata.log",val_buf);
		freopen(path_buf,"a",stderr);
	}

#if defined (DEBUG)
    NSLog(@"Additional debugging features (zombies, freed object check) enabled");
    
	NSDebugEnabled = YES;
    NSZombieEnabled = YES;
    [NSAutoreleasePool enableFreedObjectCheck:YES];
#endif /* DEBUG */
    
    return NSApplicationMain(argc,  (const char **) argv);
}
