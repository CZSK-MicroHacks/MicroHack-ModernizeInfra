# Init-VM: On-Premises Environment Simulator

This directory contains Azure CLI scripts and PowerShell configurations to deploy a Windows Azure VM that simulates an on-premises environment. This VM serves as the starting point for the Migrate and Modernize hackathon, hosting a legacy application with two linked SQL Server instances.

## Overview

The init-vm setup creates:
- **Windows Server 2022 Azure VM** - Simulates on-premises infrastructure (NO public IP)
- **Azure Bastion** - Secure RDP access without public IP
- **SQL Server 2022 with 2 Instances** - CustomerDB and OrderDB instances with linked server configuration
- **ASP.NET Core Application** - The legacy application running on the VM
- **Custom Script Extension** - Automated installation and configuration using scripts from GitHub
- **Entra ID Authentication** - Azure AD login enabled for VM access

## Security Features

✅ **VM has NO public IP address** - All access through Azure Bastion
✅ **Entra ID authentication enabled** - Use Azure AD credentials for VM access
✅ **Random generated password** - Strong password for local admin account
✅ **Scripts from version-controlled source** - Setup scripts are downloaded from the public GitHub repository, ensuring version control, transparency, and no secrets in scripts

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Azure Virtual Network                  │
│                         (10.0.0.0/16)                       │
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │           Azure Bastion Subnet                     │    │
│  │            (10.0.2.0/26)                          │    │
│  │   ┌─────────────────────────┐                     │    │
│  │   │    Azure Bastion        │                     │    │
│  │   │  (Secure RDP Access)    │                     │    │
│  │   └─────────────────────────┘                     │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │              VM Subnet (10.0.1.0/24)              │    │
│  │                                                    │    │
│  │   ┌─────────────────────────────────────────┐    │    │
│  │   │  Windows Server 2022 VM (No Public IP)  │    │    │
│  │   │  - Managed Identity Enabled             │    │    │
│  │   │  - Azure AD Login Extension             │    │    │
│  │   │                                          │    │    │
│  │   │  ┌─────────────────────────────────┐   │    │    │
│  │   │  │  ASP.NET Core Application       │   │    │    │
│  │   │  │       (Port 8080)               │   │    │    │
│  │   │  └────────┬──────────┬─────────────┘   │    │    │
│  │   │           │          │                  │    │    │
│  │   │  ┌────────▼────────┐ │                 │    │    │
│  │   │  │  SQL Instance 1 │ │                 │    │    │
│  │   │  │   (Port 1433)   │ │                 │    │    │
│  │   │  │   CustomerDB    │─┘                 │    │    │
│  │   │  └─────────────────┘                   │    │    │
│  │   │           │                             │    │    │
│  │   │  ┌────────▼────────┐                   │    │    │
│  │   │  │  SQL Instance 2 │                   │    │    │
│  │   │  │   (Port 1434)   │                   │    │    │
│  │   │  │     OrderDB     │                   │    │    │
│  │   │  └─────────────────┘                   │    │    │
│  │   └─────────────────────────────────────────┘    │    │
│  └───────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ Public Internet
                         ▼
            ┌────────────────────────────┐
            │  GitHub Repository         │
            │  (Raw Content)             │
            │                            │
            │  Setup Scripts:            │
            │  - setup-all.ps1          │
            │  - install-sql-server.ps1 │
            │  - setup-databases.ps1    │
            │  - setup-linked-servers.ps1│
            │  - deploy-application.ps1 │
            └────────────────────────────┘
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
   - Virtual Networks
   - Azure Bastion

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
- Deploy a Windows Server 2022 VM **WITHOUT public IP**
- Create **Azure Bastion** for secure access
- Configure network security (VNet with VM subnet and Bastion subnet)
- Install Azure AD Login extension for Entra ID authentication
- Install Custom Script Extension to automatically run setup scripts from GitHub

**Parameters you'll be prompted for:**
- Resource Group Name (default: rg-modernize-hackathon)
- Location (default: swedencentral)
- VM Name (default: vm-onprem-simulator)
- Admin Username (default: localadmin)

**Note:** Admin password will be **automatically generated** and displayed at the end.

### Step 2: Automated Setup Process

**No manual connection required!** The VM automatically configures itself using the Custom Script Extension.

The VM will automatically:
1. Download installation scripts from GitHub
2. Install SQL Server 2022 Developer Edition
3. Configure two SQL Server instances (ports 1433 and 1434)
4. Create CustomerDB and OrderDB databases with sample data
5. Set up linked server configuration
6. Install .NET 10 SDK and Runtime
7. Download and deploy the ASP.NET Core application
8. Start the application on port 8080

**This process takes approximately 20-30 minutes and requires no manual intervention.**

**IMPORTANT:** Save the admin password shown at the end of the deployment!

Monitor the deployment:
```bash
# Check VM provisioning state
az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --query "provisioningState"

# Check extension status
az vm extension list --resource-group rg-modernize-hackathon --vm-name vm-onprem-simulator --query "[].{Name:name, State:provisioningState}"
```

### Step 3: Access the VM

Since the VM has **no public IP**, you must use **Azure Bastion** to connect.

#### Option 1: Connect via Azure Portal (Easiest)

1. Navigate to the [Azure Portal](https://portal.azure.com)
2. Go to your VM resource
3. Click **Connect** → **Bastion**
4. Enter credentials:
   - **Username**: `localadmin` (or the username you specified)
   - **Password**: (the generated password shown during deployment)
5. Click **Connect**

#### Option 2: Connect via Azure CLI with Bastion Tunnel

**Note:** Bastion tunneling requires Standard SKU or higher. The current deployment uses Developer SKU which does not support tunneling. To use tunneling, upgrade to Standard SKU or use Option 1 (Azure Portal) for connection.

**To upgrade to Standard SKU:** In `deploy-vm.sh`, uncomment the Bastion subnet and public IP sections (lines 157-177), and change the SKU from `Developer` to `Standard` (line 187). You'll also need to add back the `--public-ip-address` parameter and `--enable-tunneling true` flag to the bastion create command.

<details>
<summary>For Standard SKU deployments (click to expand)</summary>

```bash
# RDP tunnel through Bastion (requires Standard SKU)
az network bastion tunnel \
  --name vm-onprem-simulator-bastion \
  --resource-group rg-modernize-hackathon \
  --target-resource-id $(az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --query id -o tsv) \
  --resource-port 3389 \
  --port 3389
```

Then connect your RDP client to `localhost:3389`.
</details>

#### Option 3: Use Entra ID Authentication

If you have the appropriate Azure RBAC role assigned:

1. Assign yourself the **Virtual Machine Administrator Login** role on the VM:
   ```bash
   az role assignment create \
     --role "Virtual Machine Administrator Login" \
     --assignee your-email@domain.com \
     --scope $(az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --query id -o tsv)
   ```

2. Connect via Bastion using:
   - **Username**: `AzureAD\your-email@domain.com`
   - **Password**: Your Azure AD password

## Scripts Overview

### 1. `deploy-vm.sh`
Main deployment script using Azure CLI to:
- Create resource group
- Deploy Windows Server 2022 VM **without public IP**
- Create **Azure Bastion** for secure access
- Configure VNet with VM subnet and Bastion subnet
- Install **Azure AD Login extension** for Entra ID authentication
- Install Custom Script Extension to automatically execute setup scripts from GitHub

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

From within the VM (since it has no public IP):

```powershell
# Get all customers
Invoke-WebRequest -Uri http://localhost:8080/api/customers

# Get all orders
Invoke-WebRequest -Uri http://localhost:8080/api/orders

# Create a new customer
Invoke-WebRequest -Uri http://localhost:8080/api/customers `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"name":"John Doe","email":"john@example.com"}'
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

✅ **Production-Grade Security Implemented:**

1. **No Public IP on VM** - VM is not directly accessible from the internet
2. **Azure Bastion** - Secure RDP access without exposing RDP port to the internet
3. **Entra ID Authentication** - Azure AD login enabled for VM access
4. **Random Generated Passwords** - Strong passwords automatically generated
5. **Version-Controlled Scripts** - Setup scripts from public GitHub ensure transparency and auditability

⚠️ **Additional Notes:**

1. **This is a development/hackathon environment** - Further hardening recommended for production
2. **SQL Server Developer Edition** - Licensed for dev/test only
3. **No SSL/TLS** - Application uses HTTP (not HTTPS)
4. **SQL Server uses default passwords** - Change for any non-hackathon use
5. **Scripts from public repository** - For production, consider using private repositories, signed releases, or script integrity validation (e.g., SHA256 checksums) to mitigate supply chain risks

**Additional recommendations for production:**
- Use Azure Key Vault for all secrets
- Enable SSL/TLS for application
- Implement proper authentication/authorization for application
- Enable audit logging and monitoring
- Use Azure Policy for compliance
- Implement backup and disaster recovery

## Cost Estimation

Approximate Azure costs (Sweden Central region):
- **VM (Standard_D4s_v3)**: ~$0.192/hour (~$140/month)
- **Managed Disk (128 GB Premium)**: ~$25/month
- **Azure Bastion (Developer SKU)**: Free (for dev/test scenarios)
- **Bandwidth**: Variable based on usage

**Estimated total**: ~$165/month (when running 24/7)

**Note:** The Developer SKU is free and perfect for dev/test scenarios. It supports one concurrent connection and does not require a public IP address or dedicated subnet, reducing both cost and complexity.

⚠️ **Important:** The Developer SKU is intended for non-production use only. For production workloads, use Standard or Premium SKU which provide reliability guarantees, support SLAs, and additional features like tunneling and multiple concurrent connections.

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
