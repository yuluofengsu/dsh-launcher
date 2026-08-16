@echo off
setlocal EnableExtensions
title DeepSeek Harness Launcher

set "URL=http://127.0.0.1:3080"
set "HERE=%~dp0"
set "STATE=%USERPROFILE%\.dsh\launcher"
set "PIDFILE=%STATE%\dsh-web.pid"
set "WAITURL=file:///%HERE:\=/%waiting.html"
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

rem ============================================================
rem  One-click DeepSeek Harness (DSH) launcher.
rem  - Service ready   -> opens the DSH app window instantly
rem  - Service booting -> shows a loading window that auto-
rem    switches to the DSH UI when ready
rem  - Not running     -> shows the loading window, starts the
rem    hidden service, window auto-switches when ready
rem  To stop the service use the desktop shortcut
rem  "Exit DeepSeek Harness" (dsh-stopper.bat).
rem ============================================================

rem ---- headless auto-start mode (logon auto-start shortcut) ----
if /i not "%~1"=="/autostart" goto chk
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%HERE%launch-dsh.ps1"
exit /b %errorlevel%
:chk

rem ---- self-update mode (dsh-launcher.bat /update) ----
if /i not "%~1"=="/update" goto chk
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%HERE%update-dsh.ps1"
echo.
pause
exit /b %errorlevel%
:chk

rem ---- self-check mode (dsh-launcher.bat /check) ----
if /i not "%~1"=="/check" goto main
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%HERE%check-dsh.ps1"
exit /b %errorlevel%
:main

rem ---- 1. is the service running? (pidfile alive) ----
set "RUNNING="
if not exist "%PIDFILE%" goto pidcheck
set /p OLDPID=<"%PIDFILE%"
set "OLDPID=%OLDPID: =%"
if not defined OLDPID goto pidcheck
tasklist /FI "PID eq %OLDPID%" 2>nul | findstr /R /C:"%OLDPID%" >nul 2>&1
if errorlevel 1 goto pidcheck
set "RUNNING=1"
:pidcheck

rem ---- 2. running: open the UI, or wait for it to finish booting ----
if not defined RUNNING goto fresh
call :isready
if "%CODE%"=="200" (
  echo DeepSeek Harness is ready - opening the UI...
  call :openapp "%URL%"
  goto done
)
rem not ready yet: is the port actually being listened? -> still booting
netstat -ano | findstr /R /C:":3080 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
  echo DeepSeek Harness is starting up - opening the loading window...
  call :openapp "%WAITURL%"
  goto done
)
rem pidfile is stale (pid alive but no server listening) -> start fresh
goto fresh

rem ---- 3. not running: loading window first, then start the service ----
:fresh
echo Starting DeepSeek Harness service, please wait...
call :openapp "%WAITURL%"
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%HERE%launch-dsh.ps1"
if errorlevel 1 (
  echo.
  echo FAILED to start! Check:
  echo   - log: %STATE%\dsh-web.err.log
  echo   - Node.js / DSH installed? (run: dsh-launcher.bat /check)
  pause
  exit /b 1
)

:done
endlocal
exit /b 0

rem ---- readiness probe: CODE=200 when the web UI responds ----
:isready
set "CODE="
if not exist "%SystemRoot%\System32\curl.exe" goto ready_done
for /f "delims=" %%c in ('%SystemRoot%\System32\curl.exe -s -o NUL -w %%{http_code} --connect-timeout 2 --max-time 4 %URL%') do set "CODE=%%c"
:ready_done
exit /b 0

rem ---- open the DSH UI in a dedicated app window ----
rem   --app:           no address bar / tabs, app-style window
rem   --user-data-dir: isolated profile, never mixes with the
rem                    normal browser; repeated clicks focus the
rem                    existing window instead of stacking new ones
rem   --no-first-run:  skip browser first-run screens
:openapp
set "TURL=%~1"
set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
set "EDGEPROFILE=%LOCALAPPDATA%\DeepSeekHarness\edge-app"
set "CHROMEPROFILE=%LOCALAPPDATA%\DeepSeekHarness\chrome-app"
if exist "%EDGE%" (
  start "" "%EDGE%" --app=%TURL% --user-data-dir="%EDGEPROFILE%" --no-first-run --no-default-browser-check --disable-features=msEdgeFirstRunExperience --start-maximized
  exit /b 0
)
if exist "%CHROME%" (
  start "" "%CHROME%" --app=%TURL% --user-data-dir="%CHROMEPROFILE%" --no-first-run --no-default-browser-check --start-maximized
  exit /b 0
)
start "" "%TURL%"
exit /b 0
