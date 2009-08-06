-- Check UI Scripting.applescript
-- based on AppleScript by Sam Deane

on run
	-- check to see if assistive devices is enabled
	tell application "System Events"
		if UI elements enabled then
			return true
		end if
	end tell
	
	tell application "System Preferences"
		activate
		set current pane to �
			pane "com.apple.preference.universalaccess"
		set the dialog_message to "This script utilizes " & �
			"the built-in Graphic User Interface Scripting " & �
			"architecture of Mac OS X " & �
			"which is currently disabled." & return & return & �
			"You can activate GUI Scripting by selecting the " & �
			"checkbox �Enable access for assistive devices� " & �
			"in the Universal Access preference pane."
		display dialog dialog_message buttons {"OK"} �
			default button 1 with icon 1
	end tell
	
	return false
end run
