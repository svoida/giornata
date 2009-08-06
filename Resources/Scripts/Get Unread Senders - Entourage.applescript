-- Get Unread Senders for Microsoft Entourage
-- Based (very loosely, now) on an Applescript by Todd Ditchendorf

on run
	-- Find out if Entourage is running; if it's not, then *don't* force it open...
	-- just return an empty list of unread senders instead
	tell application "Finder"
		set process_list to the name of every process
	end tell
	if "Microsoft Entourage" is not in process_list then
		return {}
	end if
	
	tell application "Microsoft Entourage"
		-- Construct a folder list of all inboxes from all accounts
		-- Start with the local Entourage inbox (POP accounts, primarily)
		set folder_list to (folders whose name is "inbox")
		-- Add Exchange accounts
		repeat with i from 1 to (number of items of every Exchange account)
			if (inbox folder of item i of every Exchange account is not missing value) then
				set folder_list to folder_list & (inbox folder of item i of every Exchange account)
			end if
		end repeat
		-- Add IMAP accounts
		repeat with i from 1 to (number of items of every IMAP account)
			set folder_list to folder_list & (folders of item i of every IMAP account whose name is "inbox")
		end repeat
		-- Add Hotmail accounts
		repeat with i from 1 to (number of items of every Hotmail account)
			set folder_list to folder_list & (folders of item i of every Hotmail account whose name is "inbox")
		end repeat
		
		-- Iterate through the inboxes and collect a list of the senders of all untouched emails in each
		set senders to {}
		repeat with i from 1 to (number of items of folder_list)
			set aFolder to item i of the folder_list
			set message_list to (every message in aFolder whose read status is untouched)
			repeat with i from 1 to (number of items of message_list)
				set aMessage to item i of the message_list
				if (the read status of aMessage is untouched) then
					set senders to senders & (address of the sender of aMessage)
				end if
			end repeat
		end repeat
		
		return senders
	end tell
end run
