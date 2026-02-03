# Deployment Guide: On-Premises Environment Simulator

This guide provides detailed step-by-step instructions for deploying the Windows Azure VM that simulates an on-premises environment for the Migrate and Modernize hackathon.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Steps](#deployment-steps)
3. [Manual Configuration](#manual-configuration)
4. [Automated Configuration](#automated-configuration)
5. [Verification and Testing](#verification-and-testing)
6. [Troubleshooting](#troubleshooting)
7. [Student Access Instructions](#student-access-instructions)

## Prerequisites

### Required Tools

1. **Azure CLI**
   - Download: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
   - Verify installation: `az --version`

2. **Azure Subscription**
   - Active subscription with contributor or owner access
   - Sufficient quota for Standard_D4s_v3 VM

3. **Local Machine Requirements**
   - Bash shell (Linux/Mac) or Git Bash (Windows)
   - RDP client for Windows VM access

### Azure Permissions

Ensure you have permissions to create:
- Resource Groups
- Virtual Machines
- Virtual Networks
- Network Security Groups
- VM Extensions

## Deployment Steps

### Step 1: Prepare Azure Environment

1. **Login to Azure CLI**
   ```bash
   az login
   ```

2. **Select the correct subscription**
   ```bash
   # List subscriptions
   az account list --output table
   
   # Set active subscription
   az account set --subscription "Your-Subscription-Name"
   
   # Verify
   az account show
   ```

### Step 2: Deploy the VM Using the Script

1. **Navigate to the init-vm directory**
   ```bash
   cd init-vm
   ```

2. **Make the deployment script executable**
   ```bash
   chmod +x deploy-vm.sh
   ```

3. **Run the deployment script**
   ```bash
   ./deploy-vm.sh
   ```
   
   **Optional:** To test with scripts from a different branch (e.g., for development):
   ```bash
   GITHUB_BRANCH=feature-branch ./deploy-vm.sh
   ```

4. **Provide the requested information when prompted:**
   - Resource Group Name: (default: rg-modernize-hackathon)
   - Location: (default: swedencentral)
   - VM Name: (default: vm-onprem-simulator)
   - Admin Username: (e.g., azureuser)
   - Admin Password: (must meet complexity requirements - minimum 12 characters, uppercase, lowercase, number, special character)

5. **Wait for deployment to complete** (approximately 5-10 minutes)

### Step 3: Connect to the VM

1. **Get the VM's public IP address**
   ```bash
   az vm show --resource-group rg-modernize-hackathon --name vm-onprem-simulator --show-details --query "publicIps" -o tsv
   ```

2. **Connect via RDP**
   - Windows: Use built-in Remote Desktop Connection (mstsc)
   - Mac: Use Microsoft Remote Desktop from App Store
   - Linux: Use Remmina or FreeRDP
   
   ```
   Host: <PUBLIC-IP>:3389
   Username: <ADMIN-USERNAME>
   Password: <ADMIN-PASSWORD>
   ```

## Automated Configuration (Default Behavior)

**No RDP connection needed!** The deploy-vm.sh script automatically configures the VM using Azure Custom Script Extension.

### How It Works

1. **Script Retrieval**
   - The deployment script configures the Custom Script Extension to download scripts directly from the public GitHub repository
   - Scripts include: setup-all.ps1, install-sql-server.ps1, setup-databases.ps1, setup-linked-servers.ps1, deploy-application.ps1
   
2. **Custom Script Extension**
   - Automatically installed on the VM after creation
   - Downloads scripts from GitHub using public URLs
   - Executes setup-all.ps1 which orchestrates the entire setup
   - Uses `-ExecutionPolicy Bypass` for secure script execution
   - Runs without requiring any RDP connection

3. **Monitoring Progress**
   ```bash
   # Check extension provisioning status
   az vm extension list \
     --resource-group rg-modernize-hackathon \
     --vm-name vm-onprem-simulator \
     --query "[].{Name:name, State:provisioningState}"
   
   # Check detailed extension logs (requires RDP to VM)
   # Logs located at: C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\
   ```

The entire setup process takes approximately 20-30 minutes and requires no manual intervention.

## Manual Configuration (Alternative Method)

If you need to manually configure the VM or troubleshoot issues, you can connect via RDP.

### Option 1: Automated Setup (Recommended)

1. **Open PowerShell as Administrator**

2. **Option A: Use the consolidated inline script (Recommended)**
   ```powershell
   # Create temp folder
   New-Item -ItemType Directory -Force -Path "C:\Temp"
   cd C:\Temp
   
   # Download the consolidated setup script
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/CZSK-MicroHacks/MicroHack-ModernizeInfra/main/init-vm/scripts/setup-all-inline.ps1" -OutFile "setup-all-inline.ps1"
   
   # Run the setup script
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   $env:AUTOMATION_MODE = 'false'  # Enable interactive mode
   .\setup-all-inline.ps1
   ```

   **Option B: Download individual scripts**
   ```powershell
   # Create folder for scripts
   New-Item -ItemType Directory -Force -Path "C:\Setup\scripts"
   cd C:\Setup\scripts
   
   # Download scripts from GitHub
   $baseUrl = "https://raw.githubusercontent.com/CZSK-MicroHacks/MicroHack-ModernizeInfra/main/init-vm/scripts"
   $scripts = @(
       "setup-all.ps1",
       "install-sql-server.ps1",
       "setup-databases.ps1",
       "setup-linked-servers.ps1",
       "deploy-application.ps1"
   )
   
   foreach ($script in $scripts) {
       Invoke-WebRequest -Uri "$baseUrl/$script" -OutFile $script
   }
   
   # Run the master setup script
   Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
   .\setup-all.ps1
   ```

3. **Wait for completion** (approximately 20-30 minutes)
   - The script will install SQL Server
   - Create databases
   - Configure linked servers
   - Prepare the application folder

### Option 2: Manual Step-by-Step Setup

If you prefer to run each step manually or need to troubleshoot:

#### Step 3.1: Install SQL Server

```powershell
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
cd C:\Setup\scripts
.\install-sql-server.ps1
```

**What this does:**
- Downloads SQL Server 2022 Developer Edition
- Installs default instance on port 1433
- Installs named instance MSSQL2 on port 1434
- Configures TCP/IP and firewall rules
- Enables SQL Server authentication

**Expected duration:** 15-20 minutes

#### Step 3.2: Create Databases

```powershell
.\setup-databases.ps1
```

**What this does:**
- Creates CustomerDB on default instance (port 1433)
- Creates OrderDB on named instance (port 1434)
- Creates Customers and Orders tables
- Inserts sample data

**Expected duration:** 2-3 minutes

#### Step 3.3: Configure Linked Servers

```powershell
.\setup-linked-servers.ps1
```

**What this does:**
- Creates linked server from default instance to MSSQL2
- Configures authentication
- Tests connectivity
- Creates cross-database view (vw_CustomerOrders)

**Expected duration:** 1-2 minutes

#### Step 3.4: Deploy Application

```powershell
.\deploy-application.ps1
```

**What this does:**
- Installs .NET SDK
- Creates application folder structure
- Configures connection strings
- Sets up firewall rules
- Optionally clones and builds the application

**Expected duration:** 5-10 minutes

### Step 4: Deploy Application Binaries

The application binaries need to be deployed to the VM. Choose one of these methods:

#### Method A: Build on the VM

```powershell
# Install Git if not already installed
winget install Git.Git

# Clone repository
cd C:\Apps
git clone https://github.com/CZSK-MicroHacks/MicroHack-ModernizeInfra.git

# Build and publish
cd MicroHack-ModernizeInfra\ModernizeInfraApp
dotnet restore
dotnet publish -c Release -o C:\Apps\ModernizeInfraApp

# Start application
cd C:\Apps\ModernizeInfraApp
dotnet ModernizeInfraApp.dll --urls "http://0.0.0.0:8080"
```

#### Method B: Copy Pre-built Binaries

1. On your development machine:
   ```bash
   cd ModernizeInfraApp
   dotnet publish -c Release -o ./publish
   ```

2. Copy the `publish` folder to the VM at `C:\Apps\ModernizeInfraApp`

3. On the VM, start the application:
   ```powershell
   cd C:\Apps\ModernizeInfraApp
   dotnet ModernizeInfraApp.dll --urls "http://0.0.0.0:8080"
   ```

## Automated Configuration

For fully automated deployment using Azure VM Custom Script Extension that downloads scripts from GitHub:

### Deploy Custom Script Extension

**Note:** The Custom Script Extension now embeds the setup scripts directly without downloading from GitHub. This provides better security and reliability.

The deployment script (`deploy-vm.sh`) handles this automatically by:
1. Reading the consolidated setup script from the local repository
2. Base64-encoding the script content
3. Embedding it directly in the extension command

If running commands manually, use the automated deployment script:

```bash
# Define resource and VM names (adjust as needed)
RESOURCE_GROUP="rg-modernize-hackathon"
VM_NAME="vm-onprem-simulator"

# Navigate to the repository directory
cd /path/to/MicroHack-ModernizeInfra/init-vm

# Read and encode the setup script (cross-platform compatible)
SCRIPT_CONTENT_B64=$(cat scripts/setup-all-inline.ps1 | base64 | tr -d '\n')

# Create wrapper command that decodes and executes the embedded script
WRAPPER_CMD='$ErrorActionPreference="Stop";$env:AUTOMATION_MODE="true";$b64=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(\"'${SCRIPT_CONTENT_B64}'\"));$f=\"$env:TEMP\setup-inline.ps1\";$b64|Out-File -FilePath $f -Encoding UTF8;Write-Host \"Executing embedded setup script...\";& $f'

# Deploy Custom Script Extension with embedded script
az vm extension set \
  --resource-group "$RESOURCE_GROUP" \
  --vm-name "$VM_NAME" \
  --name CustomScriptExtension \
  --publisher Microsoft.Compute \
  --version 1.10 \
  --protected-settings "{\"commandToExecute\":\"powershell -ExecutionPolicy Bypass -Command \\\"${WRAPPER_CMD}\\\"\"}"
```

**Benefits of this approach:**
- No external dependencies on GitHub for setup scripts
- Setup scripts are version-controlled with the deployment code
- Eliminates potential issues with GitHub availability or rate limits
- Improved security by avoiding external script downloads

## Verification and Testing

### Verify SQL Server Instances

1. **Check services are running**
   ```powershell
   Get-Service | Where-Object { $_.Name -like "*SQL*" -and $_.Status -eq "Running" }
   ```

2. **Test connectivity to default instance**
   ```powershell
   sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "SELECT @@VERSION" -C
   ```

3. **Test connectivity to named instance**
   ```powershell
   sqlcmd -S localhost,1434 -U sa -P YourStrongPass123! -Q "SELECT @@VERSION" -C
   ```

### Verify Databases

```powershell
# Check CustomerDB
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "USE CustomerDB; SELECT COUNT(*) as CustomerCount FROM Customers" -C

# Check OrderDB
sqlcmd -S localhost,1434 -U sa -P YourStrongPass123! -Q "USE OrderDB; SELECT COUNT(*) as OrderCount FROM Orders" -C
```

### Verify Linked Server

```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "EXEC sp_testlinkedserver 'MSSQL2_LINK'" -C
```

### Verify Cross-Database View

```powershell
sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "USE CustomerDB; SELECT TOP 5 * FROM vw_CustomerOrders" -C
```

### Test Application

1. **Check if application is running**
   ```powershell
   Test-NetConnection localhost -Port 8080
   ```

2. **Test API endpoints from the VM**
   ```powershell
   # Get customers
   Invoke-RestMethod -Uri "http://localhost:8080/api/customers"
   
   # Get orders
   Invoke-RestMethod -Uri "http://localhost:8080/api/orders"
   ```

3. **Test API endpoints from external machine**
   ```bash
   # Replace <VM-PUBLIC-IP> with actual IP
   curl http://<VM-PUBLIC-IP>:8080/api/customers
   curl http://<VM-PUBLIC-IP>:8080/api/orders
   ```

## Troubleshooting

### Issue: SQL Server Installation Fails

**Symptoms:** Installation script errors or SQL Server services don't start

**Solutions:**
1. Check if VM has enough resources (4 vCPUs, 16 GB RAM recommended)
2. Verify Windows Updates are not blocking the installation
3. Check installation logs at `C:\Program Files\Microsoft SQL Server\*\Setup Bootstrap\Log`
4. Manually download SQL Server from Microsoft and install

### Issue: Cannot Connect to SQL Server

**Symptoms:** Connection timeout or authentication errors

**Solutions:**
1. Verify services are running:
   ```powershell
   Get-Service MSSQLSERVER, MSSQL$MSSQL2
   ```

2. Check firewall rules:
   ```powershell
   Get-NetFirewallRule -DisplayName "*SQL*"
   ```

3. Test port connectivity:
   ```powershell
   Test-NetConnection localhost -Port 1433
   Test-NetConnection localhost -Port 1434
   ```

4. Verify TCP/IP is enabled in SQL Server Configuration Manager

### Issue: Linked Server Fails

**Symptoms:** Error when querying cross-database view

**Solutions:**
1. Test linked server:
   ```powershell
   sqlcmd -S localhost,1433 -U sa -P YourStrongPass123! -Q "EXEC sp_testlinkedserver 'MSSQL2_LINK'"
   ```

2. Verify password is correct in linked server configuration
3. Check network connectivity between instances
4. Review SQL Server error logs

### Issue: Application Won't Start

**Symptoms:** Cannot access http://localhost:8080

**Solutions:**
1. Verify .NET SDK is installed:
   ```powershell
   dotnet --version
   ```

2. Check if port 8080 is already in use:
   ```powershell
   Get-NetTCPConnection -LocalPort 8080
   ```

3. Check firewall rules:
   ```powershell
   Get-NetFirewallRule -DisplayName "*Application*"
   ```

4. Review application logs
5. Verify connection strings are correct in appsettings.json

### Issue: Cannot Access VM from Internet

**Symptoms:** Cannot RDP or access application from external network

**Solutions:**
1. Verify NSG rules:
   ```bash
   az network nsg rule list \
     --resource-group rg-modernize-hackathon \
     --nsg-name vm-onprem-simulator-nsg \
     --output table
   ```

2. Check public IP is assigned:
   ```bash
   az network public-ip show \
     --resource-group rg-modernize-hackathon \
     --name vm-onprem-simulator-pip
   ```

3. Verify Windows Firewall on the VM is not blocking connections

## Student Access Instructions

For hackathon students, provide them with:

### Access Information Template

```
================================================
  Hackathon Environment Access
================================================

VM Public IP: <VM-PUBLIC-IP>
RDP Port: 3389

Credentials:
  Username: <USERNAME>
  Password: <PASSWORD>

Application:
  URL: http://<VM-PUBLIC-IP>:8080
  
SQL Server Instances:
  Instance 1: <VM-PUBLIC-IP>,1433
  Instance 2: <VM-PUBLIC-IP>,1434
  SA Password: YourStrongPass123!

Databases:
  CustomerDB (Instance 1)
    - Customers table
  OrderDB (Instance 2)
    - Orders table
  
Linked Server:
  Name: MSSQL2_LINK
  View: CustomerDB.dbo.vw_CustomerOrders

================================================
```

### Student Tasks

Students should be able to:

1. **Explore the On-Premises Environment**
   - Connect via RDP to the VM
   - Examine SQL Server configuration
   - Review application architecture
   - Query databases and linked servers

2. **Document Current State**
   - Create architecture diagrams
   - Document dependencies
   - Identify modernization opportunities

3. **Plan Migration Strategy**
   - Choose Azure services (e.g., Azure SQL Database, App Service)
   - Design migration approach
   - Identify challenges and solutions

4. **Execute Migration** (in subsequent hackathon phases)
   - Migrate databases to Azure SQL
   - Deploy application to Azure App Service
   - Configure networking and security
   - Test migrated application

## Cleanup

After the hackathon, clean up resources:

```bash
# Delete resource group (removes all resources)
az group delete --name rg-modernize-hackathon --yes --no-wait

# Verify deletion
az group list --output table
```

## Additional Resources

- Azure CLI Documentation: https://docs.microsoft.com/en-us/cli/azure/
- SQL Server on Azure VM: https://docs.microsoft.com/en-us/azure/azure-sql/virtual-machines/
- .NET on Azure: https://docs.microsoft.com/en-us/dotnet/azure/
- Azure Migration Guide: https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/migrate/

## Support

For issues during deployment:
1. Check the troubleshooting section above
2. Review logs on the VM at `C:\Temp\setup-log.txt`
3. Contact hackathon organizers
4. Review Azure VM boot diagnostics in the Azure Portal
