/*
 *  GLGrab.h
 *  Giornata
 *
 *  Created by Stephen Voida on 1/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl.h>

CGImageRef grabViaOpenGL(CGDirectDisplayID display, CGRect srcRect);
