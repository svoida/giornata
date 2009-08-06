on run
	tell application "Address Book"
		activate
	end tell
	
	tell application "System Events"
		tell process "Address Book"
			-- select the "find" menu item
			click menu item "Find" of menu "Find" of menu item "Find" of menu "Edit" of menu bar item "Edit" of menu bar 1
			
			-- type the search term and hit return
			keystroke "%EMAIL%"
			keystroke return
			
			-- press "Escape" to undo all the highlighting and stuff
			key code 53
		end tell
	end tell
end run