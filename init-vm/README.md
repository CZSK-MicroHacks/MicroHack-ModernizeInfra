# Init-VM: On-Premises Environment Simulator

This directory contains Azure CLI scripts and PowerShell configurations to deploy a Windows Azure VM that simulates an on-premises environment. This VM serves as the starting point for the Migrate and Modernize hackathon, hosting a legacy application with two linked SQL Server instances.

## Overview

The init-vm setup creates:
- **Windows Server 2022 Azure VM** - Simulates on-premises infrastructure
- **Azure Storage Account** - Hosts installation scripts for automated deployment with SAS token security
- **SQL Server 2022 with 2 Instances** - CustomerDB and OrderDB instances with linked server configuration
- **ASP.NET Core Application** - The legacy application running on the VM
- **Custom Script Extension** - Automated installation and configuration without RDP

## Architecture

```
                    ┌────────────────────────────┐
                    │  Azure Storage Account     │
                    │  (Blob Container: scripts) │
                    │  - SAS Token Authentication │
                    │  - setup-all.ps1          │
                    │  - install-sql-server.ps1 │
                    │  - setup-databases.ps1    │
                    │  - setup-linked-servers.ps1│
                    │  - deploy-application.ps1 │
                    └────────┬───────────────────┘
                             │ Download Scripts
                             │ (Secure SAS Token Access)
                             ▼
┌─────────────────────────────────────────────────────────┐
│         Windows Server 2022 Azure VM (On-Prem Sim)     │
│         Custom Script Extension runs automatically       │
│                                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │         ASP.NET Core Application                │  │
│  │              (Port 8080)                        │  │
│  └───────────────┬────────┬────────────────────────┘  │
│                  │        │                            │
│  ┌───────────────▼──────┐ │                           │
│  │ SQL Server Instance 1│ │                           │
│  │    (Port 1433)       │ │                           │
│  │                      │ │                           │
│  │    CustomerDB        │ │                           │
│  │    - Customers Table │ │                           │
│  │    - Linked Server ──┼─┘                           │
│  └──────────────────────┘                             │
│                  │                                     │
│  ┌───────────────▼──────┐                            │
│  │ SQL Server Instance 2│                            │
│  │    (Port 1434)       │                            │
│  │                      │                            │
│  │      OrderDB         │                            │
│  │    - Orders Table    │                            │
│  └──────────────────────┘                            │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

Before running the deployment scripts, ensure you have:

1. **Azure CLI** installed and configured
   ```bash
   az --version
   az login
   ```

2. **Active Azure Subscription** with appropriate permissions to create:
   - Virtual Machines
   - Network Security Groups
   - Public IP addresses
   - Virtual Networks

3. **Resource Group** (will be created if it doesn't exist)

4. **SSH Key or Password** for VM access (script will prompt)

## Quick Start

### Step 1: Deploy the Azure VM

```bash
cd init-vm
chmod +x deploy-vm.sh
./deploy-vm.sh
```

This script will:
- Create a resource group (if it doesn't exist)
- Deploy a Windows Server 2022 VM
- Configure network security rules (RDP, HTTP, SQL Server ports)
- Create an Azure Storage Account for hosting installation scripts
- Upload PowerShell scripts to Blob Storage with secure SAS token access
- Install Custom Script Extension to automatically run setup scripts

**Parameters you'll be prompted for:**
- Resource Group Name (default: rg-modernize-hackathon)
- Location (default: eastus)
- VM Name (default: vm-onprem-simulator)
- Admin Username
- Admin Password (must meet complexity requirements)

### Step 2: Automated Setup Process

**No RDP connection required!** The VM automatically configures itself using the Custom Script Extension.

The VM will automatically:
1. Download installation scripts from Azure Blob Storage
2. Install SQL Server 2022 Developer Edition
3. Configure two SQL Server instances (ports 1433 and 1434)
4. Create CustomerDB and OrderDB databases with sample data
5. Set up linked server configuration
6. Install .NET 10 SDK and Runtime
7. Download and deploy the ASP.NET Core application
8. Start the application on port 8080

**This process takes approximately 20-30 minutes and requires no manual intervention.**

Monitor the deployment:
```bash
# Check VM provisioning state
az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --query "provisioningState"

# Check extension status
az vm extension list --resource-group rg-modernize-hackathon --vm-name vm-onprem-simulator --query "[].{Name:name, State:provisioningState}"
```

### Step 3: Access the Application

Once deployment is complete, get the VM's public IP:

```bash
az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --show-details --query "publicIps" -o tsv
```

Access the application:
- **Application URL**: `http://<VM-PUBLIC-IP>:8080`
- **RDP Access**: `<VM-PUBLIC-IP>:3389`

## Scripts Overview

### 1. `deploy-vm.sh`
Main deployment script using Azure CLI to:
- Create resource group
- Deploy Windows Server 2022 VM
- Configure networking and security
- Create Azure Storage Account for hosting scripts
- Upload PowerShell scripts to Blob Storage with private access and SAS token authentication
- Install Custom Script Extension to automatically execute setup scripts

### 2. `scripts/install-sql-server.ps1`
PowerShell script (downloaded and executed automatically via VM extension) to:
- Download SQL Server 2022 Developer Edition
- Install default instance (port 1433)
- Install named instance MSSQL2 (port 1434)
- Configure Windows Firewall rules
- Enable SQL Server authentication

### 3. `scripts/setup-databases.ps1`
PowerShell script to:
- Create CustomerDB database on default instance
- Create OrderDB database on named instance
- Create Customers and Orders tables
- Insert sample data

### 4. `scripts/setup-linked-servers.ps1`
PowerShell script to:
- Configure linked server from default instance to MSSQL2
- Test linked server connectivity
- Create cross-database view (vw_CustomerOrders)

### 5. `scripts/deploy-application.ps1`
PowerShell script to:
- Install .NET 10 SDK and Runtime
- Download the application binaries
- Configure connection strings
- Install as Windows Service or run as console app
- Configure Windows Firewall for port 8080

## Manual Steps (For Learning)

If you prefer to understand each step, follow the detailed manual deployment guide in [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md).

## Testing the Setup

### Test SQL Server Instances

RDP into the VM and run:

```powershell
# Test default instance (port 1433)
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "SELECT @@SERVERNAME, @@VERSION"

# Test named instance (port 1434)
sqlcmd -S localhost,1434 -U sa -P YourStrongPass123! -Q "SELECT @@SERVERNAME, @@VERSION"
```

### Test Linked Servers

```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "EXEC sp_testlinkedserver 'MSSQL2_LINK'"
```

### Test Cross-Database Query

```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "USE CustomerDB; SELECT * FROM vw_CustomerOrders"
```

### Test Application APIs

From your local machine or within the VM:

```bash
# Get all customers
curl http://<VM-PUBLIC-IP>:8080/api/customers

# Get all orders
curl http://<VM-PUBLIC-IP>:8080/api/orders

# Create a new customer
curl -X POST http://<VM-PUBLIC-IP>:8080/api/customers \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

## Troubleshooting

### VM Extension Failures

Check extension logs on the VM:
```
C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\
```

### SQL Server Connection Issues

1. Verify SQL Server services are running:
   ```powershell
   Get-Service MSSQLSERVER, MSSQL$MSSQL2
   ```

2. Check firewall rules:
   ```powershell
   Get-NetFirewallRule -DisplayName "*SQL*"
   ```

3. Test local connectivity:
   ```powershell
   Test-NetConnection localhost -Port 1433
   Test-NetConnection localhost -Port 1434
   ```

### Application Not Starting

1. Check .NET installation:
   ```powershell
   dotnet --version
   ```

2. Review application logs (if running as service):
   ```powershell
   Get-EventLog -LogName Application -Source "ModernizeInfraApp" -Newest 50
   ```

## Cleanup

To remove all resources:

```bash
az group delete --name rg-modernize-hackathon --yes --no-wait
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **This is a development/hackathon environment** - Not suitable for production
2. **Default passwords are used** - Change all passwords for any non-hackathon use
3. **Public IP with open ports** - Only use for temporary hackathon scenarios
4. **SQL Server Developer Edition** - Licensed for dev/test only
5. **No SSL/TLS** - Application uses HTTP (not HTTPS)

For a production-ready setup:
- Use Azure Key Vault for secrets
- Implement proper authentication/authorization
- Use private endpoints
- Enable SSL/TLS
- Use managed identities
- Implement proper network segmentation
- Enable audit logging

## Cost Estimation

Approximate Azure costs (East US region):
- **VM (Standard_D4s_v3)**: ~$0.192/hour (~$140/month)
- **Managed Disk (128 GB Premium)**: ~$25/month
- **Public IP**: ~$3.65/month
- **Bandwidth**: Variable based on usage

**Estimated total**: ~$170/month (when running 24/7)

**Cost-saving tips for hackathon:**
- Deallocate VM when not in use: `az vm deallocate`
- Use spot instances for even lower costs
- Delete resources immediately after hackathon

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs in the VM
3. Refer to [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md) for detailed steps
4. Contact the hackathon organizers

## License

This setup is for educational purposes as part of the CZ/SK MicroHack program.
