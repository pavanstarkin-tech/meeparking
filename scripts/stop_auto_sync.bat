@echo off
setlocal
echo Stopping all auto_sync background processes...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*auto_sync.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Write-Host 'Stopped Auto-Sync Process ID:' $_.ProcessId }"
echo Done.
pause
