<#
.SYNOPSIS
    Automated Git Commit and Push script for MeeParking repository.
.DESCRIPTION
    Periodically checks the repository for changes every X minutes (default: 15 mins, range 10-30 mins),
    stages all changed/new/deleted files, crafts an informative custom commit message, and pushes to remote.
.PARAMETER IntervalMinutes
    Interval between checks in minutes (default: 15).
.PARAMETER CustomMessagePrefix
    Custom commit message prefix.
.PARAMETER RunOnce
    If specified, runs a single sync check and exits immediately.
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
        # Check git status
        $status = git status --porcelain
        if (-not $status) {
            Write-SyncLog "ℹ️ No changes detected in workspace. Skipping commit."
            return
        }

        # Identify changed files summary
        $changedLines = $status -split "`r?`n" | Where-Object { $_ -match '\S' }
        $fileCount = $changedLines.Count
        
        $sampleFiles = @()
        foreach ($line in $changedLines) {
            $trimmed = $line.Substring(3).Trim()
            $fileName = Split-Path $trimmed -Leaf
            if ($fileName -and $sampleFiles.Count -lt 3) {
                $sampleFiles += $fileName
            }
        }
        $fileSummary = $sampleFiles -join ", "
        if ($fileCount -gt 3) {
            $fileSummary += " and $(($fileCount - 3)) more"
        }

        # Formulate custom commit message
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        if ($CustomMessagePrefix -and $CustomMessagePrefix.Trim().Length -gt 0) {
            $commitMsg = "$CustomMessagePrefix [$timestamp] - ($fileCount file(s): $fileSummary)"
        } else {
            $commitMsg = "chore(sync): auto-update at $timestamp ($fileCount file(s): $fileSummary)"
        }

        Write-SyncLog "📦 Changes detected ($fileCount files). Staging and committing..."
        git add -A
        
        $commitResult = git commit -m "$commitMsg"
        Write-SyncLog "✅ Committed: '$commitMsg'"

        Write-SyncLog "🚀 Pushing changes to remote 'origin main'..."
        $pushResult = git push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-SyncLog "🎉 Successfully pushed to GitHub!"
        } else {
            Write-SyncLog "⚠️ Push returned warnings/errors: $pushResult"
        }
    } catch {
        Write-SyncLog "❌ Error during sync: $($_.Exception.Message)"
    }
}

Write-SyncLog "=========================================="
Write-SyncLog "🚀 MeeParking Auto-Sync Service Started"
Write-SyncLog "⏱️ Interval: $IntervalMinutes minutes"
Write-SyncLog "📁 Repository: $RepoPath"
Write-SyncLog "=========================================="

if ($RunOnce) {
    Perform-Sync
    Write-SyncLog "🏁 Single run completed."
    exit 0
}

while ($true) {
    Perform-Sync
    Write-SyncLog "⏳ Sleeping for $IntervalMinutes minutes until next check..."
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}
