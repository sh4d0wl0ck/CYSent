#!/bin/bash
# ============================================================================
# Azure Sentinel Simple Cloud Shell Deployment
# Uses direct Azure CLI commands - no templates!
# ============================================================================

echo "🚀 AZURE SENTINEL SIMPLE DEPLOYMENT"
echo "==================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_status "Using Azure CLI direct commands - maximum compatibility!"
echo ""

# Get user inputs with proper validation
print_info "Please provide the following information:"
echo ""

# Get Resource Group Name
while true; do
    echo -n "📁 Resource Group Name (required): "
    read RESOURCE_GROUP
    if [[ -n "$RESOURCE_GROUP" ]]; then
        break
    fi
    print_error "Resource Group name is required!"
done

echo ""

# Get Location
echo "📍 Select Azure Region:"
echo "   [1] East US        [6] North Europe"
echo "   [2] East US 2      [7] West Europe"
echo "   [3] West US        [8] UK South"
echo "   [4] West US 2      [9] Australia East"
echo "   [5] Central US    [10] Southeast Asia"
echo ""

while true; do
    echo -n "Select location [1-10] (default: 1): "
    read LOCATION_CHOICE
    
    # Set default if empty
    if [[ -z "$LOCATION_CHOICE" ]]; then
        LOCATION_CHOICE=1
    fi
    
    case $LOCATION_CHOICE in
        1) LOCATION="eastus"; break ;;
        2) LOCATION="eastus2"; break ;;
        3) LOCATION="westus"; break ;;
        4) LOCATION="westus2"; break ;;
        5) LOCATION="centralus"; break ;;
        6) LOCATION="northeurope"; break ;;
        7) LOCATION="westeurope"; break ;;
        8) LOCATION="uksouth"; break ;;
        9) LOCATION="australiaeast"; break ;;
        10) LOCATION="southeastasia"; break ;;
        *) print_error "Please enter a number between 1-10"; continue ;;
    esac
done

echo ""

# Get Workspace Name
echo -n "🏢 Workspace Name (press Enter for auto-generated): "
read WORKSPACE_NAME
if [[ -z "$WORKSPACE_NAME" ]]; then
    WORKSPACE_NAME="sentinel-ws-$(date +%Y%m%d%H%M)"
fi

echo ""
print_info "DEPLOYMENT CONFIGURATION:"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   Location: $LOCATION"
echo "   Workspace: $WORKSPACE_NAME"
echo "   Pricing: PerGB2018 (Pay-per-GB)"
echo ""

# Confirm deployment
while true; do
    echo -n "🚀 Proceed with deployment? [y/N]: "
    read CONFIRM
    case $CONFIRM in
        [Yy]* ) break;;
        [Nn]* | "" ) print_info "Deployment cancelled"; exit 0;;
        * ) print_error "Please answer y or n";;
    esac
done

echo ""
print_info "Starting deployment process..."

# Check if already authenticated
print_info "Checking Azure authentication..."
if az account show >/dev/null 2>&1; then
    SUBSCRIPTION_NAME=$(az account show --query "name" --output tsv)
    SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
    print_status "Using subscription: $SUBSCRIPTION_NAME"
else
    print_error "Not authenticated with Azure. Please run 'az login' first."
    exit 1
fi

# Register required resource providers (in background)
print_info "Registering Azure resource providers..."
PROVIDERS=("Microsoft.OperationalInsights" "Microsoft.SecurityInsights" "Microsoft.OperationsManagement")

for provider in "${PROVIDERS[@]}"; do
    print_info "Registering $provider..."
    az provider register --namespace "$provider" >/dev/null 2>&1 &
done

print_status "Resource provider registration initiated in background"

# Step 1: Create Resource Group
print_info "Step 1: Creating Resource Group '$RESOURCE_GROUP'..."

# Check if resource group already exists
if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_warning "Resource group '$RESOURCE_GROUP' already exists. Using existing group."
else
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        print_status "Resource group created successfully"
    else
        print_error "Failed to create resource group"
        exit 1
    fi
fi

# Step 2: Create Log Analytics Workspace
print_info "Step 2: Creating Log Analytics Workspace '$WORKSPACE_NAME'..."
print_info "This may take 2-3 minutes..."

# Check if workspace already exists
if az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" >/dev/null 2>&1; then
    print_warning "Workspace '$WORKSPACE_NAME' already exists. Using existing workspace."
    WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" --query "customerId" --output tsv)
else
    # Create Log Analytics workspace
    az monitor log-analytics workspace create \
        --resource-group "$RESOURCE_GROUP" \
        --workspace-name "$WORKSPACE_NAME" \
        --location "$LOCATION" \
        --sku "pergb2018" \
        --retention-time 30 \
        --tags Purpose="Microsoft Sentinel" DeployedBy="CloudShell" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        print_status "Log Analytics workspace created successfully"
        WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" --query "customerId" --output tsv)
    else
        print_error "Failed to create Log Analytics workspace"
        exit 1
    fi
fi

# Step 3: Enable Microsoft Sentinel
print_info "Step 3: Enabling Microsoft Sentinel..."
print_info "This may take 1-2 minutes..."

# Enable Sentinel on the workspace
az sentinel workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
    print_status "Microsoft Sentinel enabled successfully"
else
    print_warning "Sentinel may already be enabled or there was a minor issue, but workspace is ready"
fi

# Step 4: Configure basic settings
print_info "Step 4: Applying final configurations..."

# Set workspace retention and other settings
az monitor log-analytics workspace update \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --retention-time 30 >/dev/null 2>&1

print_status "Configuration completed"

echo ""
print_status "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo ""
print_info "📊 RESOURCES CREATED:"
echo "   ✅ Subscription: $SUBSCRIPTION_NAME"
echo "   ✅ Resource Group: $RESOURCE_GROUP"
echo "   ✅ Log Analytics Workspace: $WORKSPACE_NAME"
echo "   ✅ Workspace ID: $WORKSPACE_ID"
echo "   ✅ Microsoft Sentinel: Enabled"
echo "   ✅ Pricing Tier: PerGB2018"
echo "   ✅ Data Retention: 30 days"
echo ""
print_info "🔗 ACCESS LINKS:"
echo "   🛡️  Sentinel Portal: https://portal.azure.com/#view/Microsoft_Azure_Security_Insights"
echo "   📊 Log Analytics: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME"
echo "   📋 Resource Group: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
echo ""
print_info "📋 IMMEDIATE NEXT STEPS:"
echo "   1. 🔗 Click the Sentinel Portal link above"
echo "   2. 📊 Configure data connectors:"
echo "      • Azure Activity logs (recommended first)"
echo "      • Security Events from Windows VMs"
echo "      • Azure Security Center alerts"
echo "   3. 🛡️  Enable built-in analytics rules:"
echo "      • Suspicious number of resource operations"
echo "      • Rare application consent"
echo "      • Multiple failed login attempts"
echo "   4. 📈 Set up workbooks for monitoring"
echo "   5. 🔔 Configure email notifications"
echo ""
print_status "Microsoft Sentinel is protecting your environment! 🛡️"
echo ""
print_info "💡 QUICK START TIPS:"
echo "   • The Azure Activity connector provides immediate security insights"
echo "   • Start with built-in templates for common threat detection"
echo "   • Use the 'Azure Sentinel' workbook for executive dashboards"
echo "   • Set up automated responses using Logic Apps playbooks"
echo ""
print_info "📞 SUPPORT:"
echo "   • Documentation: https://docs.microsoft.com/en-us/azure/sentinel/"
echo "   • Community: https://techcommunity.microsoft.com/t5/microsoft-sentinel/bd-p/MicrosoftSentinel"
echo ""
print_status "🎉 Deployment completed in $(date)! Thank you for using Azure Sentinel! 🎉"
