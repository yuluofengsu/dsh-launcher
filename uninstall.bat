@echo off
setlocal EnableExtensions
title DeepSeek Harness Launcher - Uninstaller

set "HERE=%~dp0"
set "SILENT="
if /i "%~1"=="/silent" set "SILENT=1"
set "TARGET=%~1"
if /i "%TARGET%"=="/silent" set "TARGET="
if "%TARGET%"=="" set "TARGET=%LOCALAPPDATA%\DSHLauncher"

echo Removing DeepSeek Harness launcher from:
echo   %TARGET%
echo.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%HERE%uninstall.ps1" -Target "%TARGET%"
echo.
if not defined SILENT pause
endlocal & exit /b 0
