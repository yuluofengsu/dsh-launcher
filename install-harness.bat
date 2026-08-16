@echo off
setlocal EnableExtensions
title DeepSeek Harness Installer

set "NOPAUSE="
if /i "%~1"=="/noif not defined NOPAUSE pause" set "NOPAUSE=1"

echo ============================================
echo   DeepSeek Harness - One-Click Installer
echo   Checks Node.js, installs missing pieces,
echo   installs DSH, self-checks, then launches.
echo ============================================
echo.

rem ========== 1. NODE.JS CHECK ==========
set "NODE_MAJOR="
for /f "tokens=1 delims=v." %%a in ('node --version 2^>nul') do set "NODE_MAJOR=%%a"
if not defined NODE_MAJOR goto node_missing
echo [1/6] Node.js found : v%NODE_MAJOR%.x
if %NODE_MAJOR% LSS 20 goto node_too_old
goto node_ok

:node_missing
echo [1/6] Node.js NOT found - installing the latest LTS...
goto node_install

:node_too_old
echo [1/6] Node.js v%NODE_MAJOR%.x is too old (need 20+) - upgrading...
goto node_install

:node_install
where winget >nul 2>&1
if errorlevel 1 goto no_winget
echo        Installing via winget (OpenJS.NodeJS.LTS)...
winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
winget upgrade --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
set "PATH=%PATH%;%ProgramFiles%\nodejs"
set "NODE_MAJOR="
for /f "tokens=1 delims=v." %%a in ('node --version 2^>nul') do set "NODE_MAJOR=%%a"
if not defined NODE_MAJOR goto winget_failed
if %NODE_MAJOR% LSS 20 goto winget_failed
echo        Node.js ready : v%NODE_MAJOR%.x
goto node_ok

:no_winget
echo        [ERROR] winget is not available on this system.
echo        Please install Node.js LTS manually from:
echo        https://nodejs.org
echo        then run this installer again.
if not defined NOPAUSE pause
exit /b 1

:winget_failed
echo        [ERROR] Could not install or upgrade Node.js.
echo        Please install Node.js LTS manually from:
echo        https://nodejs.org
echo        then run this installer again.
if not defined NOPAUSE pause
exit /b 1

:node_ok
echo.
echo [2/6] Checking npm...
npm --version >nul 2>&1
if errorlevel 1 (
  echo        [ERROR] npm not found. Reinstall Node.js and rerun.
  if not defined NOPAUSE pause
  exit /b 1
)
echo        npm OK :
npm --version

echo.
echo [3/6] Allowing required npm install scripts (one-time config)...
npm config set allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs --location=user
if errorlevel 1 (
  echo        [ERROR] npm config failed.
  if not defined NOPAUSE pause
  exit /b 1
)
echo        OK.

echo.
echo [4/6] Installing @deepseek-ai/dsh globally (a few minutes)...
call npm install -g @deepseek-ai/dsh
if errorlevel 1 (
  echo        [ERROR] Install failed. Check internet connection, then rerun.
  if not defined NOPAUSE pause
  exit /b 1
)

echo.
echo [5/6] Self-check...
set "DSH=%APPDATA%\npm\dsh.cmd"
if not exist "%DSH%" (
  echo        [ERROR] dsh not found at %DSH%
  if not defined NOPAUSE pause
  exit /b 1
)
echo        dsh path : %DSH%
call "%DSH%" --version
if errorlevel 1 (
  echo        [ERROR] dsh failed to run.
  if not defined NOPAUSE pause
  exit /b 1
)
node -e "var b=process.env.APPDATA+'/npm/node_modules/@deepseek-ai/dsh/node_modules/';for(var m of ['koffi','node-pty','protobufjs']){try{require(b+m);console.log('        '+m+': OK')}catch(e){console.log('        '+m+': FAIL')}}"
echo        Self-check PASSED.

echo.
echo ============================================
echo   *** INSTALL SUCCESS ***
echo ============================================
echo   dsh version:
call "%DSH%" --version
echo.

rem ========== 6. DESKTOP SHORTCUT + LAUNCH ==========
echo [6/6] Setting up desktop shortcut...
set "LDIR=%USERPROFILE%\DeepSeekHarness"
set "LAUNCHER=%LDIR%\dsh-launcher.bat"
if not exist "%LDIR%" mkdir "%LDIR%"

> "%LAUNCHER%" echo @echo off
>> "%LAUNCHER%" echo setlocal EnableExtensions
>> "%LAUNCHER%" echo set "URL=http://127.0.0.1:3080"
>> "%LAUNCHER%" echo set "DSH=%%APPDATA%%\npm\dsh.cmd"
>> "%LAUNCHER%" echo netstat -an ^| findstr /r /c:":3080 .*LISTENING" ^>nul 2^>^&1
>> "%LAUNCHER%" echo if not errorlevel 1 goto open
>> "%LAUNCHER%" echo start "DSH Server" /min cmd /k "%%DSH%% web"
>> "%LAUNCHER%" echo set /a n=0
>> "%LAUNCHER%" echo :wait
>> "%LAUNCHER%" echo timeout /t 1 /nobreak ^>nul
>> "%LAUNCHER%" echo netstat -an ^| findstr /r /c:":3080 .*LISTENING" ^>nul 2^>^&1
>> "%LAUNCHER%" echo if not errorlevel 1 goto open
>> "%LAUNCHER%" echo set /a n+=1
>> "%LAUNCHER%" echo if %%n%% lss 30 goto wait
>> "%LAUNCHER%" echo :open
>> "%LAUNCHER%" echo set "EDGE=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
>> "%LAUNCHER%" echo set "CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe"
>> "%LAUNCHER%" echo if exist "%%EDGE%%" ^( start "" "%%EDGE%%" --app=%%URL%% ^& goto done ^)
>> "%LAUNCHER%" echo if exist "%%CHROME%%" ^( start "" "%%CHROME%%" --app=%%URL%% ^& goto done ^)
>> "%LAUNCHER%" echo start "" "%%URL%%"
>> "%LAUNCHER%" echo :done
>> "%LAUNCHER%" echo endlocal
echo        Launcher written : %LAUNCHER%

set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" if exist "%USERPROFILE%\OneDrive\Desktop" set "DESKTOP=%USERPROFILE%\OneDrive\Desktop"
set "VBS=%TEMP%\dsh_mklnk.vbs"
> "%VBS%" echo Set ws = CreateObject("WScript.Shell")
>> "%VBS%" echo Set lnk = ws.CreateShortcut("%DESKTOP%\DeepSeek Harness.lnk")
>> "%VBS%" echo lnk.TargetPath = "%LAUNCHER%"
>> "%VBS%" echo lnk.WorkingDirectory = "%LDIR%"
>> "%VBS%" echo lnk.WindowStyle = 7
>> "%VBS%" echo lnk.IconLocation = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe,0"
>> "%VBS%" echo lnk.Save()
cscript //nologo "%VBS%" >nul 2>&1
del "%VBS%" >nul 2>&1
if exist "%DESKTOP%\DeepSeek Harness.lnk" (
  echo        Desktop shortcut : OK
) else (
  echo        Desktop shortcut : FAILED - create it manually
)

echo.
echo   Launching DeepSeek Harness...
call "%LAUNCHER%"

echo.
echo   Done! The app window should now be open.
echo   To start it later, double-click "DeepSeek Harness"
echo   on your desktop.
echo.
if not defined NOPAUSE pause
endlocal
