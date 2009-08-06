-- Send an Email for Apple Mail

on run
	tell application "Mail"
		-- Email content templates
		set subjectTemplate to "Files shared with you"
		set bodyTemplate to "(edit your message here)" & return & return & Â
			"------------------------------------" & return & Â
			"This message was sent using Giornata" & return & Â
			"http://giornata.sourceforge.net"
		
		-- Set up recipient list and file list as proper arrays
		set recipientList to {%RECIPIENTS%}
		set fileList to {%FILES%}
		
		-- Properties can be specified in a record when creating the message or
		-- afterwards by setting individual property values.
		set newMessage to make new outgoing message with properties {subject:subjectTemplate, content:bodyTemplate & return & return}
		tell newMessage
			-- Default is false. Determines whether the compose window will
			-- show on the screen or whether it will happen in the background.
			set visible to true
			
			-- Build out recipient list
			repeat with aRecipient in recipientList
				make new to recipient at end of to recipients Â
					with properties {address:aRecipient}
			end repeat
			
			-- Build out attachment list
			tell content
				repeat with aFile in fileList
					make new attachment with properties {file name:aFile} Â
						at after the last word of the last paragraph
				end repeat
			end tell
		end tell
		
		-- Bring the new compose window to the foreground, in all its glory
		activate
	end tell
end run