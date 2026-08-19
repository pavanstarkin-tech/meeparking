@echo off
setlocal
echo ========================================================
echo   MeeParking Auto-Sync Status
echo ========================================================
echo Checking running processes...
powershell -NoProfile -Command "$procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*auto_sync.ps1*' }; if ($procs) { Write-Host 'Status: RUNNING (' ($procs | Measure-Object).Count ' process(es) active)' -ForegroundColor Green; $procs | Select-Object ProcessId, CommandLine | Format-Table -AutoSize } else { Write-Host 'Status: STOPPED / NOT RUNNING' -ForegroundColor Yellow }"

echo --------------------------------------------------------
echo Recent Logs (Last 15 lines):
echo --------------------------------------------------------
if exist "%~dp0auto_sync.log" (
    powershell -NoProfile -Command "Get-Content -Path '%~dp0auto_sync.log' -Tail 15"
) else (
    echo No log file found yet.
)
echo ========================================================
pause
