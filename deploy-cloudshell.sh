#!/bin/bash
# ============================================================================
# Azure Sentinel Cloud Shell Deployment Script
# Run this directly in Azure Cloud Shell - no setup required!
# ============================================================================

echo "🚀 AZURE SENTINEL CLOUD SHELL DEPLOYMENT"
echo "========================================"
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

# Check if we're in Cloud Shell
if [[ -z "${CLOUDSHELL}" ]]; then
    print_warning "This script is optimized for Azure Cloud Shell"
    print_info "You can also run it locally if Azure CLI is installed"
fi

print_status "Running in Azure Cloud Shell - all tools pre-installed!"
echo ""

# Get user inputs
print_info "Please provide the following information:"
echo ""

read -p "📁 Resource Group Name (required): " RESOURCE_GROUP
while [[ -z "$RESOURCE_GROUP" ]]; do
    print_error "Resource Group name is required!"
    read -p "📁 Resource Group Name: " RESOURCE_GROUP
done

echo ""
echo "📍 Select Azure Region:"
echo "   [1] East US        [6] North Europe"
echo "   [2] East US 2      [7] West Europe"
echo "   [3] West US        [8] UK South"
echo "   [4] West US 2      [9] Australia East"
echo "   [5] Central US    [10] Southeast Asia"
echo ""

read -p "Select location [1-10] (default: 1): " LOCATION_CHOICE
LOCATION_CHOICE=${LOCATION_CHOICE:-1}

case $LOCATION_CHOICE in
    1) LOCATION="eastus" ;;
    2) LOCATION="eastus2" ;;
    3) LOCATION="westus" ;;
    4) LOCATION="westus2" ;;
    5) LOCATION="centralus" ;;
    6) LOCATION="northeurope" ;;
    7) LOCATION="westeurope" ;;
    8) LOCATION="uksouth" ;;
    9) LOCATION="australiaeast" ;;
    10) LOCATION="southeastasia" ;;
    *) LOCATION="eastus" ;;
esac

read -p "🏢 Workspace Name (press Enter for auto-generated): " WORKSPACE_NAME
WORKSPACE_NAME=${WORKSPACE_NAME:-"sentinel-ws-$(date +%Y%m%d%H%M)"}

echo ""
print_info "DEPLOYMENT CONFIGURATION:"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   Location: $LOCATION"
echo "   Workspace: $WORKSPACE_NAME"
echo "   Pricing: PerGB2018 (Pay-per-GB)"
echo ""

read -p "🚀 Proceed with deployment? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_info "Deployment cancelled"
    exit 0
fi

echo ""
print_info "Starting deployment process..."

# Download the Bicep template directly from GitHub
print_info "Downloading Bicep templates..."
REPO_URL="https://raw.githubusercontent.com/sh4d0wl0ck/CYSent/main"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Download files
curl -s -o main.bicep "$REPO_URL/main.bicep"
mkdir -p modules
curl -s -o modules/sentinel.bicep "$REPO_URL/modules/sentinel.bicep"

if [[ ! -f "main.bicep" ]]; then
    print_error "Failed to download Bicep templates. Please check the repository URL."
    exit 1
fi

print_status "Templates downloaded successfully"

# Register required resource providers
print_info "Registering Azure resource providers..."
PROVIDERS=("Microsoft.OperationalInsights" "Microsoft.SecurityInsights" "Microsoft.OperationsManagement" "Microsoft.Security" "Microsoft.Automation")

for provider in "${PROVIDERS[@]}"; do
    print_info "Registering $provider..."
    az provider register --namespace "$provider" --output none
done

print_status "Resource providers registration initiated"

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
SUBSCRIPTION_NAME=$(az account show --query "name" --output tsv)

print_info "Using subscription: $SUBSCRIPTION_NAME"

# Deploy using Bicep
print_info "Deploying Microsoft Sentinel..."
DEPLOYMENT_NAME="sentinel-cloudshell-$(date +%Y%m%d%H%M%S)"

az deployment sub create \
    --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters \
        createNewSubscription=false \
        existingSubscriptionId="$SUBSCRIPTION_ID" \
        resourceGroupName="$RESOURCE_GROUP" \
        location="$LOCATION" \
        workspaceName="$WORKSPACE_NAME" \
        dataRetentionDays=30 \
        enableSentinel=true \
    --output table

if [[ $? -eq 0 ]]; then
    echo ""
    print_status "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo ""
    print_info "📊 RESOURCES CREATED:"
    echo "   ✅ Resource Group: $RESOURCE_GROUP"
    echo "   ✅ Log Analytics Workspace: $WORKSPACE_NAME"
    echo "   ✅ Microsoft Sentinel: Enabled"
    echo "   ✅ Pricing Tier: PerGB2018"
    echo ""
    print_info "🔗 ACCESS LINKS:"
    echo "   🛡️  Sentinel Portal: https://portal.azure.com/#view/Microsoft_Azure_Security_Insights"
    echo "   📋 Resource Group: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
    echo ""
    print_info "📋 NEXT STEPS:"
    echo "   1. Configure data connectors (Azure Activity, Security Center)"
    echo "   2. Enable additional analytics rules"
    echo "   3. Set up automated incident response"
    echo "   4. Create custom workbooks for monitoring"
    echo ""
    print_status "Microsoft Sentinel is ready to use! 🛡️"
else
    print_error "Deployment failed. Check the error messages above."
    exit 1
fi

# Cleanup
cd ~
rm -rf $TEMP_DIR

print_info "Temporary files cleaned up"
echo ""
print_status "Deployment script completed!"
