//
//  main.m
//  Giornata
//
//  Created by Development on 8/8/09.
//  Copyright Stephen Voida 2009. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
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
