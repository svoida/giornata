/* ActiveDesktop */

#import <Cocoa/Cocoa.h>
#import "HUDWindow.h"
#import "PNDesktop.h"
#import "RoundedBox.h"


@interface ActiveDesktop : NSObject
{
	IBOutlet NSPanel *_desktopLayout;
	IBOutlet NSTextView *_tagDisplay;
	IBOutlet RoundedBox *_sharedSpace;
	IBOutlet NSWindow *_tagEditingPanel;
	IBOutlet NSTokenField *_tagField;
	IBOutlet NSPanel *_screenChangeWarningPanel;
	
	NSWindow *_desktopWindow;
	NSWindow *_changeTagsButtonWindow;
	NSRect _fullSizeFrame;

	BOOL _underlaysEnabled;
    BOOL _fadeToTransparent;
	
	PNDesktop *_currentDesktop;
}

#pragma mark -
#pragma mark Accessors
- (BOOL)underlaysEnabled;
- (PNDesktop *)currentDesktop;

#pragma mark -
#pragma mark Action callbacks
- (IBAction)commitTagEdits:(id)sender;
- (IBAction)commitTagEditsRetroactively:(id)sender;

#pragma mark -
#pragma mark NotificationCenter callbacks
- (void)desktopChanged:(NSNotification*)notification;
- (void)displayResized:(NSNotification *)notification;
- (void)fileSystemChanged:(NSNotification *)notification;

#pragma mark -
#pragma mark ChangeTagsButton action callback
- (void)changeTags:(id)sender;

#pragma mark -
#pragma mark Presentation Mode support
- (void)fadeToTransparent:(BOOL)toTransparent;

@end
