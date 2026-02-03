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

# Construct GitHub raw URLs for scripts
# Use main branch as the default, scripts will be fetched from GitHub
GITHUB_BASE_URL="https://raw.githubusercontent.com/CZSK-MicroHacks/MicroHack-ModernizeInfra/main/init-vm/scripts"
SETUP_ALL_URL="${GITHUB_BASE_URL}/setup-all.ps1"
INSTALL_SQL_URL="${GITHUB_BASE_URL}/install-sql-server.ps1"
SETUP_DATABASES_URL="${GITHUB_BASE_URL}/setup-databases.ps1"
SETUP_LINKED_URL="${GITHUB_BASE_URL}/setup-linked-servers.ps1"
DEPLOY_APP_URL="${GITHUB_BASE_URL}/deploy-application.ps1"

# Install Custom Script Extension with public GitHub URLs
echo -e "${YELLOW}Installing Custom Script Extension...${NC}"
# Note: Using Bypass instead of Unrestricted for better security
# The scripts will be downloaded from public GitHub repository
az vm extension set \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension \
    --publisher Microsoft.Compute \
    --version 1.10 \
    --settings "{\"fileUris\":[\"$SETUP_ALL_URL\",\"$INSTALL_SQL_URL\",\"$SETUP_DATABASES_URL\",\"$SETUP_LINKED_URL\",\"$DEPLOY_APP_URL\"]}" \
    --protected-settings "{\"commandToExecute\":\"powershell -ExecutionPolicy Bypass -Command \\\"\$env:AUTOMATION_MODE='true'; & .\\\\setup-all.ps1\\\"\"}" \
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
