//
//  GiornataController.m
//  Giornata
//
//  Created by Development on 8/15/09.
//  Copyright 2009 Stephen Voida. All rights reserved.
//

#import "GiornataController.h"
#import "GiornataPlugInProtocol.h"

NSString *ext = @"plugin";
NSString *appSupportSubpath = @"Application Support/Giornata/PlugIns";

@implementation GiornataController

- (void)awakeFromNib
{
	[self loadAllPlugIns];
}

- (BOOL)plugInClassIsValid:(Class)plugInClass;
{
    if([plugInClass conformsToProtocol:@protocol(GiornataPlugIn)])
	{
		// Check that all of the required selectors are actually implemented
        if([plugInClass instancesRespondToSelector:@selector(pluginLoaded:)] &&
		   [plugInClass instancesRespondToSelector:@selector(interfaceVersion)] &&
           [plugInClass instancesRespondToSelector:@selector(displayName)] &&
		   [plugInClass instancesRespondToSelector:@selector(description)] &&
           [plugInClass instancesRespondToSelector:@selector(plugInConfigurationViewController)])
		{
            return YES;
        }
	}
		   
	return NO;
}

	
- (NSMutableArray *)allPlugInBundles;
{
	NSArray *librarySearchPaths;
	NSEnumerator *searchPathEnum;
	NSString *currPath;
	NSMutableArray *bundleSearchPaths = [NSMutableArray array];
	NSMutableArray *allBundles = [NSMutableArray array];
	
	librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
	
	searchPathEnum = [librarySearchPaths objectEnumerator];
	while(currPath = [searchPathEnum nextObject])
	{
		[bundleSearchPaths addObject:
		 [currPath stringByAppendingPathComponent:appSupportSubpath]];
	}
	[bundleSearchPaths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	
	searchPathEnum = [bundleSearchPaths objectEnumerator];
	while(currPath = [searchPathEnum nextObject])
	{
		NSDirectoryEnumerator *bundleEnum;
		NSString *currBundlePath;
		bundleEnum = [[NSFileManager defaultManager] enumeratorAtPath:currPath];
		if(bundleEnum)
		{
			while(currBundlePath = [bundleEnum nextObject])
			{
				if([[currBundlePath pathExtension] isEqualToString:ext])
				{
					[allBundles addObject:[currPath stringByAppendingPathComponent:currBundlePath]];
				}
			}
		}
	}
	
	return allBundles;
}


- (void)loadAllPlugIns;
{
	NSMutableArray *bundlePaths;
	NSBundle *currBundle;
	Class currPrincipalClass;
	id currInstance;
			
	if (!plugIns)
	{
		plugIns = [[NSMutableArray alloc] init];
	}
			
	bundlePaths = [NSMutableArray array];
	[bundlePaths addObjectsFromArray:[self allPlugInBundles]];
	
	for (NSString *currPath in bundlePaths)
	{
		currBundle = [NSBundle bundleWithPath:currPath];
		if(currBundle)
		{
			currPrincipalClass = [currBundle principalClass];
			if(currPrincipalClass &&
			   [self plugInClassIsValid:currPrincipalClass])
			{
				currInstance = [[currPrincipalClass alloc] init];
				if(currInstance)
				{
					[plugIns addObject:currInstance];
					
					NSLog(@"Loaded the plugin named %@, version %@.",
						  [(id<GiornataPlugIn>)currInstance displayName],
						  [[currBundle infoDictionary] objectForKey:@"CFBundleVersion"]);
				}
			} else {
				NSLog(@"Invalid plugin file discovered: %@", [currBundle bundleIdentifier]);
			}
		}
	}
}
		   
@end
