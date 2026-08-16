@echo off
setlocal
title DeepSeek Harness Stopper

echo Stopping DeepSeek Harness service...
echo.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop-dsh.ps1"
set "RC=%errorlevel%"
echo.
if "%RC%"=="0" (
  echo Done. You can close this window now.
) else (
  echo Some processes could not be stopped - see the warnings above.
)
echo.
pause
endlocal & exit /b %RC%
