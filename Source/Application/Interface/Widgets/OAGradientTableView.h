// Copyright 2003-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: /net/cvs/ecl/giornata-final/Source/Application/Interface/Widgets/OAGradientTableView.h,v 1.1 2007/02/11 06:00:49 svoida Exp $


#import <AppKit/NSTableView.h>

// For this to look right your cell class must return -[NSColor textBackgroundColor] from -textColor when it is highlighted.  See OATextWithIconCell for example.

@interface OAGradientTableView : NSTableView
{
  struct {
    unsigned int acceptsFirstMouse:1;
  } flags;
}

- (void)setAcceptsFirstMouse:(BOOL)flag;

@end
