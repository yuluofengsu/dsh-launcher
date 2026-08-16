' stop-dsh.vbs - hidden launcher for stop-dsh.ps1 (no console window, no popups)
' Used by the "Exit DeepSeek Harness" desktop shortcut.
Set ws = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Dim ps, here
ps = ws.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
here = fso.GetParentFolderName(WScript.ScriptFullName)
ws.Run """" & ps & """ -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & here & "\stop-dsh.ps1""", 0, False
