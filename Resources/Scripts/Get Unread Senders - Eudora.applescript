-- Get Unread Senders for Eudora
-- Based on an Applescript by Todd Ditchendorf

on run
	-- Find out if Eudora is running; if it's not, then *don't* force it open...
	-- just return an empty list of unread senders instead
	tell application "Finder"
		set process_list to the name of every process
	end tell
	if "Eudora" is not in process_list then
		return {}
	end if
	
	tell application "Eudora"
		set newSenders to {}
		
		-- Get a list of all unread message senders from messages in the aggregate inbox
		set primaryInbox to name of mailbox 1
		set messageCount to number of messages in mailbox primaryInbox of application "Eudora"
		repeat with messageIndex from 1 to messageCount
			if status of message messageIndex of mailbox primaryInbox of application "Eudora" is unread then
				set senderString to field "From" of message messageIndex of mailbox primaryInbox of application "Eudora" as string
				set newSenders to newSenders & text 7 thru (length of senderString) of senderString
			end if
		end repeat
		
		-- Then add the senders of unread messages in the inboxes of any other defined (IMAP) personalities
		set accounts to (name of every mail folder as list)
		repeat with accountIndex from 1 to (count accounts)
			set messageCount to number of messages in first mailbox of mail folder (item accountIndex of accounts)
			repeat with messageIndex from 1 to messageCount
				if status of message messageIndex of first mailbox of mail folder (item accountIndex of accounts) is unread then
					set senderString to field "From" of message messageIndex of first mailbox of mail folder (item accountIndex of accounts) as string
					set newSenders to newSenders & text 7 thru (length of senderString) of senderString
				end if
			end repeat
		end repeat
		
		return newSenders
	end tell
end run