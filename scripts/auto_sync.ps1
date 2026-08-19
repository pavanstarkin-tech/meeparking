<#
.SYNOPSIS
    Automated Git Commit and Push script for MeeParking repository.
.DESCRIPTION
    Periodically checks the repository for changes every X minutes (default: 15 mins, range 10-30 mins),
    stages all changed/new/deleted files, crafts an informative custom commit message, and pushes to remote.
#>
param (
    [int]$IntervalMinutes = 15,
    [string]$CustomMessagePrefix = "",
    [switch]$RunOnce = $false
)

$RepoPath = Split-Path -Parent $PSScriptRoot
Set-Location $RepoPath

$LogFile = Join-Path $PSScriptRoot "auto_sync.log"

function Write-SyncLog {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry -Encoding utf8
}

function Perform-Sync {
    try {
        $status = git status --porcelain
        if (-not $status) {
            Write-SyncLog "No changes detected in workspace. Skipping commit."
            return
        }

        $changedLines = $status -split "`r?`n" | Where-Object { $_ -match '\S' }
        $fileCount = $changedLines.Count
        
        $sampleFiles = @()
        foreach ($line in $changedLines) {
            $trimmed = $line.Substring(2).Trim()
            $fileName = Split-Path $trimmed -Leaf
            if ($fileName -and $sampleFiles.Count -lt 3) {
                $sampleFiles += $fileName
            }
        }
        $fileSummary = $sampleFiles -join ", "
        if ($fileCount -gt 3) {
            $fileSummary += " and " + ($fileCount - 3) + " more"
        }

        $dateStr = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        if ($CustomMessagePrefix -and $CustomMessagePrefix.Trim().Length -gt 0) {
            $commitMsg = $CustomMessagePrefix + " [" + $dateStr + "] - (" + $fileCount + " files: " + $fileSummary + ")"
        } else {
            $commitMsg = "chore(sync): auto-update at " + $dateStr + " (" + $fileCount + " files: " + $fileSummary + ")"
        }

        Write-SyncLog "Changes detected ($fileCount files). Staging and committing..."
        git add -A
        
        $commitOutput = git commit -m "$commitMsg" 2>&1
        Write-SyncLog "Committed: '$commitMsg'"

        Write-SyncLog "Pushing changes to remote 'origin main'..."
        $pushOutput = git push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-SyncLog "Successfully pushed to GitHub repository!"
        } else {
            Write-SyncLog "Push response: $pushOutput"
        }
    } catch {
        Write-SyncLog "Error during sync: $($_.Exception.Message)"
    }
}

Write-SyncLog "=========================================="
Write-SyncLog "MeeParking Auto-Sync Service Initialized"
Write-SyncLog "Interval: $IntervalMinutes minutes"
Write-SyncLog "Repository: $RepoPath"
Write-SyncLog "=========================================="

if ($RunOnce) {
    Perform-Sync
    Write-SyncLog "Single run completed."
    exit 0
}

while ($true) {
    Perform-Sync
    Write-SyncLog "Sleeping for $IntervalMinutes minutes until next check..."
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}
