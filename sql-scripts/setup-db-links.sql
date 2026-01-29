-- Setup Database Links between two SQL Server instances
-- This script creates linked servers to enable cross-database queries

USE master;
GO

-- Enable distributed queries (required for linked servers)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- Check if linked server to sqlserver2 already exists, if so drop it
IF EXISTS(SELECT * FROM sys.servers WHERE name = 'SQLSERVER2_LINK')
BEGIN
    EXEC sp_dropserver 'SQLSERVER2_LINK', 'droplogins';
END
GO

-- Create linked server from sqlserver1 to sqlserver2
EXEC sp_addlinkedserver 
    @server = 'SQLSERVER2_LINK',
    @srvproduct = '',
    @provider = 'SQLNCLI',
    @datasrc = 'sqlserver2,1433';
GO

-- Configure login mapping for the linked server
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'SQLSERVER2_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sa',
    @rmtpassword = 'YourStrong@Passw0rd';
GO

-- Test the linked server connection
EXEC sp_testlinkedserver 'SQLSERVER2_LINK';
GO

PRINT 'Database link from sqlserver1 to sqlserver2 has been created successfully!';
GO

-- Create a view that demonstrates the database link by joining data from both databases
USE CustomerDB;
GO

IF OBJECT_ID('dbo.vw_CustomerOrders', 'V') IS NOT NULL
    DROP VIEW dbo.vw_CustomerOrders;
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
    LEFT JOIN SQLSERVER2_LINK.OrderDB.dbo.Orders o ON c.CustomerId = o.CustomerId;
GO

PRINT 'View vw_CustomerOrders created to demonstrate cross-database queries via linked server!';
GO
