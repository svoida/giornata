#import "TransparentTableView.h"
#import "CPPalette.h"

@implementation TransparentTableView

- (void)awakeFromNib {	
    [[self enclosingScrollView] setDrawsBackground: NO];
}

- (BOOL)isOpaque {
    return NO;
}

- (void)drawBackgroundInClipRect:(NSRect)clipRect {
}

// make return and tab only end editing, and not cause other cells to edit
// from Borkware.com
- (void) textDidEndEditing:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
	
    int textMovement = [[userInfo valueForKey:@"NSTextMovement"] intValue];
	
    if (textMovement == NSReturnTextMovement ||
        textMovement == NSTabTextMovement ||
        textMovement == NSBacktabTextMovement) {
		
        NSMutableDictionary *newInfo;
        newInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
		
        [newInfo setObject:[NSNumber numberWithInt:NSIllegalTextMovement]
					forKey:@"NSTextMovement"];
		
        notification = [NSNotification notificationWithName:[notification name]
													 object:[notification object]
												   userInfo:newInfo];		
    }
	
    [super textDidEndEditing:notification];
    [[self window] makeFirstResponder:self];
}

@end
