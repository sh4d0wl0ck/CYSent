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

# Register required resource providers
print_info "Registering Azure resource providers (this may take a few minutes)..."
PROVIDERS=("Microsoft.OperationalInsights" "Microsoft.SecurityInsights" "Microsoft.OperationsManagement" "Microsoft.Security" "Microsoft.Automation")

for provider in "${PROVIDERS[@]}"; do
    print_info "Registering $provider..."
    az provider register --namespace "$provider" --output none
    if [[ $? -eq 0 ]]; then
        print_status "$provider registration initiated"
    else
        print_warning "Failed to register $provider (may already be registered)"
    fi
done

print_status "Resource provider registration completed"

# Create ARM template inline for maximum compatibility
print_info "Creating deployment template..."

cat > template.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourceGroupName": {
      "type": "string",
      "metadata": {
        "description": "Name of the resource group"
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "eastus",
      "metadata": {
        "description": "Location for resources"
      }
    },
    "workspaceName": {
      "type": "string",
      "metadata": {
        "description": "Name of the Log Analytics workspace"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.Resources/resourceGroups",
      "apiVersion": "2021-04-01",
      "name": "[parameters('resourceGroupName')]",
      "location": "[parameters('location')]",
      "tags": {
        "Purpose": "Microsoft Sentinel",
        "DeployedBy": "CloudShell"
      }
    },
    {
      "type": "Microsoft.Resources/deployments",
      "apiVersion": "2021-04-01",
      "name": "sentinel-resources",
      "resourceGroup": "[parameters('resourceGroupName')]",
      "dependsOn": [
        "[resourceId('Microsoft.Resources/resourceGroups', parameters('resourceGroupName'))]"
      ],
      "properties": {
        "mode": "Incremental",
        "template": {
          "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
          "contentVersion": "1.0.0.0",
          "parameters": {
            "workspaceName": {
              "type": "string"
            },
            "location": {
              "type": "string"
            }
          },
          "resources": [
            {
              "type": "Microsoft.OperationalInsights/workspaces",
              "apiVersion": "2022-10-01",
              "name": "[parameters('workspaceName')]",
              "location": "[parameters('location')]",
              "properties": {
                "sku": {
                  "name": "PerGB2018"
                },
                "retentionInDays": 30,
                "features": {
                  "enableLogAccessUsingOnlyResourcePermissions": true
                },
                "workspaceCapping": {
                  "dailyQuotaGb": -1
                },
                "publicNetworkAccessForIngestion": "Enabled",
                "publicNetworkAccessForQuery": "Enabled"
              },
              "tags": {
                "Purpose": "Microsoft Sentinel"
              }
            },
            {
              "type": "Microsoft.SecurityInsights/onboardingStates",
              "apiVersion": "2023-02-01",
              "scope": "[concat('Microsoft.OperationalInsights/workspaces/', parameters('workspaceName'))]",
              "name": "default",
              "dependsOn": [
                "[resourceId('Microsoft.OperationalInsights/workspaces', parameters('workspaceName'))]"
              ],
              "properties": {
                "customerManagedKey": false
              }
            }
          ],
          "outputs": {
            "workspaceId": {
              "type": "string",
              "value": "[reference(resourceId('Microsoft.OperationalInsights/workspaces', parameters('workspaceName'))).customerId]"
            }
          }
        },
        "parameters": {
          "workspaceName": {
            "value": "[parameters('workspaceName')]"
          },
          "location": {
            "value": "[parameters('location')]"
          }
        }
      }
    }
  ],
  "outputs": {
    "resourceGroupName": {
      "type": "string",
      "value": "[parameters('resourceGroupName')]"
    },
    "workspaceName": {
      "type": "string",
      "value": "[parameters('workspaceName')]"
    },
    "subscriptionId": {
      "type": "string",
      "value": "[subscription().subscriptionId]"
    },
    "sentinelUrl": {
      "type": "string",
      "value": "[concat('https://portal.azure.com/#view/Microsoft_Azure_Security_Insights/MainMenuBlade/~/0/subscriptionId/', subscription().subscriptionId, '/resourceGroup/', parameters('resourceGroupName'))]"
    }
  }
}
EOF

print_status "ARM template created successfully"

# Deploy using ARM template
print_info "Deploying Microsoft Sentinel..."
DEPLOYMENT_NAME="sentinel-cloudshell-$(date +%Y%m%d%H%M%S)"

print_info "Starting deployment: $DEPLOYMENT_NAME"
print_info "This may take 5-10 minutes..."

# Deploy to subscription scope using ARM template
az deployment sub create \
    --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file template.json \
    --parameters \
        resourceGroupName="$RESOURCE_GROUP" \
        location="$LOCATION" \
        workspaceName="$WORKSPACE_NAME" \
    --output table

DEPLOYMENT_STATUS=$?

echo ""

if [[ $DEPLOYMENT_STATUS -eq 0 ]]; then
    print_status "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo ""
    print_info "📊 RESOURCES CREATED:"
    echo "   ✅ Subscription: $SUBSCRIPTION_NAME"
    echo "   ✅ Resource Group: $RESOURCE_GROUP"
    echo "   ✅ Log Analytics Workspace: $WORKSPACE_NAME"
    echo "   ✅ Microsoft Sentinel: Enabled"
    echo "   ✅ Pricing Tier: PerGB2018"
    echo ""
    print_info "🔗 ACCESS LINKS:"
    echo "   🛡️  Sentinel Portal: https://portal.azure.com/#view/Microsoft_Azure_Security_Insights"
    echo "   📋 Resource Group: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
    echo ""
    print_info "📋 IMMEDIATE NEXT STEPS:"
    echo "   1. 🔗 Click the Sentinel Portal link above"
    echo "   2. 📊 Configure data connectors (Azure Activity, Security Events)"
    echo "   3. 🛡️  Enable built-in analytics rules"
    echo "   4. 📈 Set up workbooks for monitoring"
    echo ""
    print_status "Microsoft Sentinel is ready to protect your environment! 🛡️"
    echo ""
    print_info "💡 QUICK START TIPS:"
    echo "   • Start with Azure Activity logs connector for immediate insights"
    echo "   • Enable 'Suspicious number of resource creation or deployment activities' rule"
    echo "   • Use the Azure Sentinel workbook for overview dashboards"
    echo "   • Set up email notifications for high-priority incidents"
else
    print_error "Deployment failed. Please check the error messages above."
    echo ""
    print_info "🔧 TROUBLESHOOTING TIPS:"
    echo "   • Check if you have sufficient permissions"
    echo "   • Ensure the resource group name doesn't already exist"
    echo "   • Try a different Azure region if the current one has capacity issues"
    echo "   • Resource providers may still be registering - wait 5 minutes and retry"
    exit 1
fi

# Cleanup temporary files
rm -f template.json

print_info "Temporary files cleaned up"
echo ""
print_status "🎉 Cloud Shell deployment completed successfully! 🎉"
echo ""
echo "Thank you for using the Azure Sentinel Cloud Shell deployment! 🚀"
