-- Based in part on AppleScripts by Hans Hafner

on run
	-- Check if Eudora is already running. If it isn't and we're running on
	-- an Intel Mac, then we're kind of out of luck since an i386 executable
	-- can't launch a PPC app as a child process (it'll just crash)
	tell application "Finder"
		set process_list to the name of every process
		set sysa to system attribute "sysa"
		if ("Eudora" is not in process_list) and (sysa is 10) then
			display dialog "Giornata cannot start Eudora automatically when running on an Intel Mac." & return & return & Â
				"Please start Eudora manually and try again." buttons {"OK"} giving up after 10 with icon caution
			return
		end if
	end tell
	
	tell application "Eudora"
		activate

		-- Email content templates
		set subjectTemplate to "Files shared with you"
		set bodyTemplate to "(edit your message here)" & return & return & Â
			"------------------------------------" & return & Â
			"This message was sent using Giornata" & return & Â
			"http://giornata.sourceforge.net"
		
		-- Set up recipient list and file list as proper arrays
		set recipientList to {%RECIPIENTS%}
		set fileList to {%FILES%}
		
		-- Create the new message and stash it at the end of the "Out" mailbox
		set newMessage to make new message at end of mailbox 2
		
		-- Set up the basic characteristics of the message
		set field "subject" of newMessage to subjectTemplate
		set field "" of newMessage to bodyTemplate
		
		-- Build out the recipient list
		set recipientString to ""
		repeat with aRecipient in recipientList
			set recipientString to aRecipient & ", " & recipientString
		end repeat
		set field "to" of newMessage to recipientString
		
		-- Build out the attachment list
		set attachment encoding of newMessage to uuencode
		repeat with aFile in fileList
			set fileRef to aFile as alias
			attach to message newMessage documents fileRef with spooling
			-- spooling creates and attaches a copy of the original file and
			-- then deletes the copy when the message is deleted.
		end repeat
	end tell
end run