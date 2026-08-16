@echo off
setlocal
title DeepSeek Harness AutoStart Toggle
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0autostart.ps1"
echo.
pause
endlocal
