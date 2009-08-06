-- Inbox filter script for Apple Mail
-- based on AppleScript by Sam Deane

on run
	tell application "Mail"
		activate
	end tell
	
	tell application "System Events"
		tell process "Mail"
			-- select the inbox
			click menu item "In" of menu "Go To" of menu item "Go To" of menu "Mailbox" of menu bar item "Mailbox" of menu bar 1
			
			-- select the "mailbox search" menu item
			click menu item "Mailbox Search" of menu "Find" of menu item "Find" of menu "Edit" of menu bar item "Edit" of menu bar 1
			
			-- type the search term and hit return
			keystroke "%EMAIL%"
			keystroke return
			
			repeat until exists button "Inbox" of window 1
				-- can get errors if the script runs before the button has been created...
				-- so we wait here
			end repeat
			
			-- click the Inbox button (as opposed to searching in all mailboxes)
			click button "Inbox" of window 1
			
			-- click the from button to search in the From: field
			click button "From" of window 1
		end tell
	end tell
end run
