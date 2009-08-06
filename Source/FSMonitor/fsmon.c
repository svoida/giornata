/*
###############################################################################
#                                                                             #
#   fsmon 0.1                                                                 #
#   Subscribes to Mac OS X 10.4 fsevents and displays all filesystem changes. #
#                                                                             #
#   Based on gfslogger v0.9                                                   #
#   Copyright (C) 2005 Rian Hunter [rian at thelaststop point net]            #
#                                                                             #
#   Modified to only output file paths, to stamp events with an approximate   #
#   time of generation, and automatically kill itself if stdout dies.         #
#   Modifications by RbrtPntn, 20 August 2005                                 #
#																			  #
#   Further modified to remove debugging code, further minimize events        #
#   caught and information displayed for each file.                           #
#   Modifications by Stephen Voida, 19 September 2006                         #
#                                                                             #
#   This program is free software; you can redistribute it and/or modify      #
#   it under the terms of the GNU General Public License as published by      #
#   the Free Software Foundation; either version 2 of the License, or         #
#   (at your option) any later version.                                       #
#                                                                             #
#   This program is distributed in the hope that it will be useful,           #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of            #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
#   GNU General Public License for more details.                              #
#                                                                             #
#   You should have received a copy of the GNU General Public License         #
#   along with this program; if not, write to the Free Software	              #
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA #
#                                                                             #
###############################################################################
*/

// for open(2)
#include <fcntl.h>

// for ioctl(2)
#include <sys/ioctl.h>
#include <sys/sysctl.h>

// for read(2)
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

// for printf(3)
#include <stdio.h>

// for exit(3)
#include <stdlib.h>

// for strncpy(3)
#include <string.h>

// for getpwuid(3)
#include <pwd.h>

// for getgrgid(3)
#include <grp.h>

// for S_IS*(3)
#include <sys/stat.h>

#include <mach-o/dyld.h>
#include <sys/errno.h>
#include <sys/param.h>
#include <sys/wait.h>
#include <stdio.h>
#include <time.h> 

// duh.
#include "fsevents.h"

static int gfslogger_loop();
static void printPath(int32_t type, pid_t pid, char *path);
static void process_event_data(void *, int);

char large_buf[0x2000];

// activates self as fsevent listener and displays fsevents
// must be run as root!! (at least on Mac OS X 10.4)
static int gfslogger_loop() {
  int newfd, fd, n;
  signed char event_list[FSE_MAX_EVENTS];
  fsevent_clone_args retrieve_ioctl;
  
  // list of events we actually care about
  // (events that indicate a substantive change in a file)
  event_list[FSE_CREATE_FILE]         = FSE_REPORT;
  event_list[FSE_RENAME]              = FSE_REPORT;
  event_list[FSE_CONTENT_MODIFIED]    = FSE_REPORT;
  event_list[FSE_EXCHANGE]            = FSE_REPORT;
  event_list[FSE_CREATE_DIR]          = FSE_REPORT;

  fd = open("/dev/fsevents", 0, 2);
  if (fd < 0) {
    exit(1);
  }

  retrieve_ioctl.event_list = event_list;
  retrieve_ioctl.num_events = sizeof(event_list);
  retrieve_ioctl.event_queue_depth = 0x400;
  retrieve_ioctl.fd = &newfd;

  if (ioctl(fd, FSEVENTS_CLONE, &retrieve_ioctl) < 0) {
    exit(1);
  }
  close(fd);

  fprintf(stderr, "fsmon running...\n");

  // note: you must read at least 2048 bytes at a time on this fd, to get data.
  // also you read quick! newer events can be lost in the internal kernel event
  // buffer if you take too long to get events. thats why buffer is so large:
  // less read calls.
  while ((n = read(newfd, large_buf, sizeof(large_buf))) > 0) {
    process_event_data(large_buf, n);
  }

  return 0;
}
 
void printPath(int32_t type, pid_t pid, char *path) {
	/* if we can't write to stdout anymore then kill ourself - either our parent died or the fd closed*/
	struct stat st;
	time_t when;
  	if(fstat(1, &st) != 0) exit(0); /* exit nicely */

	/* only write file paths */
	if(!path[0] || (path[0] != '/')) return;
	
	/* stamp with the time */
	time(&when);

	fprintf(stdout, "%d:%ld:%ld:%s\n", (int)type, (long)pid, when, path);
	fflush(stdout);
}

// parses the incoming event data and displays it in a friendly way
static void process_event_data(void *in_buf, int size) {
	int pos = 0;
	pid_t pid;
	u_int16_t argtype;
	u_int16_t arglen;

	do {
		int32_t type = *((int32_t *) (in_buf + pos));
	
		// Filter for invalid data
		switch (type) {
			case FSE_CREATE_FILE:
			case FSE_RENAME:
			case FSE_CONTENT_MODIFIED:
			case FSE_EXCHANGE:
			case FSE_CREATE_DIR:
				break;
			case FSE_INVALID: default:
				return; // <----------we return if invalid type (give up on this data)
				break;
		}	
		pos += 4;
	
		pid = *((pid_t *) (in_buf + pos));
		pos += sizeof(pid_t);
	
		while(1) {
			argtype = *((u_int16_t *) (in_buf + pos));
			pos += 2;

			if (FSE_ARG_DONE == argtype) {
				break;
			}

			arglen = *((u_int16_t *) (in_buf + pos));
			pos += 2;
			
			switch(argtype) {
				case FSE_ARG_VNODE:
					printPath(type, pid, in_buf + pos);
					break;
				case FSE_ARG_STRING:
					printPath(type, pid, in_buf + pos);
					break;
				case FSE_ARG_PATH: // not in kernel
					printPath(type, pid, in_buf + pos);
					break;
				case FSE_ARG_INT32:
				case FSE_ARG_INT64: // not supported in kernel yet
				case FSE_ARG_RAW: // just raw bytes, can't display
				case FSE_ARG_INO:
				case FSE_ARG_UID:
				case FSE_ARG_DEV:
				case FSE_ARG_MODE:
				case FSE_ARG_GID:
					break;
				default:
					return; // <----------we return if invalid type (give up on this data)
					break;
			}
			pos += arglen;
		}
	} while (pos < size);

	return;
}

int main(int argc, char * const *argv) {
    unsigned int path_to_self_size = 0;
    char *path_to_self = NULL;
	
    path_to_self_size = MAXPATHLEN;
    if (! (path_to_self = malloc(path_to_self_size)))
        exit(1);
    if (_NSGetExecutablePath(path_to_self, &path_to_self_size) == -1) {
        /* Try again with actual size */
        if (! (path_to_self = realloc(path_to_self, path_to_self_size + 1)))
            exit(1);
        if (_NSGetExecutablePath(path_to_self, &path_to_self_size) != 0)
            exit(1);
    }                
	
	fprintf(stderr, "fsmon 0.1\n");
	fprintf(stderr, "running as user %d, effective user %d\n", getuid(), geteuid());
	
	if (geteuid() != 0) {
		fprintf(stderr, "Warning! Tool not installed correctly.\n");
		exit(13); /* "special" return code to indicate running with wrong permissions */
	}
	
    if (argc == 2 && (strcmp(argv[1], "--self-repair") == 0)) {
        /*  Self repair code.  We ran ourselves using AuthorizationExecuteWithPrivileges()
        so we need to make ourselves setuid root to avoid the need for this the next time around. */
        struct stat st;  
        int fd_tool;
        
		/* Open tool exclusively, so noone can change it while we bless it */
        fd_tool = open(path_to_self, O_NONBLOCK|O_RDONLY|O_EXLOCK, 0);
        if (fd_tool == -1) {
            fprintf(stderr, "Exclusive open while repairing tool failed: %d.\n", errno);
            exit(1);
        }
		
        if (fstat(fd_tool, &st))
            exit(1);
        
        if (st.st_uid != 0)
            fchown(fd_tool, 0, st.st_gid);
		
        /* Disable all writability and make setuid root. */
        fchmod(fd_tool, (st.st_mode & (~S_IWRITE)) | S_ISUID);
		
        close(fd_tool);
		
        fprintf(stderr, "Tool self-repair done.\n");
		exit(0);
    }
	
    /* No need for it anymore */
    if (path_to_self)
        free(path_to_self);
	
	gfslogger_loop();
	
	/* unreachable */
    exit(0);
}
