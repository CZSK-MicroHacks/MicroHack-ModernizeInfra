#
# Setup Linked Servers
# Creates a linked server from default instance to named instance
# and creates a cross-database view
#

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=================================================="
Write-Host "  Linked Server Setup Script"
Write-Host "=================================================="
Write-Host ""

# Configuration
$SqlPassword = "YourStrongPass123!"
$SqlCmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"
$ComputerName = $env:COMPUTERNAME

# Check if sqlcmd exists
if (-not (Test-Path $SqlCmdPath)) {
    Write-Host "Error: sqlcmd not found at $SqlCmdPath" -ForegroundColor Red
    exit 1
}

Write-Host "Setting up linked server from default instance to MSSQL2..." -ForegroundColor Yellow

$LinkedServerScript = @"
USE master;
GO

-- Enable distributed queries (required for linked servers)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- Check if linked server to MSSQL2 already exists, if so drop it
IF EXISTS(SELECT * FROM sys.servers WHERE name = 'MSSQL2_LINK')
BEGIN
    EXEC sp_dropserver 'MSSQL2_LINK', 'droplogins';
    PRINT 'Existing linked server dropped';
END
GO

-- Create linked server from default instance to MSSQL2 named instance
-- Using SQL Server Native Client provider
EXEC sp_addlinkedserver 
    @server = 'MSSQL2_LINK',
    @srvproduct = '',
    @provider = 'MSOLEDBSQL',
    @datasrc = 'localhost,1435';
GO

PRINT 'Linked server created';
GO

-- Configure login mapping for the linked server
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'MSSQL2_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sa',
    @rmtpassword = '$SqlPassword';
GO

PRINT 'Login mapping configured';
GO

-- Test the linked server connection
PRINT 'Testing linked server connection...';
EXEC sp_testlinkedserver 'MSSQL2_LINK';
GO

PRINT 'Linked server test successful!';
GO

-- Verify linked server can query OrderDB
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
Write-Host ""
Write-Host "Creating cross-database view..." -ForegroundColor Yellow

$ViewScript = @"
USE CustomerDB;
GO

-- Drop existing view if it exists
IF OBJECT_ID('dbo.vw_CustomerOrders', 'V') IS NOT NULL
BEGIN
    DROP VIEW dbo.vw_CustomerOrders;
    PRINT 'Existing view dropped';
END
GO

-- Create view that joins data from both databases via linked server
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

-- Test the view
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

# Verify setup
Write-Host ""
Write-Host "Verifying linked server configuration..." -ForegroundColor Yellow

$VerifyScript = @"
-- Show linked server configuration
EXEC sp_helpserver;
GO

-- Test query using the view
USE CustomerDB;
GO

SELECT 
    'Total Customers' as Metric,
    COUNT(*) as Count
FROM Customers;
GO

SELECT 
    'Total Orders' as Metric,
    COUNT(*) as Count
FROM MSSQL2_LINK.OrderDB.dbo.Orders;
GO

SELECT 
    'Customer-Order Pairs (via view)' as Metric,
    COUNT(*) as Count
FROM vw_CustomerOrders
WHERE OrderId IS NOT NULL;
GO
"@

$VerifyFile = "$env:TEMP\verify-setup.sql"
$VerifyScript | Out-File -FilePath $VerifyFile -Encoding ASCII

& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i $VerifyFile -C

Write-Host ""
Write-Host "=================================================="
Write-Host "  Linked Server Setup Complete!"
Write-Host "=================================================="
Write-Host "Linked Server Name: MSSQL2_LINK"
Write-Host "Source: localhost,1433 (CustomerDB)"
Write-Host "Target: localhost,1435 (OrderDB)"
Write-Host ""
Write-Host "Cross-Database View: CustomerDB.dbo.vw_CustomerOrders"
Write-Host ""
Write-Host "Test the setup with:"
Write-Host "  sqlcmd -S localhost,1433 -U sa -P $SqlPassword -Q ""USE CustomerDB; SELECT * FROM vw_CustomerOrders"""
Write-Host "=================================================="
