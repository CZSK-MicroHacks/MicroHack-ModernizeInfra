# Quick Reference Guide

## Quick Commands

### Deployment

```bash
# Deploy VM
cd init-vm
./deploy-vm.sh

# Check VM status
az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --query "provisioningState"

# Get VM public IP
az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --show-details --query "publicIps" -o tsv
```

### On VM - Setup

```powershell
# Run automated setup
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
cd C:\Setup\scripts
.\setup-all.ps1

# Or run individual steps
.\install-sql-server.ps1
.\setup-databases.ps1
.\setup-linked-servers.ps1
.\deploy-application.ps1
```

### SQL Server Commands

```powershell
# Check SQL services
Get-Service | Where-Object { $_.Name -like "*SQL*" }

# Test default instance
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "SELECT @@VERSION" -C

# Test named instance
sqlcmd -S localhost,1434 -U sa -P YourStrongPass123! -Q "SELECT @@VERSION" -C

# Test linked server
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "EXEC sp_testlinkedserver 'MSSQL2_LINK'" -C

# Query cross-database view
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "USE CustomerDB; SELECT * FROM vw_CustomerOrders" -C
```

### Application Commands

```powershell
# Build and deploy from source
cd C:\Apps
git clone https://github.com/CZSK-MicroHacks/MicroHack-ModernizeInfra.git
cd MicroHack-ModernizeInfra\ModernizeInfraApp
dotnet restore
dotnet publish -c Release -o C:\Apps\ModernizeInfraApp

# Start application
cd C:\Apps\ModernizeInfraApp
dotnet ModernizeInfraApp.dll --urls "http://0.0.0.0:8080"

# Test application
Invoke-RestMethod -Uri "http://localhost:8080/api/customers"
Invoke-RestMethod -Uri "http://localhost:8080/api/orders"
```

### Testing APIs

```bash
# From external machine (replace <VM-IP>)
curl http://<VM-IP>:8080/api/customers
curl http://<VM-IP>:8080/api/orders

# Create customer
curl -X POST http://<VM-IP>:8080/api/customers \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'

# Create order
curl -X POST http://<VM-IP>:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId":1,"productName":"Test Product","amount":99.99}'
```

### Cleanup

```bash
# Stop VM (saves costs)
az vm deallocate --resource-group rg-modernize-hackathon --name vm-onprem-simulator

# Start VM
az vm start --resource-group rg-modernize-hackathon --name vm-onprem-simulator

# Delete all resources
az group delete --name rg-modernize-hackathon --yes --no-wait
```

## Default Configuration

| Component | Value |
|-----------|-------|
| Resource Group | rg-modernize-hackathon |
| VM Name | vm-onprem-simulator |
| VM Size | Standard_D4s_v3 |
| OS | Windows Server 2022 |
| SQL Instance 1 | localhost,1433 |
| SQL Instance 2 | localhost,1434 |
| SA Password | YourStrongPass123! |
| App Port | 8080 |
| Linked Server | MSSQL2_LINK |

## Ports

| Port | Service | Protocol |
|------|---------|----------|
| 3389 | RDP | TCP |
| 1433 | SQL Server (default) | TCP |
| 1434 | SQL Server (MSSQL2) | TCP |
| 8080 | Application | TCP |

## Connection Strings

```
# CustomerDB
Server=localhost,1433;Database=CustomerDB;User Id=sa;Password=YourStrongPass123!;TrustServerCertificate=True;Encrypt=False;

# OrderDB
Server=localhost,1434;Database=OrderDB;User Id=sa;Password=YourStrongPass123!;TrustServerCertificate=True;Encrypt=False;
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Can't connect to VM | Check NSG rules and public IP |
| SQL Server not starting | Verify VM has enough RAM (16GB recommended) |
| Application not accessible | Check firewall rules and app is running |
| Linked server fails | Verify both instances are running and password is correct |

## File Locations on VM

| Path | Description |
|------|-------------|
| C:\Apps\ModernizeInfraApp | Application files |
| C:\Setup\scripts | Setup scripts |
| C:\Temp\setup-log.txt | Setup log file |
| C:\Temp\SQLServer | SQL Server installation files |

## Useful Azure CLI Commands

```bash
# List all VMs
az vm list --resource-group rg-modernize-hackathon --output table

# Get VM details
az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator

# Check extension status
az vm extension list --resource-group rg-modernize-hackathon --vm-name vm-onprem-simulator --output table

# View VM boot diagnostics
az vm boot-diagnostics get-boot-log --resource-group rg-modernize-hackathon --name vm-onprem-simulator

# Resize VM
az vm resize --resource-group rg-modernize-hackathon --name vm-onprem-simulator --size Standard_D8s_v3
```
