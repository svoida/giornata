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
		set current pane to Â
			pane "com.apple.preference.universalaccess"
		set the dialog_message to "This script utilizes " & Â
			"the built-in Graphic User Interface Scripting " & Â
			"architecture of Mac OS X " & Â
			"which is currently disabled." & return & return & Â
			"You can activate GUI Scripting by selecting the " & Â
			"checkbox ÒEnable access for assistive devicesÓ " & Â
			"in the Universal Access preference pane."
		display dialog dialog_message buttons {"OK"} Â
			default button 1 with icon 1
	end tell
	
	return false
end run
