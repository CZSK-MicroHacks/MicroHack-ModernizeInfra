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
DEFAULT_LOCATION="eastus"
DEFAULT_VM_NAME="vm-onprem-simulator"
DEFAULT_VM_SIZE="Standard_D4s_v3"

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

read -p "Admin Username: " ADMIN_USERNAME
while [[ -z "$ADMIN_USERNAME" ]]; do
    echo -e "${RED}Admin username cannot be empty${NC}"
    read -p "Admin Username: " ADMIN_USERNAME
done

read -sp "Admin Password: " ADMIN_PASSWORD
echo ""
while [[ -z "$ADMIN_PASSWORD" ]]; do
    echo -e "${RED}Admin password cannot be empty${NC}"
    read -sp "Admin Password: " ADMIN_PASSWORD
    echo ""
done

# Derived names
VNET_NAME="${VM_NAME}-vnet"
SUBNET_NAME="${VM_NAME}-subnet"
NSG_NAME="${VM_NAME}-nsg"
PUBLIC_IP_NAME="${VM_NAME}-pip"
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

# Create virtual network
echo -e "${YELLOW}Creating virtual network...${NC}"
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefix 10.0.0.0/16 \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix 10.0.1.0/24 \
    --output none

echo -e "${GREEN}✓ Virtual network created${NC}"

# Create public IP
echo -e "${YELLOW}Creating public IP address...${NC}"
az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --allocation-method Static \
    --sku Standard \
    --output none

echo -e "${GREEN}✓ Public IP created${NC}"

# Create NSG
echo -e "${YELLOW}Creating Network Security Group...${NC}"
az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --output none

# Add NSG rules
echo -e "${YELLOW}Configuring security rules...${NC}"

# RDP access
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowRDP" \
    --priority 1000 \
    --destination-port-ranges 3389 \
    --protocol Tcp \
    --access Allow \
    --output none

# HTTP access for application
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowHTTP" \
    --priority 1010 \
    --destination-port-ranges 8080 \
    --protocol Tcp \
    --access Allow \
    --output none

# SQL Server default instance
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowSQLServer1" \
    --priority 1020 \
    --destination-port-ranges 1433 \
    --protocol Tcp \
    --access Allow \
    --output none

# SQL Server named instance
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowSQLServer2" \
    --priority 1030 \
    --destination-port-ranges 1434 \
    --protocol Tcp \
    --access Allow \
    --output none

echo -e "${GREEN}✓ Security rules configured${NC}"

# Create NIC
echo -e "${YELLOW}Creating network interface...${NC}"
az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --public-ip-address "$PUBLIC_IP_NAME" \
    --network-security-group "$NSG_NAME" \
    --output none

echo -e "${GREEN}✓ Network interface created${NC}"

# Create VM
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
    --output none

echo -e "${GREEN}✓ VM created successfully${NC}"

# Get the public IP address
PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query ipAddress -o tsv)

# Create storage account for scripts
echo -e "${YELLOW}Creating storage account for installation scripts...${NC}"
# Generate a valid storage account name (3-24 chars, lowercase letters and numbers only)
# Format: st + sanitized resource group name + random suffix
RG_SANITIZED=$(echo "$RESOURCE_GROUP" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
RANDOM_SUFFIX=$(date +%s%N | md5sum | head -c 6)
STORAGE_ACCOUNT_NAME="st${RG_SANITIZED:0:12}${RANDOM_SUFFIX}"
# Ensure name is at least 3 characters and at most 24 characters
STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:0:24}"
if [ ${#STORAGE_ACCOUNT_NAME} -lt 3 ]; then
    STORAGE_ACCOUNT_NAME="stmodernize${RANDOM_SUFFIX}"
fi
CONTAINER_NAME="scripts"

az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false \
    --output none

echo -e "${GREEN}✓ Storage account created: ${STORAGE_ACCOUNT_NAME}${NC}"

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --query "[0].value" -o tsv)

# Create container (private access only)
echo -e "${YELLOW}Creating blob container...${NC}"
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --public-access off \
    --output none

echo -e "${GREEN}✓ Container created${NC}"

# Upload scripts to blob storage
echo -e "${YELLOW}Uploading installation scripts to blob storage...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

for script_file in "$SCRIPT_DIR"/*.ps1; do
    if [ -f "$script_file" ]; then
        filename=$(basename "$script_file")
        echo "  Uploading $filename..."
        az storage blob upload \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --account-key "$STORAGE_KEY" \
            --container-name "$CONTAINER_NAME" \
            --name "$filename" \
            --file "$script_file" \
            --output none
    fi
done

echo -e "${GREEN}✓ Scripts uploaded successfully${NC}"

# Generate SAS token for secure access (valid for 24 hours)
echo -e "${YELLOW}Generating SAS token for secure script access...${NC}"
EXPIRY_DATE=$(date -u -d "24 hours" '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+24H '+%Y-%m-%dT%H:%MZ' 2>/dev/null)
SAS_TOKEN=$(az storage container generate-sas \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --name "$CONTAINER_NAME" \
    --permissions r \
    --expiry "$EXPIRY_DATE" \
    --output tsv)

echo -e "${GREEN}✓ SAS token generated (valid for 24 hours)${NC}"

# Get blob URLs with SAS token
SETUP_ALL_URL="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${CONTAINER_NAME}/setup-all.ps1?${SAS_TOKEN}"
INSTALL_SQL_URL="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${CONTAINER_NAME}/install-sql-server.ps1?${SAS_TOKEN}"
SETUP_DATABASES_URL="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${CONTAINER_NAME}/setup-databases.ps1?${SAS_TOKEN}"
SETUP_LINKED_URL="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${CONTAINER_NAME}/setup-linked-servers.ps1?${SAS_TOKEN}"
DEPLOY_APP_URL="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${CONTAINER_NAME}/deploy-application.ps1?${SAS_TOKEN}"

# Install Custom Script Extension
echo -e "${YELLOW}Installing Custom Script Extension...${NC}"
# Note: Using Bypass instead of Unrestricted for better security
az vm extension set \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension \
    --publisher Microsoft.Compute \
    --version 1.10 \
    --protected-settings "{\"fileUris\":[\"$SETUP_ALL_URL\",\"$INSTALL_SQL_URL\",\"$SETUP_DATABASES_URL\",\"$SETUP_LINKED_URL\",\"$DEPLOY_APP_URL\"],\"commandToExecute\":\"powershell -ExecutionPolicy Bypass -Command \\\"\\\$env:AUTOMATION_MODE='true'; & .\\\\setup-all.ps1\\\"\"}" \
    --output none

echo -e "${GREEN}✓ Custom Script Extension installed${NC}"

echo ""
echo "=================================================="
echo "  VM Deployment Successful!"
echo "=================================================="
echo "VM Name: ${VM_NAME}"
echo "Public IP: ${PUBLIC_IP}"
echo "RDP Access: ${PUBLIC_IP}:3389"
echo "Username: ${ADMIN_USERNAME}"
echo "Storage Account: ${STORAGE_ACCOUNT_NAME}"
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
echo "Once complete, access the application at:"
echo "  http://${PUBLIC_IP}:8080"
echo ""
echo "=================================================="
echo ""
echo -e "${GREEN}Deployment complete! Setup is running automatically.${NC}"
