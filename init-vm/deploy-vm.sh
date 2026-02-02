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

echo ""
echo "=================================================="
echo "  VM Deployment Successful!"
echo "=================================================="
echo "VM Name: ${VM_NAME}"
echo "Public IP: ${PUBLIC_IP}"
echo "RDP Access: ${PUBLIC_IP}:3389"
echo "Username: ${ADMIN_USERNAME}"
echo ""
echo "=================================================="
echo "  Next Steps:"
echo "=================================================="
echo "1. Connect via RDP to: ${PUBLIC_IP}"
echo "2. Run the setup scripts in order:"
echo "   - scripts/install-sql-server.ps1"
echo "   - scripts/setup-databases.ps1"
echo "   - scripts/setup-linked-servers.ps1"
echo "   - scripts/deploy-application.ps1"
echo ""
echo "3. Or use Custom Script Extension to automate:"
echo ""
echo "   az vm extension set \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --vm-name $VM_NAME \\"
echo "     --name CustomScriptExtension \\"
echo "     --publisher Microsoft.Compute \\"
echo "     --settings '{\"fileUris\":[\"https://your-storage/scripts.zip\"],\"commandToExecute\":\"powershell -ExecutionPolicy Unrestricted -File setup-all.ps1\"}'"
echo ""
echo "=================================================="
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
