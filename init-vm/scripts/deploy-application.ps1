#
# Deploy ASP.NET Core Application
# Installs .NET SDK, publishes the application, and sets it up to run
#

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Check if running in non-interactive mode (e.g., via Custom Script Extension)
$isNonInteractive = [Environment]::UserInteractive -eq $false -or $env:AUTOMATION_MODE -eq 'true'

Write-Host "=================================================="
Write-Host "  ASP.NET Core Application Deployment Script"
Write-Host "=================================================="
Write-Host ""

# Configuration
$SqlPassword = "YourStrongPass123!"
$AppFolder = "C:\Apps\ModernizeInfraApp"
$DotNetVersion = "10.0" # Using .NET 10 SDK for compatibility
$AppPort = 8080

# Create application folder
Write-Host "Creating application folder..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $AppFolder | Out-Null
Write-Host "✓ Application folder created: $AppFolder" -ForegroundColor Green

# Download and Install .NET SDK
Write-Host ""
Write-Host "Checking for .NET SDK..." -ForegroundColor Yellow

$dotnetInstalled = $false
try {
    $dotnetVersion = & dotnet --version 2>$null
    if ($dotnetVersion) {
        Write-Host "✓ .NET SDK already installed: $dotnetVersion" -ForegroundColor Green
        $dotnetInstalled = $true
    }
} catch {
    $dotnetInstalled = $false
}

if (-not $dotnetInstalled) {
    Write-Host "Installing .NET SDK..." -ForegroundColor Yellow
    
    # Download .NET SDK installer
    $installerPath = "$env:TEMP\dotnet-sdk-installer.exe"
    $installerUrl = "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.100/dotnet-sdk-10.0.100-win-x64.exe"
    
    Write-Host "Downloading .NET SDK installer..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    
    Write-Host "Installing .NET SDK (this may take a few minutes)..." -ForegroundColor Cyan
    Start-Process -FilePath $installerPath -ArgumentList "/quiet", "/norestart" -Wait
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Host "✓ .NET SDK installed" -ForegroundColor Green
}

# For this hackathon scenario, we'll create a simplified version of the application
# In a real scenario, you would clone from git or copy pre-built binaries
Write-Host ""
Write-Host "Setting up application files..." -ForegroundColor Yellow

# Create appsettings.json
$appSettings = @{
    "Logging" = @{
        "LogLevel" = @{
            "Default" = "Information"
            "Microsoft.AspNetCore" = "Warning"
        }
    }
    "AllowedHosts" = "*"
    "ConnectionStrings" = @{
        "CustomerDatabase" = "Server=localhost,1433;Database=CustomerDB;User Id=sa;Password=$SqlPassword;TrustServerCertificate=True;Encrypt=False;"
        "OrderDatabase" = "Server=localhost,1435;Database=OrderDB;User Id=sa;Password=$SqlPassword;TrustServerCertificate=True;Encrypt=False;"
    }
} | ConvertTo-Json -Depth 10

$appSettings | Out-File -FilePath "$AppFolder\appsettings.json" -Encoding UTF8

Write-Host "✓ Configuration file created" -ForegroundColor Green

# Create startup script
$startupScript = @"
@echo off
echo Starting ModernizeInfraApp...
cd /d "$AppFolder"

REM Check if published app exists
if exist "$AppFolder\ModernizeInfraApp.dll" (
    echo Running published application...
    dotnet ModernizeInfraApp.dll --urls http://0.0.0.0:$AppPort
) else (
    echo Application binaries not found!
    echo Please copy the published application to: $AppFolder
    echo Or clone and build from source
    pause
)
"@

$startupScript | Out-File -FilePath "$AppFolder\start-app.bat" -Encoding ASCII

Write-Host "✓ Startup script created" -ForegroundColor Green

# Configure Windows Firewall for application port
Write-Host ""
Write-Host "Configuring Windows Firewall for application..." -ForegroundColor Yellow

New-NetFirewallRule -DisplayName "ASP.NET Core Application" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort $AppPort `
    -Action Allow `
    -ErrorAction SilentlyContinue

Write-Host "✓ Firewall rule created for port $AppPort" -ForegroundColor Green

# Create instructions file
$instructions = @"
================================================
  ModernizeInfraApp Setup Instructions
================================================

IMPORTANT: Application binaries need to be deployed to this VM.

Option 1: Copy Pre-built Binaries
----------------------------------
1. Build the application on your development machine:
   cd ModernizeInfraApp
   dotnet publish -c Release -o ./publish

2. Copy the contents of ./publish to this VM at:
   $AppFolder

3. Run the application:
   cd $AppFolder
   start-app.bat

Option 2: Clone and Build on VM
--------------------------------
1. Install Git:
   winget install Git.Git

2. Clone the repository:
   cd C:\Apps
   git clone https://github.com/CZSK-MicroHacks/MicroHack-ModernizeInfra.git

3. Build and publish:
   cd MicroHack-ModernizeInfra\ModernizeInfraApp
   dotnet restore
   dotnet publish -c Release -o "$AppFolder"

4. Run the application:
   cd $AppFolder
   start-app.bat

Option 3: Deploy as Windows Service
------------------------------------
1. After copying/building the application, install as a service:
   sc create ModernizeInfraApp binPath= "C:\Program Files\dotnet\dotnet.exe $AppFolder\ModernizeInfraApp.dll" start= auto
   sc start ModernizeInfraApp

Configuration:
--------------
Connection strings are configured in:
$AppFolder\appsettings.json

Application URL:
----------------
http://localhost:$AppPort
http://<VM-Public-IP>:$AppPort

Test the application:
---------------------
curl http://localhost:$AppPort/api/customers
curl http://localhost:$AppPort/api/orders

================================================
"@

$instructions | Out-File -FilePath "$AppFolder\INSTRUCTIONS.txt" -Encoding UTF8

Write-Host "✓ Instructions file created" -ForegroundColor Green

# Check if we can access the repository to clone it
Write-Host ""
Write-Host "Checking if Git is available to clone application..." -ForegroundColor Yellow

$gitInstalled = $false
try {
    $gitVersion = & git --version 2>$null
    if ($gitVersion) {
        Write-Host "✓ Git is installed: $gitVersion" -ForegroundColor Green
        $gitInstalled = $true
    }
} catch {
    Write-Host "⚠ Git is not installed" -ForegroundColor Yellow
    $gitInstalled = $false
}

if ($gitInstalled) {
    if (-not $isNonInteractive) {
        Write-Host ""
        Write-Host "Would you like to clone and build the application now? (Y/N)" -ForegroundColor Cyan
        $response = Read-Host
        $shouldClone = $response -eq 'Y' -or $response -eq 'y'
    } else {
        # In automated mode, always clone and build
        Write-Host "Running in automated mode - cloning and building application" -ForegroundColor Green
        $shouldClone = $true
    }
    
    if ($shouldClone) {
        Write-Host "Cloning repository..." -ForegroundColor Yellow
        $repoPath = "C:\Apps\MicroHack-ModernizeInfra"
        
        if (Test-Path $repoPath) {
            Write-Host "Repository already exists at $repoPath" -ForegroundColor Yellow
        } else {
            git clone https://github.com/CZSK-MicroHacks/MicroHack-ModernizeInfra.git $repoPath
            Write-Host "✓ Repository cloned" -ForegroundColor Green
        }
        
        Write-Host "Building and publishing application..." -ForegroundColor Yellow
        Push-Location "$repoPath\ModernizeInfraApp"
        
        try {
            & dotnet restore
            & dotnet publish -c Release -o $AppFolder
            Write-Host "✓ Application built and published" -ForegroundColor Green
            
            Write-Host ""
            Write-Host "Starting application..." -ForegroundColor Yellow
            Write-Host "Navigate to http://localhost:$AppPort to access the application" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
            
            # Start the application
            & dotnet "$AppFolder\ModernizeInfraApp.dll" --urls "http://0.0.0.0:$AppPort"
        } catch {
            Write-Host "Error building application: $_" -ForegroundColor Red
        } finally {
            Pop-Location
        }
    }
}

Write-Host ""
Write-Host "=================================================="
Write-Host "  Application Deployment Setup Complete!"
Write-Host "=================================================="
Write-Host "Application Folder: $AppFolder"
Write-Host "Configuration: $AppFolder\appsettings.json"
Write-Host "Startup Script: $AppFolder\start-app.bat"
Write-Host "Instructions: $AppFolder\INSTRUCTIONS.txt"
Write-Host ""
Write-Host "Application Port: $AppPort"
Write-Host "Application URL: http://localhost:$AppPort"
Write-Host ""
Write-Host "Please read $AppFolder\INSTRUCTIONS.txt for next steps"
Write-Host "=================================================="
