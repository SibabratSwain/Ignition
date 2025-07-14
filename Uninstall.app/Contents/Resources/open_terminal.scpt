#
# Opens an instance of Terminal and forces a screen command to the front tab/window. The command is elevated with sudo
# and expects a screen configuration file at /tmp/ignition_install.screenrc to configure the screen instance. The first
# argument must be the bash script to run. All subsequent args are passed through to the script unaltered.
#

on run argv
  set shell_script to item 1 of argv
  set args to ""
  set include to 0
  repeat with theItem in argv
    if include is greater than 0 then
      set args to args & " " & theItem
    else
      set include to 1
    end if
  end repeat
  tell application "Terminal"
    do script "sudo screen -c /tmp/ignition_install.screenrc -U " & shell_script & args & "" in window 1
    set frontWindow to window 1
    repeat until busy of frontWindow is false
      delay 1
    end repeat
  end tell
  return args
end run