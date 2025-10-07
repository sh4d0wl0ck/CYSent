#!/bin/bash

# Deploy Azure Resource Group with Log Analytics and Sentinel using Azure CLI
# This script creates a new resource group and deploys security monitoring resources

# Set script parameters with defaults
SUBSCRIPTION_NAME=""
SUBSCRIPTION_ID=""
RESOURCE_GROUP_NAME=""
RESOURCE_GROUP_DESCRIPTION="Resource group for security monitoring, Log Analytics workspace, and Microsoft Sentinel"
LOG_ANALYTICS_WORKSPACE_NAME=""
LOCATION=""
LOG_ANALYTICS_SKU="PerGB2018"
DATA_RETENTION_DAYS=90
ENABLE_RESOURCE_GROUP_LOCK=true
RESOURCE_GROUP_LOCK_TYPE="CanNotDelete"
TEMPLATE_FILE="main.bicep"

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script will interactively prompt for subscription selection if not provided."
    echo ""
    echo "Required Options:"
    echo "  -s, --subscription-name NAME        Name for the subscription reference"
    echo "  -i, --subscription-id ID            Azure subscription ID to deploy to"
    echo "  -g, --resource-group NAME           Name for the new resource group to be created"
    echo "  -w, --workspace-name NAME           Name for the Log Analytics workspace"
    echo "  -l, --location LOCATION             Azure region (e.g., eastus, westus2)"
    echo ""
    echo "Optional Parameters:"
    echo "  -d, --description TEXT              Resource group description"
    echo "  --sku SKU                          Log Analytics SKU (Free, Standalone, PerNode, PerGB2018)"
    echo "  --retention DAYS                   Data retention days (30-730)"
    echo "  --no-lock                          Disable resource group lock"
    echo "  --lock-type TYPE                   Lock type (ReadOnly, CanNotDelete)"
    echo "  --template-file FILE               Bicep template file path"
    echo "  --non-interactive                  Skip subscription selection prompt"
    echo "  -h, --help                         Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Interactive mode (recommended):"
    echo "  $0"
    echo ""
    echo "  # With parameters:"
    echo "  $0 -s \"MyCompany-Security\" -g \"rg-security-prod\" -w \"law-security-prod\" -l \"eastus\""
    echo ""
    echo "  # Specify subscription ID:"
    echo "  $0 -i \"12345678-1234-1234-1234-123456789012\" -g \"rg-security\" -w \"law-security\" -l \"eastus\""
}

# Function to validate resource group name
validate_resource_group_name() {
    local name="$1"
    
    # Check length
    if [[ ${#name} -lt 1 || ${#name} -gt 90 ]]; then
        echo "❌ Error: Resource group name must be 1-90 characters long"
        return 1
    fi
    
    # Check valid characters
    if [[ ! "$name" =~ ^[a-zA-Z0-9._\(\)-]+$ ]]; then
        echo "❌ Error: Resource group name contains invalid characters"
        echo "   Valid characters: alphanumeric, periods, underscores, hyphens, parentheses"
        return 1
    fi
    
    # Check doesn't end with period
    if [[ "$name" =~ \.$ ]]; then
        echo "❌ Error: Resource group name cannot end with a period"
        return 1
    fi
    
    return 0
}

# Function to check if resource group exists
check_resource_group_exists() {
    local rg_name="$1"
    az group show --name "$rg_name" --query "name" -o tsv 2>/dev/null
}

# Function to list available subscriptions
list_subscriptions() {
    echo "📋 Available Azure Subscriptions:"
    echo ""
    az account list --query "[].{Number:name, SubscriptionId:id, State:state}" -o table
}

# Function to select subscription interactively
select_subscription_interactive() {
    echo "🔍 Fetching your Azure subscriptions..."
    echo ""
    
    # Get subscriptions as JSON
    local subs_json=$(az account list --query "[?state=='Enabled']" -o json)
    
    # Check if any subscriptions found
    local sub_count=$(echo "$subs_json" | jq 'length')
    
    if [[ "$sub_count" -eq 0 ]]; then
        echo "❌ No enabled Azure subscriptions found."
        echo "   Please check your Azure access or login again."
        exit 1
    fi
    
    # Display subscriptions with numbers
    echo "Available Subscriptions:"
    echo "------------------------"
    local i=1
    while IFS= read -r line; do
        local sub_name=$(echo "$line" | jq -r '.name')
        local sub_id=$(echo "$line" | jq -r '.id')
        local is_default=$(echo "$line" | jq -r '.isDefault')
        
        if [[ "$is_default" == "true" ]]; then
            echo "  $i) $sub_name"
            echo "     ID: $sub_id [CURRENT]"
        else
            echo "  $i) $sub_name"
            echo "     ID: $sub_id"
        fi
        echo ""
        ((i++))
    done < <(echo "$subs_json" | jq -c '.[]')
    
    # Prompt user to select
    echo ""
    read -p "Select subscription number (1-$sub_count) or press Enter for current: " selection
    
    # If empty, use current/default subscription
    if [[ -z "$selection" ]]; then
        local default_sub=$(az account show --query "{name:name, id:id}" -o json)
        SUBSCRIPTION_NAME=$(echo "$default_sub" | jq -r '.name')
        SUBSCRIPTION_ID=$(echo "$default_sub" | jq -r '.id')
        echo "✅ Using current subscription: $SUBSCRIPTION_NAME"
        return 0
    fi
    
    # Validate selection is a number
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "$sub_count" ]]; then
        echo "❌ Invalid selection. Please run the script again."
        exit 1
    fi
    
    # Get selected subscription
    local selected_sub=$(echo "$subs_json" | jq -r ".[$((selection-1))]")
    SUBSCRIPTION_NAME=$(echo "$selected_sub" | jq -r '.name')
    SUBSCRIPTION_ID=$(echo "$selected_sub" | jq -r '.id')
    
    # Set the selected subscription as active
    echo ""
    echo "🔄 Setting active subscription to: $SUBSCRIPTION_NAME"
    az account set --subscription "$SUBSCRIPTION_ID"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Successfully switched to subscription: $SUBSCRIPTION_NAME"
    else
        echo "❌ Failed to switch subscription"
        exit 1
    fi
}

# Function to prompt for deployment parameters
prompt_for_parameters() {
    echo ""
    echo "📝 Please provide deployment parameters:"
    echo ""
    
    # Resource Group Name
    if [[ -z "$RESOURCE_GROUP_NAME" ]]; then
        read -p "Resource Group Name: " RESOURCE_GROUP_NAME
        if ! validate_resource_group_name "$RESOURCE_GROUP_NAME"; then
            exit 1
        fi
    fi
    
    # Log Analytics Workspace Name
    if [[ -z "$LOG_ANALYTICS_WORKSPACE_NAME" ]]; then
        read -p "Log Analytics Workspace Name: " LOG_ANALYTICS_WORKSPACE_NAME
    fi
    
    # Location
    if [[ -z "$LOCATION" ]]; then
        echo ""
        echo "Common Azure Regions:"
        echo "  - eastus, eastus2, westus, westus2, centralus"
        echo "  - northeurope, westeurope, uksouth"
        echo "  - southeastasia, eastasia, australiaeast"
        read -p "Azure Region: " LOCATION
    fi
    
    # Subscription Name (if not set)
    if [[ -z "$SUBSCRIPTION_NAME" ]]; then
        SUBSCRIPTION_NAME="Deployment-$(date +%Y%m%d)"
    fi
}

# Parse command line arguments
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subscription-name)
            SUBSCRIPTION_NAME="$2"
            shift 2
            ;;
        -i|--subscription-id)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP_NAME="$2"
            shift 2
            ;;
        -w|--workspace-name)
            LOG_ANALYTICS_WORKSPACE_NAME="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -d|--description)
            RESOURCE_GROUP_DESCRIPTION="$2"
            shift 2
            ;;
        --sku)
            LOG_ANALYTICS_SKU="$2"
            shift 2
            ;;
        --retention)
            DATA_RETENTION_DAYS="$2"
            shift 2
            ;;
        --no-lock)
            ENABLE_RESOURCE_GROUP_LOCK=false
            shift
            ;;
        --lock-type)
            RESOURCE_GROUP_LOCK_TYPE="$2"
            shift 2
            ;;
        --template-file)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "❌ Unknown parameter: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if user is logged into Azure
echo "🔍 Checking Azure CLI login status..."
if ! az account show >/dev/null 2>&1; then
    echo "❌ Please log in to Azure CLI first:"
    echo "   az login"
    exit 1
fi

echo "✅ Azure CLI authenticated"
echo ""

# Interactive subscription selection if not provided
if [[ -z "$SUBSCRIPTION_ID" && "$NON_INTERACTIVE" == "false" ]]; then
    select_subscription_interactive
elif [[ -n "$SUBSCRIPTION_ID" ]]; then
    # Use provided subscription ID
    echo "🔄 Setting subscription to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
    
    if [[ $? -eq 0 ]]; then
        CURRENT_SUB=$(az account show --query "{name:name, id:id}" -o json)
        SUBSCRIPTION_NAME=$(echo "$CURRENT_SUB" | jq -r '.name')
        echo "✅ Successfully set subscription: $SUBSCRIPTION_NAME"
    else
        echo "❌ Failed to set subscription"
        exit 1
    fi
else
    # Non-interactive mode, use current subscription
    CURRENT_SUB=$(az account show --query "{name:name, id:id}" -o json)
    SUBSCRIPTION_NAME=$(echo "$CURRENT_SUB" | jq -r '.name')
    SUBSCRIPTION_ID=$(echo "$CURRENT_SUB" | jq -r '.id')
fi

# Prompt for parameters if not provided and not in non-interactive mode
if [[ "$NON_INTERACTIVE" == "false" ]]; then
    if [[ -z "$RESOURCE_GROUP_NAME" || -z "$LOG_ANALYTICS_WORKSPACE_NAME" || -z "$LOCATION" ]]; then
        prompt_for_parameters
    fi
fi

# Validate required parameters
if [[ -z "$RESOURCE_GROUP_NAME" || -z "$LOG_ANALYTICS_WORKSPACE_NAME" || -z "$LOCATION" ]]; then
    echo "❌ Error: Missing required parameters"
    echo ""
    echo "Required parameters:"
    echo "  - Resource Group Name: $RESOURCE_GROUP_NAME"
    echo "  - Log Analytics Workspace Name: $LOG_ANALYTICS_WORKSPACE_NAME"
    echo "  - Location: $LOCATION"
    echo ""
    usage
    exit 1
fi

# Validate resource group name
if ! validate_resource_group_name "$RESOURCE_GROUP_NAME"; then
    exit 1
fi

# Check if user is logged into Azure
echo "🔍 Checking Azure CLI login status..."
if ! az account show >/dev/null 2>&1; then
    echo "❌ Please log in to Azure CLI first:"
    echo "   az login"
    exit 1
fi

# Get current subscription information
CURRENT_SUBSCRIPTION=$(az account show --query "{name:name, id:id}" -o json)
CURRENT_SUB_NAME=$(echo "$CURRENT_SUBSCRIPTION" | jq -r '.name')
CURRENT_SUB_ID=$(echo "$CURRENT_SUBSCRIPTION" | jq -r '.id')

# Generate deployment name
DEPLOYMENT_NAME="create-rg-security-setup-$(date +%Y%m%d-%H%M%S)"

echo "======================================="
echo "  AZURE RESOURCE GROUP CREATION SCRIPT"
echo "======================================="
echo ""
echo "Target Subscription: $CURRENT_SUB_NAME ($CURRENT_SUB_ID)"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo ""
echo "RESOURCES TO BE CREATED:"
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ 1. NEW RESOURCE GROUP: $RESOURCE_GROUP_NAME"
echo "│    Description: $RESOURCE_GROUP_DESCRIPTION"
echo "│    Location: $LOCATION"
echo "│    Lock Enabled: $ENABLE_RESOURCE_GROUP_LOCK ($RESOURCE_GROUP_LOCK_TYPE)"
echo "│"
echo "│ 2. LOG ANALYTICS WORKSPACE: $LOG_ANALYTICS_WORKSPACE_NAME"
echo "│    SKU: $LOG_ANALYTICS_SKU"
echo "│    Data Retention: $DATA_RETENTION_DAYS days"
echo "│"
echo "│ 3. MICROSOFT SENTINEL"
echo "│    Enabled on the Log Analytics workspace"
echo "│    Basic data connectors will be configured"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# Confirm deployment
read -p "Do you want to proceed with creating these resources? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled by user."
    exit 0
fi

# Check if resource group already exists
echo ""
echo "🔍 Checking if resource group exists..."
EXISTING_RG=$(check_resource_group_exists "$RESOURCE_GROUP_NAME")

if [[ -n "$EXISTING_RG" ]]; then
    echo "⚠️  WARNING: Resource Group '$RESOURCE_GROUP_NAME' already exists!"
    
    # Get existing resource group details
    EXISTING_RG_INFO=$(az group show --name "$RESOURCE_GROUP_NAME" --query "{location:location, id:id}" -o json)
    EXISTING_LOCATION=$(echo "$EXISTING_RG_INFO" | jq -r '.location')
    
    echo "   Current Location: $EXISTING_LOCATION"
    echo ""
    read -p "Do you want to continue and potentially modify existing resources? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled to protect existing resources."
        exit 0
    fi
    echo "Proceeding with existing resource group..."
else
    echo "✅ Resource group does not exist. Will create new resource group."
fi

# Create resource group tags
TAGS="Environment=Security Purpose='Log Analytics and Sentinel' CreatedBy='Azure CLI Script' Owner=$USER Department='IT Security'"

# Start deployment
echo ""
echo "🚀 Starting deployment..."
echo "This may take several minutes..."

# Deploy using Azure CLI
DEPLOYMENT_RESULT=$(az deployment sub create \
    --name "$DEPLOYMENT_NAME" \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
        subscriptionName="$SUBSCRIPTION_NAME" \
        resourceGroupName="$RESOURCE_GROUP_NAME" \
        resourceGroupDescription="$RESOURCE_GROUP_DESCRIPTION" \
        logAnalyticsWorkspaceName="$LOG_ANALYTICS_WORKSPACE_NAME" \
        location="$LOCATION" \
        logAnalyticsSku="$LOG_ANALYTICS_SKU" \
        dataRetentionDays="$DATA_RETENTION_DAYS" \
        enableResourceGroupLock="$ENABLE_RESOURCE_GROUP_LOCK" \
        resourceGroupLockType="$RESOURCE_GROUP_LOCK_TYPE" \
    --query "{provisioningState:properties.provisioningState, outputs:properties.outputs}" \
    -o json)

# Check deployment result
PROVISIONING_STATE=$(echo "$DEPLOYMENT_RESULT" | jq -r '.provisioningState')

if [[ "$PROVISIONING_STATE" == "Succeeded" ]]; then
    echo ""
    echo "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo "======================================"
    echo ""
    echo "CREATED RESOURCES:"
    
    # Display outputs
    OUTPUTS=$(echo "$DEPLOYMENT_RESULT" | jq -r '.outputs')
    echo "$OUTPUTS" | jq -r 'to_entries[] | "  \(.key): \(.value.value)"'
    
    echo ""
    echo "NEXT STEPS:"
    echo "1. 📊 Configure additional data connectors in Microsoft Sentinel"
    echo "2. 📋 Set up analytics rules and workbooks for threat detection"
    echo "3. 🤖 Configure automation and incident response playbooks"  
    echo "4. 📈 Review and adjust data retention policies as needed"
    echo "5. 👥 Set up proper RBAC permissions for your security team"
    echo "6. 🔔 Configure alerting and notification preferences"
    
    # Display resource group information
    echo ""
    echo "RESOURCE GROUP DETAILS:"
    RG_DETAILS=$(az group show --name "$RESOURCE_GROUP_NAME" --query "{name:name, location:location, id:id, tags:tags}" -o json)
    echo "  Name: $(echo "$RG_DETAILS" | jq -r '.name')"
    echo "  Location: $(echo "$RG_DETAILS" | jq -r '.location')"
    echo "  Resource ID: $(echo "$RG_DETAILS" | jq -r '.id')"
    echo "  Tags: $(echo "$RG_DETAILS" | jq -c '.tags')"
    
else
    echo ""
    echo "❌ DEPLOYMENT FAILED"
    echo "Provisioning State: $PROVISIONING_STATE"
    
    # Get deployment error details
    ERROR_DETAILS=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query "properties.error" -o json)
    if [[ "$ERROR_DETAILS" != "null" && "$ERROR_DETAILS" != "" ]]; then
        echo "Error Details: $ERROR_DETAILS"
    fi
    
    echo ""
    echo "Common solutions:"
    echo "1. Ensure you have appropriate permissions to create resource groups"
    echo "2. Check that the resource group name is unique and valid"
    echo "3. Verify the selected region supports all required services"
    echo "4. Ensure you're connected to the correct Azure subscription"
    exit 1
fi

echo ""
echo "========================================"
echo "  DEPLOYMENT SCRIPT COMPLETED"
echo "========================================"

# USAGE EXAMPLES (commented out):
# 
# Basic usage - Creates new resource group with default settings:
# ./deploy-security-setup.sh -s "MyCompany-Security" -g "rg-security-prod" -w "law-security-prod" -l "eastus"
#
# Advanced usage with custom settings:
# ./deploy-security-setup.sh \
#     --subscription-name "Production-Security" \
#     --resource-group "rg-soc-production" \
#     --workspace-name "law-soc-prod" \
#     --location "eastus" \
#     --description "Production SOC monitoring and security analytics" \
#     --sku "PerGB2018" \
#     --retention 180 \
#     --lock-type "CanNotDelete"
