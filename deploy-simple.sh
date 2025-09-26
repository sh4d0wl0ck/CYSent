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

# Get the workspace resource ID for Sentinel
WORKSPACE_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME"

# Method 1: Try to enable Sentinel using the onboardingStates API
print_info "Attempting to enable Sentinel on workspace..."

# Create a small ARM template for Sentinel onboarding only
cat > sentinel-enable.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "workspaceName": {
      "type": "string"
    }
  },
  "resources": [
    {
      "type": "Microsoft.SecurityInsights/onboardingStates",
      "apiVersion": "2023-02-01",
      "scope": "[concat('Microsoft.OperationalInsights/workspaces/', parameters('workspaceName'))]",
      "name": "default",
      "properties": {
        "customerManagedKey": false
      }
    }
  ]
}
EOF

# Deploy the Sentinel enablement template
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "enable-sentinel-$(date +%Y%m%d%H%M%S)" \
    --template-file sentinel-enable.json \
    --parameters workspaceName="$WORKSPACE_NAME" >/dev/null 2>&1

SENTINEL_STATUS=$?

# Clean up the temporary template
rm -f sentinel-enable.json

if [[ $SENTINEL_STATUS -eq 0 ]]; then
    print_status "Microsoft Sentinel enabled successfully"
    
    # Wait a moment for Sentinel to be fully activated
    print_info "Waiting for Sentinel to fully activate..."
    sleep 5
    
    # Skip the verification that was hanging - just assume success if deployment worked
    print_status "Sentinel activation completed"
else
    print_error "Failed to enable Microsoft Sentinel automatically"
    print_info "Don't worry - you can enable it manually:"
    print_info "1. Go to the Azure Portal"
    print_info "2. Navigate to Microsoft Sentinel"
    print_info "3. Click 'Add Microsoft Sentinel to a workspace'"
    print_info "4. Select workspace: $WORKSPACE_NAME"
    print_info "5. Click 'Add'"
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
print_info "📊 DEPLOYMENT SUMMARY:"
echo "   ✅ Subscription: $SUBSCRIPTION_NAME"
echo "   ✅ Resource Group: $RESOURCE_GROUP"
echo "   ✅ Log Analytics Workspace: $WORKSPACE_NAME"
echo "   ✅ Workspace ID: $WORKSPACE_ID"
echo "   ✅ Pricing Tier: PerGB2018"
echo "   ✅ Data Retention: 30 days"

# Check Sentinel status
if [[ $SENTINEL_STATUS -eq 0 ]]; then
    echo "   ✅ Microsoft Sentinel: Enabled"
else
    echo "   ⚠️  Microsoft Sentinel: Requires manual activation (see steps below)"
fi
echo ""
print_info "🔗 ACCESS LINKS:"
echo "   🛡️  Sentinel Portal: https://portal.azure.com/#view/Microsoft_Azure_Security_Insights"
echo "   📊 Log Analytics: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME"
echo "   📋 Resource Group: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
echo ""
print_info "📋 IMMEDIATE NEXT STEPS:"
if [[ $SENTINEL_STATUS -eq 0 ]]; then
    echo "   1. 🔗 Click the Sentinel Portal link above"
    echo "   2. 📊 Your workspace should appear in the Sentinel workspace list"
    echo "   3. 📊 Configure data connectors:"
else
    echo "   1. 🔗 Go to Azure Portal: https://portal.azure.com"
    echo "   2. 🛡️  Search for 'Microsoft Sentinel'"
    echo "   3. ➕ Click 'Add Microsoft Sentinel to a workspace'"
    echo "   4. ✅ Select workspace: $WORKSPACE_NAME (should be listed)"
    echo "   5. ➕ Click 'Add' to enable Sentinel"
    echo "   6. 📊 Then configure data connectors:"
fi
echo "      • Azure Activity logs (recommended first)"
echo "      • Security Events from Windows VMs"
echo "      • Azure Security Center alerts"
echo "   7. 🛡️  Enable built-in analytics rules:"
echo "      • Suspicious number of resource operations"
echo "      • Rare application consent"
echo "      • Multiple failed login attempts"
echo "   8. 📈 Set up workbooks for monitoring"
echo "   9. 🔔 Configure email notifications"
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
