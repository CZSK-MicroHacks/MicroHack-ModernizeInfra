#
# Install SQL Server 2022 Developer Edition with Two Instances
# This script installs SQL Server with a default instance (port 1433) and a named instance (port 1434)
#

# Require Administrator
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=================================================="
Write-Host "  SQL Server 2022 Installation Script"
Write-Host "=================================================="
Write-Host ""

# Configuration
$SqlPassword = "YourStrongPass123!"
$DownloadFolder = "C:\Temp\SQLServer"
$SqlSetupPath = "$DownloadFolder\SQL2022-SSEI-Dev.exe"
$SqlMediaPath = "$DownloadFolder\SQLMedia"

# Create download folder
Write-Host "Creating download folder..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $DownloadFolder | Out-Null
New-Item -ItemType Directory -Force -Path $SqlMediaPath | Out-Null

# Download SQL Server 2022 Developer Edition
Write-Host "Downloading SQL Server 2022 Developer Edition..." -ForegroundColor Yellow
$SqlDownloadUrl = "https://go.microsoft.com/fwlink/p/?linkid=2215158"
Invoke-WebRequest -Uri $SqlDownloadUrl -OutFile $SqlSetupPath
Write-Host "✓ Downloaded SQL Server installer" -ForegroundColor Green

# Download media files
Write-Host "Downloading SQL Server media files..." -ForegroundColor Yellow
Start-Process -FilePath $SqlSetupPath -ArgumentList "/Action=Download", "/MediaPath=$SqlMediaPath", "/MediaType=Iso", "/Quiet" -Wait
Write-Host "✓ Downloaded SQL Server media" -ForegroundColor Green

# Find the ISO file in the downloaded media
$IsoFile = Get-ChildItem -Path $SqlMediaPath -Filter "*.iso" | Sort-Object Name | Select-Object -First 1

if ($null -eq $IsoFile) {
    Write-Host "Error: Could not find ISO file in downloaded media" -ForegroundColor Red
    exit 1
}

Write-Host "Found ISO at: $($IsoFile.FullName)" -ForegroundColor Green

# Mount the ISO
Write-Host "Mounting SQL Server ISO..." -ForegroundColor Yellow
try {
    $MountResult = Mount-DiskImage -ImagePath $IsoFile.FullName -PassThru -ErrorAction Stop
    $DriveLetter = ($MountResult | Get-Volume).DriveLetter
    
    if ($null -eq $DriveLetter) {
        throw "Failed to get drive letter from mounted ISO"
    }
} catch {
    Write-Host "Error: Failed to mount ISO: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "✓ ISO mounted to drive $DriveLetter`:" -ForegroundColor Green

# Find setup.exe in the mounted ISO
if (-not (Test-Path "$DriveLetter`:\setup.exe")) {
    Write-Host "Error: Could not find setup.exe in mounted ISO" -ForegroundColor Red
    Dismount-DiskImage -ImagePath $IsoFile.FullName
    exit 1
}

$SetupExe = Get-Item -Path "$DriveLetter`:\setup.exe"

Write-Host "Found setup.exe at: $($SetupExe.FullName)" -ForegroundColor Green

# Install Default Instance (MSSQLSERVER) on port 1433
Write-Host ""
Write-Host "Installing SQL Server Default Instance (Port 1433)..." -ForegroundColor Yellow

$ConfigFile1 = "$DownloadFolder\ConfigurationFile1.ini"
$ConfigContent1 = @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE
INSTANCENAME="MSSQLSERVER"
INSTANCEID="MSSQLSERVER"
SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"
SQLSYSADMINACCOUNTS="BUILTIN\Administrators"
AGTSVCACCOUNT="NT AUTHORITY\SYSTEM"
SECURITYMODE="SQL"
SAPWD="$SqlPassword"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCSTARTUPTYPE="Automatic"
TCPENABLED="1"
NPENABLED="0"
BROWSERSVCSTARTUPTYPE="Automatic"
IACCEPTSQLSERVERLICENSETERMS
QUIET="True"
"@

$ConfigContent1 | Out-File -FilePath $ConfigFile1 -Encoding ASCII

Start-Process -FilePath $SetupExe.FullName -ArgumentList "/ConfigurationFile=$ConfigFile1" -Wait -NoNewWindow

Write-Host "✓ Default instance installed" -ForegroundColor Green

# Install Named Instance (MSSQL2) on port 1434
Write-Host ""
Write-Host "Installing SQL Server Named Instance MSSQL2 (Port 1434)..." -ForegroundColor Yellow

$ConfigFile2 = "$DownloadFolder\ConfigurationFile2.ini"
$ConfigContent2 = @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE
INSTANCENAME="MSSQL2"
INSTANCEID="MSSQL2"
SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"
SQLSYSADMINACCOUNTS="BUILTIN\Administrators"
AGTSVCACCOUNT="NT AUTHORITY\SYSTEM"
SECURITYMODE="SQL"
SAPWD="$SqlPassword"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCSTARTUPTYPE="Automatic"
TCPENABLED="1"
NPENABLED="0"
BROWSERSVCSTARTUPTYPE="Automatic"
IACCEPTSQLSERVERLICENSETERMS
QUIET="True"
"@

$ConfigContent2 | Out-File -FilePath $ConfigFile2 -Encoding ASCII

Start-Process -FilePath $SetupExe.FullName -ArgumentList "/ConfigurationFile=$ConfigFile2" -Wait -NoNewWindow

Write-Host "✓ Named instance MSSQL2 installed" -ForegroundColor Green

# Dismount the ISO as installations are complete
Write-Host ""
Write-Host "Dismounting SQL Server ISO..." -ForegroundColor Yellow
try {
    Dismount-DiskImage -ImagePath $IsoFile.FullName
    Write-Host "✓ ISO dismounted" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to dismount ISO: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "You may need to manually dismount the ISO from drive $DriveLetter`:" -ForegroundColor Yellow
}

# Wait for services to start
Write-Host ""
Write-Host "Waiting for SQL Server services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Configure TCP/IP for default instance (port 1433)
Write-Host "Configuring TCP/IP for default instance..." -ForegroundColor Yellow

# Import SQL Server module
$sqlPsModule = Get-Module -ListAvailable -Name SqlServer | Select-Object -First 1
if ($null -eq $sqlPsModule) {
    Write-Host "Installing SqlServer PowerShell module..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name SqlServer -Force -AllowClobber
}
Import-Module SqlServer -ErrorAction SilentlyContinue

# Create ManagedComputer object once for use by both instances
# Note: Explicitly pass computer name to avoid "Attempt to retrieve data for object failed" errors
$wmi1 = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $env:COMPUTERNAME

# Enable TCP/IP and set port for default instance
try {
    $uri1 = "ManagedComputer[@Name='$env:COMPUTERNAME']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']"
    $tcp1 = $wmi1.GetSmoObject($uri1)
    $tcp1.IsEnabled = $true
    $tcp1.Alter()
    
    # Set static port 1433
    $ipAll1 = $tcp1.IPAddresses | Where-Object { $_.Name -eq "IPAll" }
    $ipAll1.IPAddressProperties["TcpPort"].Value = "1433"
    $ipAll1.IPAddressProperties["TcpDynamicPorts"].Value = ""
    $tcp1.Alter()
} catch {
    Write-Host "Error accessing ManagedComputer for default instance: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please verify SQL Server is installed and running." -ForegroundColor Yellow
    throw
}

Write-Host "✓ TCP/IP configured for default instance (port 1433)" -ForegroundColor Green

# Configure TCP/IP for named instance (port 1434)
Write-Host "Configuring TCP/IP for named instance..." -ForegroundColor Yellow

try {
    $uri2 = "ManagedComputer[@Name='$env:COMPUTERNAME']/ServerInstance[@Name='MSSQL2']/ServerProtocol[@Name='Tcp']"
    $tcp2 = $wmi1.GetSmoObject($uri2)
    $tcp2.IsEnabled = $true
    $tcp2.Alter()
    
    # Set static port 1434
    $ipAll2 = $tcp2.IPAddresses | Where-Object { $_.Name -eq "IPAll" }
    $ipAll2.IPAddressProperties["TcpPort"].Value = "1434"
    $ipAll2.IPAddressProperties["TcpDynamicPorts"].Value = ""
    $tcp2.Alter()
} catch {
    Write-Host "Error accessing ManagedComputer for named instance: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please verify SQL Server named instance MSSQL2 is installed and running." -ForegroundColor Yellow
    throw
}

Write-Host "✓ TCP/IP configured for named instance (port 1434)" -ForegroundColor Green

# Restart SQL Server services
Write-Host ""
Write-Host "Restarting SQL Server services..." -ForegroundColor Yellow
Restart-Service -Name "MSSQLSERVER" -Force
Restart-Service -Name "MSSQL`$MSSQL2" -Force
Restart-Service -Name "SQLBrowser" -Force
Start-Sleep -Seconds 10

Write-Host "✓ Services restarted" -ForegroundColor Green

# Configure Windows Firewall
Write-Host ""
Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow

New-NetFirewallRule -DisplayName "SQL Server Default Instance" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 1433 `
    -Action Allow `
    -ErrorAction SilentlyContinue

New-NetFirewallRule -DisplayName "SQL Server Named Instance MSSQL2" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 1434 `
    -Action Allow `
    -ErrorAction SilentlyContinue

New-NetFirewallRule -DisplayName "SQL Server Browser" `
    -Direction Inbound `
    -Protocol UDP `
    -LocalPort 1434 `
    -Action Allow `
    -ErrorAction SilentlyContinue

Write-Host "✓ Firewall rules created" -ForegroundColor Green

# Test connectivity
Write-Host ""
Write-Host "Testing SQL Server connectivity..." -ForegroundColor Yellow

$sqlcmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"
if (Test-Path $sqlcmdPath) {
    Write-Host "Testing default instance (port 1433)..." -ForegroundColor Cyan
    & $sqlcmdPath -S "localhost,1433" -U sa -P $SqlPassword -Q "SELECT @@VERSION" -C
    
    Write-Host "Testing named instance (port 1434)..." -ForegroundColor Cyan
    & $sqlcmdPath -S "localhost,1434" -U sa -P $SqlPassword -Q "SELECT @@VERSION" -C
} else {
    Write-Host "Warning: sqlcmd not found at expected path, skipping connectivity test" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=================================================="
Write-Host "  SQL Server Installation Complete!"
Write-Host "=================================================="
Write-Host "Default Instance: localhost,1433"
Write-Host "Named Instance:   localhost,1434"
Write-Host "SA Password:      $SqlPassword"
Write-Host ""
Write-Host "Services running:"
Get-Service | Where-Object { $_.Name -like "*SQL*" -and $_.Status -eq "Running" } | Format-Table -AutoSize
Write-Host "=================================================="

