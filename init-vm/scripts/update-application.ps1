#
# Automated Update Script - Downloads and deploys the latest application from GitHub
# This script can be run manually or scheduled as a task for automatic updates
#

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=================================================="
Write-Host "  ModernizeInfraApp - Automated Update Script"
Write-Host "=================================================="
Write-Host ""

# Configuration
$AppFolder = "C:\Apps\ModernizeInfraApp"
$TempFolder = "$env:TEMP\ModernizeInfraApp-Deploy"
$GitHubRepo = "CZSK-MicroHacks/MicroHack-ModernizeInfra"
$AppPort = 8080

# Check if application folder exists
if (-not (Test-Path $AppFolder)) {
    Write-Host "Creating application folder: $AppFolder" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $AppFolder -Force | Out-Null
}

# Function to get latest release
function Get-LatestRelease {
    Write-Host "Fetching latest release information from GitHub..." -ForegroundColor Yellow
    try {
        $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        return $release
    } catch {
        Write-Host "Failed to fetch latest release: $_" -ForegroundColor Red
        return $null
    }
}

# Function to download and extract application
function Deploy-Application {
    param(
        [string]$DownloadUrl,
        [string]$Version
    )
    
    Write-Host ""
    Write-Host "=== Deploying Version: $Version ===" -ForegroundColor Cyan
    
    # Create temp folder
    if (Test-Path $TempFolder) {
        Remove-Item -Path $TempFolder -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null
    
    $zipFile = Join-Path $TempFolder "app-binaries.zip"
    
    # Download application
    Write-Host "Downloading application..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipFile -UseBasicParsing
        Write-Host "✓ Download complete" -ForegroundColor Green
    } catch {
        Write-Host "✗ Download failed: $_" -ForegroundColor Red
        return $false
    }
    
    # Stop running application
    Write-Host "Stopping running application processes..." -ForegroundColor Yellow
    Get-Process -Name "dotnet" -ErrorAction SilentlyContinue | Where-Object { 
        $_.Path -like "*ModernizeInfraApp*"
    } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Backup current version
    $BackupFolder = "$AppFolder.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path $AppFolder) {
        Write-Host "Backing up current version to: $BackupFolder" -ForegroundColor Yellow
        Copy-Item -Path $AppFolder -Destination $BackupFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clear application folder (except backups and config)
    Write-Host "Clearing application folder..." -ForegroundColor Yellow
    Get-ChildItem -Path $AppFolder -Exclude "*.backup*", "appsettings.json" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    
    # Extract new version
    Write-Host "Extracting application..." -ForegroundColor Yellow
    try {
        Expand-Archive -Path $zipFile -DestinationPath $AppFolder -Force
        Write-Host "✓ Extraction complete" -ForegroundColor Green
    } catch {
        Write-Host "✗ Extraction failed: $_" -ForegroundColor Red
        
        # Restore backup
        if (Test-Path $BackupFolder) {
            Write-Host "Restoring backup..." -ForegroundColor Yellow
            Remove-Item -Path $AppFolder -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item -Path $BackupFolder -Destination $AppFolder -Recurse -Force
            Write-Host "✓ Backup restored" -ForegroundColor Green
        }
        return $false
    }
    
    # Clean up temp folder
    Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "✓ Deployment successful!" -ForegroundColor Green
    return $true
}

# Main execution
Write-Host "Checking for latest release..." -ForegroundColor Cyan
$release = Get-LatestRelease

if ($null -eq $release) {
    Write-Host ""
    Write-Host "Could not fetch release information from GitHub." -ForegroundColor Red
    Write-Host "Please check your internet connection and try again." -ForegroundColor Red
    exit 1
}

$version = $release.tag_name
$downloadUrl = ($release.assets | Where-Object { $_.name -eq "app-binaries.zip" }).browser_download_url

if ([string]::IsNullOrEmpty($downloadUrl)) {
    Write-Host ""
    Write-Host "No application binaries found in the latest release." -ForegroundColor Red
    Write-Host "Release: $version" -ForegroundColor Yellow
    Write-Host "Please ensure the GitHub Actions workflow has completed successfully." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Latest Release: $version" -ForegroundColor Cyan
Write-Host "Download URL: $downloadUrl" -ForegroundColor Gray
Write-Host ""

# Check if this version is already deployed
$versionFile = Join-Path $AppFolder "version.txt"
$currentVersion = ""
if (Test-Path $versionFile) {
    $currentVersion = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
    $currentVersion = $currentVersion.Trim()
}

if ($currentVersion -eq $version) {
    Write-Host "Application is already at the latest version: $version" -ForegroundColor Green
    Write-Host ""
    
    $response = Read-Host "Do you want to reinstall anyway? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "Update cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Deploy the application
$success = Deploy-Application -DownloadUrl $downloadUrl -Version $version

if ($success) {
    # Save version information
    $version | Out-File -FilePath $versionFile -Encoding UTF8
    
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "  Update Complete!" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Version: $version" -ForegroundColor Cyan
    Write-Host "Application Path: $AppFolder" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To start the application:" -ForegroundColor Yellow
    Write-Host "  cd $AppFolder" -ForegroundColor White
    Write-Host "  dotnet ModernizeInfraApp.dll --urls http://0.0.0.0:$AppPort" -ForegroundColor White
    Write-Host ""
    
    $response = Read-Host "Do you want to start the application now? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host ""
        Write-Host "Starting application on port $AppPort..." -ForegroundColor Yellow
        Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
        Write-Host ""
        
        Set-Location $AppFolder
        & dotnet ModernizeInfraApp.dll --urls "http://0.0.0.0:$AppPort"
    }
} else {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "  Update Failed!" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Red
    exit 1
}
