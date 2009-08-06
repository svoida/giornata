-- Get Unread Senders for Apple Mail
-- Based on an Applescript by Todd Ditchendorf

on run
	-- Find out if Apple Mail is running; if it's not, then *don't* force it open...
	-- just return an empty list of unread senders instead
	tell application "Finder"
		set process_list to the name of every process
	end tell
	if "Mail" is not in process_list then
		return {}
	end if
	
	tell application "Mail"
		-- Get a list of all unread messages in the aggregate inbox
		set newMessages to (every message of inbox whose read status is false)
		
		-- Iterate through the messages and collect a list of their senders
		set newSenders to {}
		repeat with i from 1 to (count newMessages)
			set aMessage to item i of newMessages
			set newSenders to newSenders & (the sender of aMessage as string)
		end repeat
		
		return newSenders
	end tell
end run
