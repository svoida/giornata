-- Send an Email for Microsoft Entourage

on run
	-- Check if Entourage is already running. If it isn't and we're running on
	-- an Intel Mac, then we're kind of out of luck since an i386 executable
	-- can't launch a PPC app as a child process (it'll just crash)
	tell application "Finder"
		set process_list to the name of every process
		set sysa to system attribute "sysa"
		if ("Microsoft Entourage" is not in process_list) and (sysa is 10) then
			display dialog "Giornata cannot start Microsoft Entourage automatically when running on an Intel Mac." & return & return & Â
				"Please start Entourage manually and try again." buttons {"OK"} giving up after 10 with icon caution
			return
		end if
	end tell
	
	tell application "Microsoft Entourage"
		activate
		
		-- Email content templates
		set subjectTemplate to "Files shared with you"
		set bodyTemplate to "(edit your message here)" & return & return & Â
			"------------------------------------" & return & Â
			"This message was sent using Giornata" & return & Â
			"http://giornata.sourceforge.net"
		
		-- Set up recipient list and file list as proper arrays
		set recipientList to {%RECIPIENTS%}
		set fileNameList to {%FILES%}
		
		-- Convert recpient list to a comma-delimited string
		set recipientString to ""
		repeat with aRecipient in recipientList
			set recipientString to aRecipient & ", " & recipientString
		end repeat
		
		-- Properties can be specified in a record when creating the message or
		-- afterwards by setting individual property values.
		set newDraft to make new draft window with properties {to recipients:recipientString, subject:subjectTemplate, content:bodyTemplate & return & return}
		
		-- Build out attachment list
		repeat with aFileName in fileNameList
			set aFile to aFileName as alias
			make new attachment at newDraft with properties {file:aFile}
		end repeat
	end tell
end run