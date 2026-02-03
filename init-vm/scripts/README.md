# Scripts Directory

This directory contains PowerShell scripts for setting up the on-premises simulation environment on the Windows VM.

## Scripts Overview

### 1. setup-all.ps1
**Master setup script** that orchestrates the entire installation process.

**Usage:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
.\setup-all.ps1
```

**What it does:**
- Runs all setup scripts in sequence
- Logs progress to C:\Temp\setup-log.txt
- Provides error handling and rollback information
- Total execution time: 20-30 minutes

### 2. install-sql-server.ps1
**SQL Server installation script** that installs two SQL Server instances.

**Usage:**
```powershell
.\install-sql-server.ps1
```

**What it does:**
- Downloads SQL Server 2022 Developer Edition
- Installs default instance (MSSQLSERVER) on port 1433
- Installs named instance (MSSQL2) on port 1435
- Configures TCP/IP for both instances
- Sets up Windows Firewall rules
- Enables SQL Server authentication
- Execution time: 15-20 minutes

**Configuration:**
- SA Password: `YourStrongPass123!`
- Download Path: `C:\Temp\SQLServer`
- Port 1433: Default instance
- Port 1435: Named instance MSSQL2

### 3. setup-databases.ps1
**Database creation script** that sets up databases and sample data.

**Usage:**
```powershell
.\setup-databases.ps1
```

**What it does:**
- Creates CustomerDB on default instance (port 1433)
- Creates OrderDB on named instance (port 1435)
- Creates Customers table in CustomerDB
- Creates Orders table in OrderDB
- Inserts sample data for testing
- Execution time: 2-3 minutes

**Sample Data:**
- 5 customers in CustomerDB
- 8 orders in OrderDB

### 4. setup-linked-servers.ps1
**Linked server configuration script** that enables cross-database queries.

**Usage:**
```powershell
.\setup-linked-servers.ps1
```

**What it does:**
- Enables distributed queries on default instance
- Creates linked server (MSSQL2_LINK) from default to named instance
- Configures authentication for linked server
- Tests linked server connectivity
- Creates cross-database view (vw_CustomerOrders)
- Execution time: 1-2 minutes

**Linked Server Details:**
- Name: MSSQL2_LINK
- Source: localhost,1433 (CustomerDB)
- Target: localhost,1435 (OrderDB)
- View: CustomerDB.dbo.vw_CustomerOrders

### 5. deploy-application.ps1
**Application deployment script** that sets up the ASP.NET Core application.

**Usage:**
```powershell
.\deploy-application.ps1
```

**What it does:**
- Checks for .NET SDK (installs if missing)
- Creates application folder (C:\Apps\ModernizeInfraApp)
- Configures connection strings
- Sets up Windows Firewall for port 8080
- Optionally clones and builds the application
- Creates startup scripts
- Execution time: 5-10 minutes

**Application Configuration:**
- Install Path: `C:\Apps\ModernizeInfraApp`
- Port: 8080
- Connection strings point to localhost,1433 and localhost,1435

## Execution Order

**IMPORTANT:** Scripts must be run in this order:

1. `install-sql-server.ps1` - First, install SQL Server
2. `setup-databases.ps1` - Then create databases
3. `setup-linked-servers.ps1` - Then configure linked servers
4. `deploy-application.ps1` - Finally, deploy the application

**OR** simply run `setup-all.ps1` which executes all scripts in the correct order.

## Requirements

- **Run as Administrator** - All scripts require administrative privileges
- **PowerShell 5.1+** - Included in Windows Server 2022
- **Internet Connection** - Required to download SQL Server and .NET SDK
- **Disk Space** - At least 20 GB free space
- **Memory** - 8 GB minimum (16 GB recommended)

## Common Issues and Solutions

### Issue: "Execution of scripts is disabled on this system"

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
```

### Issue: SQL Server installation fails

**Solution:**
- Ensure VM has enough resources (4 vCPUs, 16 GB RAM)
- Check Windows Updates aren't blocking installation
- Manually review logs at: `C:\Program Files\Microsoft SQL Server\*\Setup Bootstrap\Log`

### Issue: Cannot connect to SQL Server instances

**Solution:**
```powershell
# Verify services are running
Get-Service MSSQLSERVER, MSSQL$MSSQL2

# Restart if needed
Restart-Service MSSQLSERVER, MSSQL$MSSQL2

# Check firewall
Get-NetFirewallRule -DisplayName "*SQL*"
```

### Issue: Application build fails

**Solution:**
```powershell
# Verify .NET SDK installation
dotnet --version

# Reinstall if needed
winget install Microsoft.DotNet.SDK.9
```

## Logs and Diagnostics

### Setup Log
Location: `C:\Temp\setup-log.txt`

View recent entries:
```powershell
Get-Content C:\Temp\setup-log.txt -Tail 50
```

### SQL Server Logs
Location: `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Log\ERRORLOG`

View SQL Server errors:
```powershell
Get-Content "C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Log\ERRORLOG" -Tail 50
```

### Windows Event Logs
View application events:
```powershell
Get-EventLog -LogName Application -Newest 50 | Where-Object { $_.Source -like "*SQL*" }
```

## Testing Commands

### Test SQL Server Connectivity
```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "SELECT @@VERSION" -C
sqlcmd -S localhost,1435 -U sa -P YourStrongPass123! -Q "SELECT @@VERSION" -C
```

### Test Databases
```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "USE CustomerDB; SELECT COUNT(*) FROM Customers" -C
sqlcmd -S localhost,1435 -U sa -P YourStrongPass123! -Q "USE OrderDB; SELECT COUNT(*) FROM Orders" -C
```

### Test Linked Server
```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "EXEC sp_testlinkedserver 'MSSQL2_LINK'" -C
```

### Test Cross-Database View
```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "USE CustomerDB; SELECT * FROM vw_CustomerOrders" -C
```

### Test Application
```powershell
# Check if app is running
Test-NetConnection localhost -Port 8080

# Test API
Invoke-RestMethod -Uri "http://localhost:8080/api/customers"
Invoke-RestMethod -Uri "http://localhost:8080/api/orders"
```

## Customization

### Change SA Password

Edit the password in all scripts:
```powershell
$SqlPassword = "YourNewPassword123!"
```

### Change Application Port

Edit `deploy-application.ps1`:
```powershell
$AppPort = 9090  # Change from 8080
```

### Add More Sample Data

Edit `setup-databases.ps1` and add more INSERT statements.

## Security Notes

⚠️ **IMPORTANT:** These scripts are designed for development/hackathon environments only.

**For production use:**
- Use strong, unique passwords
- Store credentials in Azure Key Vault
- Use managed identities
- Enable SSL/TLS
- Implement proper network security
- Regular security updates

## Support

For issues with these scripts:
1. Check the logs (C:\Temp\setup-log.txt)
2. Review error messages carefully
3. Ensure all prerequisites are met
4. Run scripts one at a time to isolate issues
5. Check the troubleshooting section in DEPLOYMENT-GUIDE.md
