#
# Setup Databases and Tables
# Creates CustomerDB on default instance and OrderDB on named instance
#

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=================================================="
Write-Host "  Database Setup Script"
Write-Host "=================================================="
Write-Host ""

# Configuration
$SqlPassword = "YourStrongPass123!"
$SqlCmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"

# Check if sqlcmd exists
if (-not (Test-Path $SqlCmdPath)) {
    Write-Host "Error: sqlcmd not found at $SqlCmdPath" -ForegroundColor Red
    exit 1
}

# Create CustomerDB on default instance
Write-Host "Creating CustomerDB on default instance..." -ForegroundColor Yellow

$CustomerDbScript = @"
-- Create CustomerDB Database
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

-- Create Customers Table
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

-- Insert sample data
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

-- Display created data
SELECT * FROM Customers;
GO
"@

$CustomerDbFile = "$env:TEMP\setup-customerdb.sql"
$CustomerDbScript | Out-File -FilePath $CustomerDbFile -Encoding ASCII

& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i $CustomerDbFile -C

Write-Host "✓ CustomerDB created and populated" -ForegroundColor Green

# Create OrderDB on named instance
Write-Host ""
Write-Host "Creating OrderDB on named instance..." -ForegroundColor Yellow

$OrderDbScript = @"
-- Create OrderDB Database
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

-- Create Orders Table
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

-- Insert sample data
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

-- Display created data
SELECT * FROM Orders;
GO
"@

$OrderDbFile = "$env:TEMP\setup-orderdb.sql"
$OrderDbScript | Out-File -FilePath $OrderDbFile -Encoding ASCII

& $SqlCmdPath -S "localhost,1434" -U sa -P $SqlPassword -i $OrderDbFile -C

Write-Host "✓ OrderDB created and populated" -ForegroundColor Green

# Verify databases
Write-Host ""
Write-Host "Verifying databases..." -ForegroundColor Yellow

Write-Host "Databases on default instance:" -ForegroundColor Cyan
& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -Q "SELECT name FROM sys.databases WHERE name IN ('CustomerDB', 'OrderDB')" -C

Write-Host ""
Write-Host "Databases on named instance:" -ForegroundColor Cyan
& $SqlCmdPath -S "localhost,1434" -U sa -P $SqlPassword -Q "SELECT name FROM sys.databases WHERE name IN ('CustomerDB', 'OrderDB')" -C

Write-Host ""
Write-Host "=================================================="
Write-Host "  Database Setup Complete!"
Write-Host "=================================================="
Write-Host "CustomerDB: localhost,1433"
Write-Host "  - Customers table with sample data"
Write-Host ""
Write-Host "OrderDB: localhost,1434"
Write-Host "  - Orders table with sample data"
Write-Host "=================================================="
