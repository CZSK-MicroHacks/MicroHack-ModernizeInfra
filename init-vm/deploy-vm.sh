#!/bin/bash
#
# Deploy Windows Azure VM for On-Premises Environment Simulation
# This script deploys a Windows Server 2022 VM with SQL Server and ASP.NET Core application
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_RESOURCE_GROUP="rg-modernize-hackathon"
DEFAULT_LOCATION="swedencentral"
DEFAULT_VM_NAME="vm-onprem-simulator"
DEFAULT_VM_SIZE="Standard_D4s_v3"
DEFAULT_ADMIN_USERNAME="localadmin"

echo "=================================================="
echo "  Azure VM Deployment for Modernize Hackathon"
echo "=================================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in to Azure. Please login:${NC}"
    az login
fi

# Get current subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}Using subscription: ${SUBSCRIPTION}${NC}"
echo ""

# Prompt for parameters
read -p "Resource Group Name [${DEFAULT_RESOURCE_GROUP}]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}

read -p "Location [${DEFAULT_LOCATION}]: " LOCATION
LOCATION=${LOCATION:-$DEFAULT_LOCATION}

read -p "VM Name [${DEFAULT_VM_NAME}]: " VM_NAME
VM_NAME=${VM_NAME:-$DEFAULT_VM_NAME}

read -p "Admin Username [${DEFAULT_ADMIN_USERNAME}]: " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-$DEFAULT_ADMIN_USERNAME}

# Generate a random strong password for local admin that meets Windows complexity requirements
# Password must contain: uppercase, lowercase, numbers, and special characters
# Generate segments with sufficient length to ensure minimum requirements after filtering
UPPER=$(tr -dc 'A-Z' < /dev/urandom | head -c 4)
LOWER=$(tr -dc 'a-z' < /dev/urandom | head -c 4)
DIGITS=$(tr -dc '0-9' < /dev/urandom | head -c 4)
SPECIAL=$(tr -dc '!@#$%^&*' < /dev/urandom | head -c 4)
# Combine and shuffle to mix character types
ADMIN_PASSWORD=$(echo "${UPPER}${LOWER}${DIGITS}${SPECIAL}" | fold -w1 | shuf | tr -d '\n')
echo -e "${GREEN}Generated strong random password for local admin user${NC}"

# Derived names
VNET_NAME="${VM_NAME}-vnet"
SUBNET_NAME="${VM_NAME}-subnet"
# BASTION_SUBNET_NAME="AzureBastionSubnet"  # Not needed for Developer SKU
BASTION_NAME="${VM_NAME}-bastion"
# BASTION_IP_NAME="${VM_NAME}-bastion-pip"  # Not needed for Developer SKU
NSG_NAME="${VM_NAME}-nsg"
NIC_NAME="${VM_NAME}-nic"

# Generate a valid Windows computer name (max 15 chars, no special chars)
# 1. Convert to lowercase for consistency
# 2. Remove all non-alphanumeric characters
# 3. Handle empty result (use default 'vmdefault')
# 4. Ensure it starts with a letter (prepend 'vm' if it starts with a number)
# 5. Truncate to 15 characters
COMPUTER_NAME=$(echo "$VM_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')

# If empty after sanitization, use default
if [[ -z "$COMPUTER_NAME" ]]; then
    COMPUTER_NAME="vmdefault"
fi

# Check if it starts with a number and prepend 'vm' if so (truncate first to prevent exceeding 15 chars)
if [[ "$COMPUTER_NAME" =~ ^[0-9] ]]; then
    COMPUTER_NAME="vm$(echo "$COMPUTER_NAME" | cut -c1-13)"
fi

# Final truncation to ensure 15 char limit
COMPUTER_NAME=$(echo "$COMPUTER_NAME" | cut -c1-15)

echo ""
echo "=================================================="
echo "Deployment Configuration:"
echo "=================================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location: ${LOCATION}"
echo "VM Name: ${VM_NAME}"
echo "Computer Name: ${COMPUTER_NAME}"
echo "VM Size: ${DEFAULT_VM_SIZE}"
echo "Admin Username: ${ADMIN_USERNAME}"
echo "Admin Password: ${ADMIN_PASSWORD}"
echo ""
echo "Security Configuration:"
echo "  - VM will be deployed WITHOUT public IP"
echo "  - Azure Bastion will be created for secure access"
echo "  - Setup scripts will be downloaded from GitHub"
echo "  - Entra ID authentication will be enabled"
echo ""
echo "⚠️  SECURITY WARNING:"
echo "  The generated admin password will be displayed at the end."
echo "  Please save it immediately to a secure password manager."
echo "  The password will NOT be stored anywhere else."
echo "=================================================="
echo ""

read -p "Continue with deployment? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Starting deployment..."
echo ""

# Create resource group
echo -e "${YELLOW}Creating resource group...${NC}"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none

echo -e "${GREEN}✓ Resource group created${NC}"

# Create virtual network with VM subnet and Bastion subnet
echo -e "${YELLOW}Creating virtual network with subnets...${NC}"
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefix 10.0.0.0/16 \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix 10.0.1.0/24 \
    --output none

# Create Bastion subnet (not required for Developer SKU)
# Developer SKU does not require a dedicated AzureBastionSubnet or public IP
# az network vnet subnet create \
#     --resource-group "$RESOURCE_GROUP" \
#     --vnet-name "$VNET_NAME" \
#     --name "$BASTION_SUBNET_NAME" \
#     --address-prefix 10.0.2.0/26 \
#     --output none

echo -e "${GREEN}✓ Virtual network and subnets created${NC}"

# Create public IP for Bastion (not required for Developer SKU)
# echo -e "${YELLOW}Creating public IP address for Bastion...${NC}"
# az network public-ip create \
#     --resource-group "$RESOURCE_GROUP" \
#     --name "$BASTION_IP_NAME" \
#     --sku Standard \
#     --allocation-method Static \
#     --location "$LOCATION" \
#     --output none
# 
# echo -e "${GREEN}✓ Public IP for Bastion created${NC}"

# Create Azure Bastion (this takes several minutes)
echo -e "${YELLOW}Creating Azure Bastion with Developer SKU (this may take 5-10 minutes)...${NC}"
az network bastion create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_NAME" \
    --vnet-name "$VNET_NAME" \
    --location "$LOCATION" \
    --sku Developer \
    --output none

echo -e "${GREEN}✓ Azure Bastion created${NC}"

# Create NSG (keeping minimal rules for internal communication)
echo -e "${YELLOW}Creating Network Security Group...${NC}"
az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --output none

echo -e "${GREEN}✓ NSG created${NC}"

# Create NIC without public IP
echo -e "${YELLOW}Creating network interface...${NC}"
az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --network-security-group "$NSG_NAME" \
    --output none

echo -e "${GREEN}✓ Network interface created${NC}"

# Create VM with managed identity
echo -e "${YELLOW}Creating Windows Server VM (this may take a few minutes)...${NC}"
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --computer-name "$COMPUTER_NAME" \
    --location "$LOCATION" \
    --nics "$NIC_NAME" \
    --image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest" \
    --size "$DEFAULT_VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --os-disk-size-gb 128 \
    --assign-identity \
    --output none

echo -e "${GREEN}✓ VM created successfully${NC}"

# Enable Azure AD login for the VM
echo -e "${YELLOW}Installing Azure AD Login extension for Entra ID authentication...${NC}"
az vm extension set \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name AADLoginForWindows \
    --publisher Microsoft.Azure.ActiveDirectory \
    --output none

echo -e "${GREEN}✓ Azure AD Login extension installed${NC}"

# Install Custom Script Extension with embedded inline script
echo -e "${YELLOW}Installing Custom Script Extension...${NC}"
# Note: Script content is embedded directly in the command without downloading from GitHub
# This ensures the extension executes code directly without external dependencies

# Define the complete setup script inline
SETUP_SCRIPT_INLINE='
$ErrorActionPreference = "Stop"
$env:AUTOMATION_MODE = "true"
Write-Host "Starting consolidated inline setup..." -ForegroundColor Cyan

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

# STEP 1: Install SQL Server
Write-Host "Step 1: SQL Server Installation" -ForegroundColor Cyan
Write-Log "Starting SQL Server installation"

$DownloadFolder = "C:\Temp\SQLServer"
$SqlMediaPath = "$DownloadFolder\SQLMedia"
New-Item -ItemType Directory -Force -Path $DownloadFolder,$SqlMediaPath | Out-Null

$SqlDownloadUrl = "https://go.microsoft.com/fwlink/p/?linkid=2215158"
$SqlSetupPath = "$DownloadFolder\SQL2022-SSEI-Dev.exe"
Invoke-WebRequest -Uri $SqlDownloadUrl -OutFile $SqlSetupPath
Start-Process -FilePath $SqlSetupPath -ArgumentList "/Action=Download","/MediaPath=$SqlMediaPath","/MediaType=Core","/Quiet" -Wait

$SetupExe = Get-ChildItem -Path $SqlMediaPath -Recurse -Filter "setup.exe" | Select-Object -First 1
if ($null -eq $SetupExe) { Write-Error "Setup.exe not found"; exit 1 }

# Install default instance
$ConfigFile1 = "$DownloadFolder\ConfigurationFile1.ini"
@"
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
"@ | Out-File -FilePath $ConfigFile1 -Encoding ASCII

Start-Process -FilePath $SetupExe.FullName -ArgumentList "/ConfigurationFile=$ConfigFile1" -Wait -NoNewWindow

# Install named instance
$ConfigFile2 = "$DownloadFolder\ConfigurationFile2.ini"
@"
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
"@ | Out-File -FilePath $ConfigFile2 -Encoding ASCII

Start-Process -FilePath $SetupExe.FullName -ArgumentList "/ConfigurationFile=$ConfigFile2" -Wait -NoNewWindow
Start-Sleep -Seconds 30

# Configure TCP/IP
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name SqlServer -Force -AllowClobber
Import-Module SqlServer -ErrorAction SilentlyContinue

$wmi1 = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
$uri1 = "ManagedComputer[@Name=\"$env:COMPUTERNAME\"]/ServerInstance[@Name=\"MSSQLSERVER\"]/ServerProtocol[@Name=\"Tcp\"]"
$tcp1 = $wmi1.GetSmoObject($uri1)
$tcp1.IsEnabled = $true
$tcp1.Alter()
$ipAll1 = $tcp1.IPAddresses | Where-Object { $_.Name -eq "IPAll" }
$ipAll1.IPAddressProperties["TcpPort"].Value = "1433"
$ipAll1.IPAddressProperties["TcpDynamicPorts"].Value = ""
$tcp1.Alter()

$uri2 = "ManagedComputer[@Name=\"$env:COMPUTERNAME\"]/ServerInstance[@Name=\"MSSQL2\"]/ServerProtocol[@Name=\"Tcp\"]"
$tcp2 = $wmi1.GetSmoObject($uri2)
$tcp2.IsEnabled = $true
$tcp2.Alter()
$ipAll2 = $tcp2.IPAddresses | Where-Object { $_.Name -eq "IPAll" }
$ipAll2.IPAddressProperties["TcpPort"].Value = "1434"
$ipAll2.IPAddressProperties["TcpDynamicPorts"].Value = ""
$tcp2.Alter()

Restart-Service -Name "MSSQLSERVER","MSSQL$MSSQL2","SQLBrowser" -Force
Start-Sleep -Seconds 10

New-NetFirewallRule -DisplayName "SQL Server Default" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "SQL Server MSSQL2" -Direction Inbound -Protocol TCP -LocalPort 1434 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "SQL Browser" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action Allow -ErrorAction SilentlyContinue

Write-Log "SQL Server installation completed"

# STEP 2: Setup Databases
Write-Host "Step 2: Database Setup" -ForegroundColor Cyan
$SqlCmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"

@"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = \"CustomerDB\") CREATE DATABASE CustomerDB;
GO
USE CustomerDB;
GO
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = \"Customers\") CREATE TABLE Customers (CustomerId INT PRIMARY KEY IDENTITY(1,1), Name NVARCHAR(200) NOT NULL, Email NVARCHAR(200) NOT NULL, CreatedDate DATETIME2 NOT NULL DEFAULT GETDATE());
GO
IF NOT EXISTS (SELECT * FROM Customers) INSERT INTO Customers (Name, Email) VALUES (\"John Smith\",\"john.smith@example.com\"),(\"Jane Doe\",\"jane.doe@example.com\"),(\"Bob Johnson\",\"bob.johnson@example.com\"),(\"Alice Williams\",\"alice.williams@example.com\"),(\"Charlie Brown\",\"charlie.brown@example.com\");
GO
"@ | Out-File "$env:TEMP\customerdb.sql" -Encoding ASCII
& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i "$env:TEMP\customerdb.sql" -C

@"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = \"OrderDB\") CREATE DATABASE OrderDB;
GO
USE OrderDB;
GO
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = \"Orders\") CREATE TABLE Orders (OrderId INT PRIMARY KEY IDENTITY(1,1), CustomerId INT NOT NULL, ProductName NVARCHAR(200) NOT NULL, Amount DECIMAL(18,2) NOT NULL, OrderDate DATETIME2 NOT NULL DEFAULT GETDATE());
GO
IF NOT EXISTS (SELECT * FROM Orders) INSERT INTO Orders (CustomerId, ProductName, Amount) VALUES (1,\"Laptop\",999.99),(1,\"Mouse\",29.99),(2,\"Keyboard\",79.99),(3,\"Monitor\",299.99),(4,\"Headphones\",149.99),(5,\"Webcam\",89.99),(2,\"USB Cable\",12.99),(3,\"Desk Lamp\",45.99);
GO
"@ | Out-File "$env:TEMP\orderdb.sql" -Encoding ASCII
& $SqlCmdPath -S "localhost,1434" -U sa -P $SqlPassword -i "$env:TEMP\orderdb.sql" -C

Write-Log "Database setup completed"

# STEP 3: Linked Servers
Write-Host "Step 3: Linked Server Configuration" -ForegroundColor Cyan

@"
USE master;
GO
EXEC sp_configure \"show advanced options\", 1; RECONFIGURE;
GO
EXEC sp_configure \"Ad Hoc Distributed Queries\", 1; RECONFIGURE;
GO
IF EXISTS(SELECT * FROM sys.servers WHERE name = \"MSSQL2_LINK\") EXEC sp_dropserver \"MSSQL2_LINK\", \"droplogins\";
GO
EXEC sp_addlinkedserver @server = \"MSSQL2_LINK\", @srvproduct = \"\", @provider = \"MSOLEDBSQL\", @datasrc = \"localhost,1434\";
GO
EXEC sp_addlinkedsrvlogin @rmtsrvname = \"MSSQL2_LINK\", @useself = \"FALSE\", @locallogin = NULL, @rmtuser = \"sa\", @rmtpassword = \"$SqlPassword\";
GO
EXEC sp_testlinkedserver \"MSSQL2_LINK\";
GO
"@ | Out-File "$env:TEMP\linkedserver.sql" -Encoding ASCII
& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i "$env:TEMP\linkedserver.sql" -C

@"
USE CustomerDB;
GO
IF OBJECT_ID(\"dbo.vw_CustomerOrders\", \"V\") IS NOT NULL DROP VIEW dbo.vw_CustomerOrders;
GO
CREATE VIEW dbo.vw_CustomerOrders AS SELECT c.CustomerId, c.Name, c.Email, c.CreatedDate, o.OrderId, o.ProductName, o.Amount, o.OrderDate FROM CustomerDB.dbo.Customers c LEFT JOIN MSSQL2_LINK.OrderDB.dbo.Orders o ON c.CustomerId = o.CustomerId;
GO
"@ | Out-File "$env:TEMP\view.sql" -Encoding ASCII
& $SqlCmdPath -S "localhost,1433" -U sa -P $SqlPassword -i "$env:TEMP\view.sql" -C

Write-Log "Linked server configuration completed"

# STEP 4: Application
Write-Host "Step 4: Application Deployment" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $AppFolder | Out-Null

$dotnetInstalled = $false
try { $dotnetVersion = & dotnet --version 2>$null; if ($dotnetVersion) { $dotnetInstalled = $true } } catch {}

if (-not $dotnetInstalled) {
    $installerPath = "$env:TEMP\dotnet-sdk-installer.exe"
    Invoke-WebRequest -Uri "https://download.visualstudio.microsoft.com/download/pr/6224f00f-08da-4e7f-85b1-00d42c2bb3d3/b775de636b91e023574a0bbc291f705a/dotnet-sdk-9.0.100-win-x64.exe" -OutFile $installerPath -UseBasicParsing
    Start-Process -FilePath $installerPath -ArgumentList "/quiet","/norestart" -Wait
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

@{
    Logging = @{ LogLevel = @{ Default = "Information"; "Microsoft.AspNetCore" = "Warning" } }
    AllowedHosts = "*"
    ConnectionStrings = @{
        CustomerDatabase = "Server=localhost,1433;Database=CustomerDB;User Id=sa;Password=$SqlPassword;TrustServerCertificate=True;Encrypt=False;"
        OrderDatabase = "Server=localhost,1434;Database=OrderDB;User Id=sa;Password=$SqlPassword;TrustServerCertificate=True;Encrypt=False;"
    }
} | ConvertTo-Json -Depth 10 | Out-File "$AppFolder\appsettings.json" -Encoding UTF8

@"
@echo off
cd /d "$AppFolder"
if exist "$AppFolder\ModernizeInfraApp.dll" (dotnet ModernizeInfraApp.dll --urls http://0.0.0.0:$AppPort) else (echo Application binaries not found!)
"@ | Out-File "$AppFolder\start-app.bat" -Encoding ASCII

New-NetFirewallRule -DisplayName "ASP.NET Core App" -Direction Inbound -Protocol TCP -LocalPort $AppPort -Action Allow -ErrorAction SilentlyContinue

try { $gitVersion = & git --version 2>$null } catch {}
if ($gitVersion) {
    $repoPath = "C:\Apps\MicroHack-ModernizeInfra"
    if (-not (Test-Path $repoPath)) {
        git clone https://github.com/CZSK-MicroHacks/MicroHack-ModernizeInfra.git $repoPath
    }
    Push-Location "$repoPath\ModernizeInfraApp"
    try { & dotnet restore; & dotnet publish -c Release -o $AppFolder } catch { Write-Host "Build error: $_" } finally { Pop-Location }
}

$endTime = Get-Date
$duration = $endTime - $startTime
Write-Log "Setup completed in $($duration.TotalMinutes) minutes"
Write-Host "Setup Complete!" -ForegroundColor Green
'

# Execute the inline script via Custom Script Extension
# The script is embedded directly without any external downloads
az vm extension set \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension \
    --publisher Microsoft.Compute \
    --version 1.10 \
    --protected-settings "{\"commandToExecute\":\"powershell -ExecutionPolicy Bypass -Command \\\"${SETUP_SCRIPT_INLINE}\\\"\"}" \
    --output none

echo -e "${GREEN}✓ Custom Script Extension installed${NC}"

echo ""
echo "=================================================="
echo "  VM Deployment Successful!"
echo "=================================================="
echo "VM Name: ${VM_NAME}"
echo "Admin Username: ${ADMIN_USERNAME}"
echo ""
echo "⚠️  IMPORTANT - SAVE THESE CREDENTIALS IMMEDIATELY!"
echo ""
echo "Admin Password: ${ADMIN_PASSWORD}"
echo ""
echo "Copy this password to a secure password manager now."
echo "This is the only time it will be displayed."
echo ""
echo "=================================================="
echo "  Security Configuration"
echo "=================================================="
echo "✓ VM deployed WITHOUT public IP address"
echo "✓ Azure Bastion deployed for secure access"
echo "✓ Entra ID authentication enabled"
echo ""
echo "=================================================="
echo "  Automated Setup in Progress"
echo "=================================================="
echo "The Custom Script Extension is now running and will:"
echo "  1. Install SQL Server 2022 with two instances"
echo "  2. Create and populate databases"
echo "  3. Configure linked servers"
echo "  4. Deploy the ASP.NET Core application"
echo ""
echo "This process takes approximately 20-30 minutes."
echo ""
echo "Monitor extension status:"
echo "  az vm extension list \\"
echo "    --resource-group $RESOURCE_GROUP \\"
echo "    --vm-name $VM_NAME \\"
echo "    --query \"[].{Name:name, State:provisioningState}\""
echo ""
echo "=================================================="
echo "  How to Connect"
echo "=================================================="
echo "1. Connect using Azure Bastion from Azure Portal:"
echo "   - Navigate to the VM in Azure Portal"
echo "   - Click 'Connect' -> 'Bastion'"
echo "   - Enter credentials:"
echo "     Username: ${ADMIN_USERNAME}"
echo "     Password: ${ADMIN_PASSWORD}"
echo ""
echo "NOTE: Azure Bastion tunneling is not available with Developer SKU."
echo "      Use the Azure Portal for Bastion connection."
echo ""
echo "2. To use Entra ID authentication:"
echo "   - Username: AzureAD\\your-email@domain.com"
echo "   - Password: your Azure AD password"
echo "   - Ensure you have 'Virtual Machine Administrator Login' or"
echo "     'Virtual Machine User Login' role on the VM"
echo ""
echo "=================================================="
echo ""
echo -e "${GREEN}Deployment complete! Setup is running automatically.${NC}"
