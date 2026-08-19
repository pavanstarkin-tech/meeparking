@echo off
setlocal
cd /d "%~dp0\.."

set INTERVAL=15
if not "%~1"=="" set INTERVAL=%1

set PREFIX=
if not "%~2"=="" set PREFIX=%~2

echo ========================================================
echo   MeeParking Auto Git Sync Background Service
echo ========================================================
echo Interval: %INTERVAL% minutes
echo Starting background task...

powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"\"%~dp0auto_sync.ps1\"\" -IntervalMinutes %INTERVAL% -CustomMessagePrefix \"\"%PREFIX%\"\"' -WindowStyle Hidden"

echo Auto-Sync is now running in the background!
echo Sync checks will occur every %INTERVAL% minutes.
echo Logs are saved to scripts\auto_sync.log
echo To stop, run scripts\stop_auto_sync.bat
echo ========================================================
pause
