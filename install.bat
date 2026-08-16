@echo off
setlocal EnableExtensions
title DeepSeek Harness Launcher - Installer

set "HERE=%~dp0"
set "SILENT="
if /i "%~1"=="/silent" set "SILENT=1"
set "TARGET=%~1"
if /i "%TARGET%"=="/silent" set "TARGET="
if "%TARGET%"=="" set "TARGET=%LOCALAPPDATA%\DSHLauncher"

echo Installing DeepSeek Harness launcher to:
echo   %TARGET%
echo.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%HERE%install.ps1" -Target "%TARGET%"
set "RC=%errorlevel%"
echo.
if "%RC%"=="0" (
  echo Install OK. Desktop shortcuts created.
) else (
  echo Install FAILED - see messages above.
)
echo.
if not defined SILENT pause
endlocal & exit /b %RC%
