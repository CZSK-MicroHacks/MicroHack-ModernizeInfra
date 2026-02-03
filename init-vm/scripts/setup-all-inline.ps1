#
# Consolidated Setup Script - All-in-one installation
# This script contains all the setup logic inline without external dependencies
#

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Consolidated Setup Script - On-Premises Environment" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Check if running in non-interactive mode
$isNonInteractive = [Environment]::UserInteractive -eq $false -or $env:AUTOMATION_MODE -eq 'true'
Write-Host "Running in automated mode" -ForegroundColor Green

# Configuration
$SqlPassword = "YourStrongPass123!"
$AppFolder = "C:\Apps\ModernizeInfraApp"
$AppPort = 8080
$logFile = "C:\Temp\setup-log.txt"
New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

$startTime = Get-Date
Write-Log "Consolidated setup started"

#==========================================
# STEP 1: Install SQL Server
#==========================================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  STEP 1: SQL Server 2022 Installation" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Log "Starting SQL Server installation"

$DownloadFolder = "C:\Temp\SQLServer"
$SqlSetupPath = "$DownloadFolder\SQL2022-SSEI-Dev.exe"
$SqlMediaPath = "$DownloadFolder\SQLMedia"

Write-Host "Creating download folder..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $DownloadFolder | Out-Null
New-Item -ItemType Directory -Force -Path $SqlMediaPath | Out-Null

Write-Host "Downloading SQL Server 2022 Developer Edition..." -ForegroundColor Yellow
$SqlDownloadUrl = "https://go.microsoft.com/fwlink/p/?linkid=2215158"
Invoke-WebRequest -Uri $SqlDownloadUrl -OutFile $SqlSetupPath
Write-Host "✓ Downloaded SQL Server installer" -ForegroundColor Green

Write-Host "Downloading SQL Server media files..." -ForegroundColor Yellow
Start-Process -FilePath $SqlSetupPath -ArgumentList "/Action=Download", "/MediaPath=$SqlMediaPath", "/MediaType=Core", "/Quiet" -Wait
Write-Host "✓ Downloaded SQL Server media" -ForegroundColor Green

$SetupExe = Get-ChildItem -Path $SqlMediaPath -Recurse -Filter "setup.exe" | Select-Object -First 1

if ($null -eq $SetupExe) {
    Write-Host "Error: Could not find setup.exe in downloaded media" -ForegroundColor Red
    exit 1
}

Write-Host "Found setup.exe at: $($SetupExe.FullName)" -ForegroundColor Green

# Install Default Instance (MSSQLSERVER) on port 1433
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

Write-Host "Waiting for SQL Server services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Configure TCP/IP
Write-Host "Configuring TCP/IP for default instance..." -ForegroundColor Yellow

$sqlPsModule = Get-Module -ListAvailable -Name SqlServer | Select-Object -First 1
if ($null -eq $sqlPsModule) {
    Write-Host "Installing SqlServer PowerShell module..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name SqlServer -Force -AllowClobber
}
Import-Module SqlServer -ErrorAction SilentlyContinue

$wmi1 = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
$uri1 = "ManagedComputer[@Name='$env:COMPUTERNAME']/ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']"
$tcp1 = $wmi1.GetSmoObject($uri1)
$tcp1.IsEnabled = $true
$tcp1.Alter()

$ipAll1 = $tcp1.IPAddresses | Where-Object { $_.Name -eq "IPAll" }
$ipAll1.IPAddressProperties["TcpPort"].Value = "1433"
$ipAll1.IPAddressProperties["TcpDynamicPorts"].Value = ""
$tcp1.Alter()
Write-Host "✓ TCP/IP configured for default instance (port 1433)" -ForegroundColor Green

Write-Host "Configuring TCP/IP for named instance..." -ForegroundColor Yellow
$uri2 = "ManagedComputer[@Name='$env:COMPUTERNAME']/ServerInstance[@Name='MSSQL2']/ServerProtocol[@Name='Tcp']"
$tcp2 = $wmi1.GetSmoObject($uri2)
$tcp2.IsEnabled = $true
$tcp2.Alter()

$ipAll2 = $tcp2.IPAddresses | Where-Object { $_.Name -eq "IPAll" }
$ipAll2.IPAddressProperties["TcpPort"].Value = "1434"
$ipAll2.IPAddressProperties["TcpDynamicPorts"].Value = ""
$tcp2.Alter()
Write-Host "✓ TCP/IP configured for named instance (port 1434)" -ForegroundColor Green

Write-Host "Restarting SQL Server services..." -ForegroundColor Yellow
Restart-Service -Name "MSSQLSERVER" -Force
Restart-Service -Name "MSSQL`$MSSQL2" -Force
Restart-Service -Name "SQLBrowser" -Force
Start-Sleep -Seconds 10
Write-Host "✓ Services restarted" -ForegroundColor Green

# Configure Firewall
Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "SQL Server Default Instance" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "SQL Server Named Instance MSSQL2" -Direction Inbound -Protocol TCP -LocalPort 1434 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "SQL Server Browser" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action Allow -ErrorAction SilentlyContinue
Write-Host "✓ Firewall rules created" -ForegroundColor Green

Write-Log "SQL Server installation completed"

#==========================================
# STEP 2: Setup Databases
#==========================================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  STEP 2: Database Setup" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Log "Starting database setup"

$SqlCmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"

# Create CustomerDB
Write-Host "Creating CustomerDB on default instance..." -ForegroundColor Yellow

$CustomerDbScript = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'CustomerDB')
BEGIN
    CREATE DATABASE CustomerDB;
    PRINT 'CustomerDB database created';
END
ELSE
BEGIN
    PRINT 'CustomerDB database already exists';
END
GO

USE CustomerDB;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Customers')
BEGIN
    CREATE TABLE Customers (
        CustomerId INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(200) NOT NULL,
        Email NVARCHAR(200) NOT NULL,
        CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE()
    );
    PRINT 'Customers table created';
END
ELSE
BEGIN
    PRINT 'Customers table already exists';
END
GO

IF NOT EXISTS (SELECT * FROM Customers)
BEGIN
    INSERT INTO Customers (Name, Email, CreatedDate) VALUES
        ('John Smith', 'john.smith@example.com', GETDATE()),
        ('Jane Doe', 'jane.doe@example.com', GETDATE()),
        ('Bob Johnson', 'bob.johnson@example.com', GETDATE()),
        ('Alice Williams', 'alice.williams@example.com', GETDATE()),
        ('Charlie Brown', 'charlie.brown@example.com', GETDATE());
    PRINT 'Sample customers inserted';
END
ELSE
BEGIN
    PRINT 'Sample customers already exist';
END
GO

SELECT * FROM Customers;
GO
"@

$CustomerDbFile = "$env:TEMP\setup-customerdb.sql"
$CustomerDbScript | Out-File -FilePath $CustomerDbFile -Encoding ASCII
& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i $CustomerDbFile -C
Write-Host "✓ CustomerDB created and populated" -ForegroundColor Green

# Create OrderDB
Write-Host "Creating OrderDB on named instance..." -ForegroundColor Yellow

$OrderDbScript = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'OrderDB')
BEGIN
    CREATE DATABASE OrderDB;
    PRINT 'OrderDB database created';
END
ELSE
BEGIN
    PRINT 'OrderDB database already exists';
END
GO

USE OrderDB;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Orders')
BEGIN
    CREATE TABLE Orders (
        OrderId INT PRIMARY KEY IDENTITY(1,1),
        CustomerId INT NOT NULL,
        ProductName NVARCHAR(200) NOT NULL,
        Amount DECIMAL(18,2) NOT NULL,
        OrderDate DATETIME2 NOT NULL DEFAULT GETDATE()
    );
    PRINT 'Orders table created';
END
ELSE
BEGIN
    PRINT 'Orders table already exists';
END
GO

IF NOT EXISTS (SELECT * FROM Orders)
BEGIN
    INSERT INTO Orders (CustomerId, ProductName, Amount, OrderDate) VALUES
        (1, 'Laptop', 999.99, GETDATE()),
        (1, 'Mouse', 29.99, GETDATE()),
        (2, 'Keyboard', 79.99, GETDATE()),
        (3, 'Monitor', 299.99, GETDATE()),
        (4, 'Headphones', 149.99, GETDATE()),
        (5, 'Webcam', 89.99, GETDATE()),
        (2, 'USB Cable', 12.99, GETDATE()),
        (3, 'Desk Lamp', 45.99, GETDATE());
    PRINT 'Sample orders inserted';
END
ELSE
BEGIN
    PRINT 'Sample orders already exist';
END
GO

SELECT * FROM Orders;
GO
"@

$OrderDbFile = "$env:TEMP\setup-orderdb.sql"
$OrderDbScript | Out-File -FilePath $OrderDbFile -Encoding ASCII
& $SqlCmdPath -S "localhost,1434" -U sa -P $SqlPassword -i $OrderDbFile -C
Write-Host "✓ OrderDB created and populated" -ForegroundColor Green

Write-Log "Database setup completed"

#==========================================
# STEP 3: Setup Linked Servers
#==========================================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  STEP 3: Linked Server Configuration" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Log "Starting linked server configuration"

Write-Host "Setting up linked server from default instance to MSSQL2..." -ForegroundColor Yellow

$LinkedServerScript = @"
USE master;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

IF EXISTS(SELECT * FROM sys.servers WHERE name = 'MSSQL2_LINK')
BEGIN
    EXEC sp_dropserver 'MSSQL2_LINK', 'droplogins';
    PRINT 'Existing linked server dropped';
END
GO

EXEC sp_addlinkedserver 
    @server = 'MSSQL2_LINK',
    @srvproduct = '',
    @provider = 'MSOLEDBSQL',
    @datasrc = 'localhost,1434';
GO

PRINT 'Linked server created';
GO

EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'MSSQL2_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sa',
    @rmtpassword = '$SqlPassword';
GO

PRINT 'Login mapping configured';
GO

PRINT 'Testing linked server connection...';
EXEC sp_testlinkedserver 'MSSQL2_LINK';
GO

PRINT 'Linked server test successful!';
GO

SELECT * FROM MSSQL2_LINK.OrderDB.sys.tables WHERE name = 'Orders';
GO

PRINT 'Successfully verified access to OrderDB on linked server';
GO
"@

$LinkedServerFile = "$env:TEMP\setup-linked-server.sql"
$LinkedServerScript | Out-File -FilePath $LinkedServerFile -Encoding ASCII
& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i $LinkedServerFile -C
Write-Host "✓ Linked server configured" -ForegroundColor Green

# Create cross-database view
Write-Host "Creating cross-database view..." -ForegroundColor Yellow

$ViewScript = @"
USE CustomerDB;
GO

IF OBJECT_ID('dbo.vw_CustomerOrders', 'V') IS NOT NULL
BEGIN
    DROP VIEW dbo.vw_CustomerOrders;
    PRINT 'Existing view dropped';
END
GO

CREATE VIEW dbo.vw_CustomerOrders
AS
SELECT 
    c.CustomerId,
    c.Name,
    c.Email,
    c.CreatedDate,
    o.OrderId,
    o.ProductName,
    o.Amount,
    o.OrderDate
FROM 
    CustomerDB.dbo.Customers c
    LEFT JOIN MSSQL2_LINK.OrderDB.dbo.Orders o ON c.CustomerId = o.CustomerId;
GO

PRINT 'Cross-database view created successfully!';
GO

PRINT 'Testing cross-database view...';
SELECT TOP 5 * FROM vw_CustomerOrders ORDER BY OrderDate DESC;
GO

PRINT 'View test successful!';
GO
"@

$ViewFile = "$env:TEMP\setup-view.sql"
$ViewScript | Out-File -FilePath $ViewFile -Encoding ASCII
& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i $ViewFile -C
Write-Host "✓ Cross-database view created" -ForegroundColor Green

Write-Log "Linked server configuration completed"

#==========================================
# STEP 4: Deploy Application
#==========================================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  STEP 4: Application Deployment" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Log "Starting application deployment"

Write-Host "Creating application folder..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $AppFolder | Out-Null
Write-Host "✓ Application folder created: $AppFolder" -ForegroundColor Green

# Check for .NET SDK
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
    $installerPath = "$env:TEMP\dotnet-sdk-installer.exe"
    $installerUrl = "https://download.visualstudio.microsoft.com/download/pr/6224f00f-08da-4e7f-85b1-00d42c2bb3d3/b775de636b91e023574a0bbc291f705a/dotnet-sdk-9.0.100-win-x64.exe"
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Start-Process -FilePath $installerPath -ArgumentList "/quiet", "/norestart" -Wait
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host "✓ .NET SDK installed" -ForegroundColor Green
}

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
        "OrderDatabase" = "Server=localhost,1434;Database=OrderDB;User Id=sa;Password=$SqlPassword;TrustServerCertificate=True;Encrypt=False;"
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

# Configure Firewall
Write-Host "Configuring Windows Firewall for application..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "ASP.NET Core Application" -Direction Inbound -Protocol TCP -LocalPort $AppPort -Action Allow -ErrorAction SilentlyContinue
Write-Host "✓ Firewall rule created for port $AppPort" -ForegroundColor Green

# Clone and build application if Git is available
$gitInstalled = $false
try {
    $gitVersion = & git --version 2>$null
    if ($gitVersion) {
        Write-Host "✓ Git is installed: $gitVersion" -ForegroundColor Green
        $gitInstalled = $true
    }
} catch {
    $gitInstalled = $false
}

if ($gitInstalled) {
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
    } catch {
        Write-Host "Error building application: $_" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

Write-Log "Application deployment completed"

#==========================================
# COMPLETION
#==========================================
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Log "Consolidated setup completed in $($duration.TotalMinutes) minutes"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Environment Details:" -ForegroundColor Cyan
Write-Host "  SQL Server Instance 1: localhost,1433 (CustomerDB)" -ForegroundColor White
Write-Host "  SQL Server Instance 2: localhost,1434 (OrderDB)" -ForegroundColor White
Write-Host "  Linked Server: MSSQL2_LINK" -ForegroundColor White
Write-Host "  Application Folder: $AppFolder" -ForegroundColor White
Write-Host "  Application Port: $AppPort" -ForegroundColor White
Write-Host ""
Write-Host "Log file: $logFile" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Green
