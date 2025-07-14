#
# Requests Admin privilegs via the systems default escalation method. This is usually a GUI login window which supports
# touch ID etc. The first argument must be the bash script to run. All subsequent args are passed through to the script
# unaltered.
#

on run argv
  set shell_script to item 1 of argv
  set args to " "
  set include to 0
  repeat with theItem in argv
    if include is greater than 0 then
      set args to args & " " & theItem
    else
      set include to 1
    end if
  end repeat
  do shell script shell_script & args with prompt "Ignition Installer requires an Administrator to install" with administrator privileges
  return args
end run