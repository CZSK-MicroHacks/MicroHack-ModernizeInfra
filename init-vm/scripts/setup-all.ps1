#
# Master Setup Script - Runs all installation steps in order
# This script automates the complete setup of the on-premises simulation environment
#

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Master Setup Script - On-Premises Environment Simulator" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "  1. Install SQL Server 2022 with two instances" -ForegroundColor Yellow
Write-Host "  2. Create and populate databases" -ForegroundColor Yellow
Write-Host "  3. Configure linked servers" -ForegroundColor Yellow
Write-Host "  4. Deploy the ASP.NET Core application" -ForegroundColor Yellow
Write-Host ""
Write-Host "This process will take approximately 20-30 minutes" -ForegroundColor Yellow
Write-Host ""

# Check if running in non-interactive mode (e.g., via Custom Script Extension)
$isNonInteractive = [Environment]::UserInteractive -eq $false -or $env:AUTOMATION_MODE -eq 'true'

if (-not $isNonInteractive) {
    $confirmation = Read-Host "Do you want to continue? (Y/N)"
    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Host "Setup cancelled" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Running in automated mode - proceeding without confirmation" -ForegroundColor Green
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = "C:\Temp\setup-log.txt"
New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

function Run-Step {
    param(
        [string]$StepName,
        [string]$ScriptPath
    )
    
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "  Step: $StepName" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Log "Starting: $StepName"
    
    try {
        & $ScriptPath
        Write-Log "Completed: $StepName"
        Write-Host ""
        Write-Host "✓ $StepName completed successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Log "ERROR in ${StepName}: $_"
        Write-Host ""
        Write-Host "✗ $StepName failed: $_" -ForegroundColor Red
        return $false
    }
}

# Start timestamp
$startTime = Get-Date
Write-Log "Master setup started"

# Step 1: Install SQL Server
$step1 = Run-Step -StepName "SQL Server Installation" -ScriptPath "$scriptPath\install-sql-server.ps1"
if (-not $step1) {
    Write-Host "Setup failed at SQL Server installation. Check logs at: $logFile" -ForegroundColor Red
    exit 1
}

# Step 2: Setup Databases
$step2 = Run-Step -StepName "Database Setup" -ScriptPath "$scriptPath\setup-databases.ps1"
if (-not $step2) {
    Write-Host "Setup failed at database setup. Check logs at: $logFile" -ForegroundColor Red
    exit 1
}

# Step 3: Setup Linked Servers
$step3 = Run-Step -StepName "Linked Server Configuration" -ScriptPath "$scriptPath\setup-linked-servers.ps1"
if (-not $step3) {
    Write-Host "Setup failed at linked server configuration. Check logs at: $logFile" -ForegroundColor Red
    exit 1
}

# Step 4: Deploy Application
$step4 = Run-Step -StepName "Application Deployment" -ScriptPath "$scriptPath\deploy-application.ps1"
if (-not $step4) {
    Write-Host "Setup failed at application deployment. Check logs at: $logFile" -ForegroundColor Red
    exit 1
}

# Calculate duration
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Log "Master setup completed in $($duration.TotalMinutes) minutes"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Environment Details:" -ForegroundColor Cyan
Write-Host "  SQL Server Instance 1: localhost,1433 (CustomerDB)" -ForegroundColor White
Write-Host "  SQL Server Instance 2: localhost,1434 (OrderDB)" -ForegroundColor White
Write-Host "  Linked Server: MSSQL2_LINK" -ForegroundColor White
Write-Host "  Application Folder: C:\Apps\ModernizeInfraApp" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Deploy application binaries to C:\Apps\ModernizeInfraApp" -ForegroundColor White
Write-Host "  2. Run: cd C:\Apps\ModernizeInfraApp" -ForegroundColor White
Write-Host "  3. Run: .\start-app.bat" -ForegroundColor White
Write-Host "  4. Access: http://localhost:8080" -ForegroundColor White
Write-Host ""
Write-Host "Log file: $logFile" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Green
