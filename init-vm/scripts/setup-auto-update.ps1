#
# Setup Scheduled Task for Automatic Application Updates
# This script creates a Windows scheduled task that checks for and deploys updates from GitHub
#

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=================================================="
Write-Host "  Setup Automatic Application Updates"
Write-Host "=================================================="
Write-Host ""

# Configuration
$TaskName = "ModernizeInfraApp-AutoUpdate"
$ScriptPath = "C:\Apps\ModernizeInfraApp\update-application.ps1"
$UpdateScriptUrl = "https://raw.githubusercontent.com/CZSK-MicroHacks/MicroHack-ModernizeInfra/main/init-vm/scripts/update-application.ps1"

# Download the update script if it doesn't exist
$scriptDir = Split-Path $ScriptPath -Parent
if (-not (Test-Path $scriptDir)) {
    Write-Host "Creating directory: $scriptDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
}

Write-Host "Downloading update script..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $UpdateScriptUrl -OutFile $ScriptPath -UseBasicParsing
    Write-Host "✓ Update script downloaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to download update script: $_" -ForegroundColor Red
    exit 1
}

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host ""
    Write-Host "Scheduled task '$TaskName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Do you want to recreate it? (Y/N)"
    
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "Removing existing task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "✓ Existing task removed" -ForegroundColor Green
    } else {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Creating scheduled task..." -ForegroundColor Yellow

# Create scheduled task action
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`" -NonInteractive"

# Create trigger - run daily at 2 AM
$trigger = New-ScheduledTaskTrigger -Daily -At 2AM

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

# Create principal (run as SYSTEM)
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Register the scheduled task
try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Automatically checks for and deploys application updates from GitHub" `
        -Force | Out-Null
    
    Write-Host "✓ Scheduled task created successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create scheduled task: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  Automatic Updates Configured!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Task Name: $TaskName" -ForegroundColor Cyan
Write-Host "Schedule: Daily at 2:00 AM" -ForegroundColor Cyan
Write-Host "Update Script: $ScriptPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "The application will automatically check for and deploy" -ForegroundColor Yellow
Write-Host "updates from GitHub every day at 2:00 AM." -ForegroundColor Yellow
Write-Host ""
Write-Host "To run an update manually:" -ForegroundColor Yellow
Write-Host "  PowerShell -ExecutionPolicy Bypass -File `"$ScriptPath`"" -ForegroundColor White
Write-Host ""
Write-Host "To run the scheduled task immediately:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName `"$TaskName`"" -ForegroundColor White
Write-Host ""
Write-Host "To view task details:" -ForegroundColor Yellow
Write-Host "  Get-ScheduledTask -TaskName `"$TaskName`"" -ForegroundColor White
Write-Host ""
Write-Host "To disable automatic updates:" -ForegroundColor Yellow
Write-Host "  Disable-ScheduledTask -TaskName `"$TaskName`"" -ForegroundColor White
Write-Host ""
Write-Host "To remove automatic updates:" -ForegroundColor Yellow
Write-Host "  Unregister-ScheduledTask -TaskName `"$TaskName`"" -ForegroundColor White
Write-Host "=================================================="
