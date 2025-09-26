# Azure Sentinel Complete Deployment Solution

This repository provides a comprehensive solution to deploy Microsoft Sentinel using **both ARM templates and modern Bicep templates**. The Bicep version offers cleaner syntax, better resource provider management, and easier subscription creation.

## 🚀 Quick Deploy Options

### 🎯 Option 1: Bicep Deployment (Recommended - New!)

**Advantages of Bicep:**
- ✅ **Automatic resource provider registration**
- ✅ **Built-in subscription creation capability**
- ✅ **Cleaner, more readable syntax**
- ✅ **Better error handling and validation**
- ✅ **Automatic dependency management**

```powershell
# Clone repository
git clone https://github.com/sh4d0wl0ck/CYSent.git
cd CYSent

# Edit parameters in main.bicepparam file
# Then deploy:
.\deploy-sentinel-bicep.ps1 -ResourceGroupName "rg-sentinel" -Location "eastus"

# Or with new subscription:
.\deploy-sentinel-bicep.ps1 -CreateNewSubscription -ResourceGroupName "rg-sentinel" -Location "eastus"
```

### # Azure Sentinel Complete Deployment Solution

This repository provides a comprehensive solution to deploy Microsoft Sentinel with all required Azure resources, including subscription management, resource group creation, and workspace configuration.

## 🚀 Quick Deploy to Azure

### 🎯 Option 2: ARM Template Deployment (Classic)

#### ⚠️ IMPORTANT: Resource Provider Registration Required

Before using the Deploy to Azure button, you **must** register the required Azure resource providers. This is a one-time setup per subscription.

**Windows Users:**
```powershell
.\register-providers.ps1
```

**Linux/Mac Users:**
```bash
chmod +x register-providers.sh
./register-providers.sh
```

#### ✅ After Registration Complete:
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsh4d0wl0ck%2FCYSent%2Fmain%2Fazuredeploy.json)

## 📋 What This Solution Creates

### 🔷 Bicep Version (Recommended)
- ✅ **Automatic Resource Provider Registration** (no manual steps!)
- ✅ **Subscription Creation** with full billing account integration
- ✅ **Resource Group Creation** with proper tagging
- ✅ **Log Analytics Workspace** with PerGB2018 pricing
- ✅ **Microsoft Sentinel** with default connectors
- ✅ **Basic Analytics Rules** for immediate threat detection
- ✅ **Comprehensive Error Handling** and validation

### 🔷 ARM Version (Classic)
- ✅ **Manual Resource Provider Registration** (via helper scripts)
- ✅ **Subscription Selection** (existing subscriptions)
- ✅ **Resource Group Creation** (user must specify name)
- ✅ **Log Analytics Workspace** with PerGB2018 pricing
- ✅ **Microsoft Sentinel** activation

## 📁 Repository Structure

```
├── main.bicep                    # 🆕 Main Bicep template (recommended)
├── main.bicepparam               # 🆕 Bicep parameters file
├── modules/
│   └── sentinel.bicep            # 🆕 Sentinel module
├── deploy-sentinel-bicep.ps1     # 🆕 Bicep deployment script
├── azuredeploy.json              # ARM template for Azure resources
├── deploy-sentinel.ps1           # PowerShell deployment script (ARM)
├── deploy-sentinel.bat           # Windows batch wrapper script
├── register-providers.ps1        # PowerShell resource provider registration
├── register-providers.sh         # Bash resource provider registration
└── README.md                     # This documentation
```

## 🛠️ Prerequisites

- **Azure Account** with appropriate permissions
- **Azure CLI** installed and configured
- **PowerShell 5.1+** or **PowerShell Core 6+**
- **Contributor Access** to subscription/resource group

## 🚀 Deployment Methods

### Method 1: Bicep Deployment (Recommended)

#### 🔧 Basic Bicep Deployment
```powershell
# Clone repository
git clone [YOUR_REPO_URL]
cd [YOUR_REPO_NAME]

# Deploy with existing subscription
.\deploy-sentinel-bicep.ps1 `
  -ResourceGroupName "rg-sentinel-production" `
  -Location "eastus" `
  -WorkspaceName "my-sentinel-workspace"
```

#### 🆕 Advanced Bicep Deployment (Create New Subscription)
```powershell
# First, get your billing account ID
az billing account list

# Then deploy with new subscription
.\deploy-sentinel-bicep.ps1 `
  -CreateNewSubscription `
  -NewSubscriptionName "My-Sentinel-Subscription" `
  -BillingAccountId "/providers/Microsoft.Billing/billingAccounts/[YOUR_BILLING_ID]" `
  -ResourceGroupName "rg-sentinel-production" `
  -Location "eastus"
```

#### 📋 Bicep Parameters File Method
```powershell
# 1. Edit main.bicepparam file with your values
# 2. Deploy using parameter file
az deployment mg create `
  --management-group-id [YOUR_MG_ID] `
  --template-file main.bicep `
  --parameters @main.bicepparam
```

#### 🔧 Bicep Script Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ResourceGroupName` | String | **Yes** | Name for the new resource group |
| `Location` | String | **Yes** | Azure region |
| `CreateNewSubscription` | Switch | No | Create new subscription |
| `NewSubscriptionName` | String | No | Name for new subscription |
| `BillingAccountId` | String | No* | Billing account (* required if creating subscription) |
| `ExistingSubscriptionId` | String | No | Use existing subscription ID |
| `WorkspaceName` | String | No | Workspace name (auto-generated if not provided) |
| `ManagementGroupId` | String | No | Management group for deployment scope |

### Method 2: ARM PowerShell Script

#### 🔧 Basic ARM Deployment (Use Existing Subscription)
```powershell
# First register resource providers
.\register-providers.ps1

# Then deploy
.\deploy-sentinel.ps1 `
  -UseExistingSubscription `
  -ResourceGroupName "rg-sentinel-production" `
  -Location "eastus" `
  -WorkspaceName "my-sentinel-workspace"
```

#### 🆕 Advanced ARM Deployment (Create New Subscription)
```powershell
# Deploy with new subscription creation
.\deploy-sentinel.ps1 `
  -CreateNewSubscription `
  -NewSubscriptionName "My-Sentinel-Subscription" `
  -ResourceGroupName "rg-sentinel-production" `
  -Location "eastus" `
  -WorkspaceName "my-sentinel-workspace"
```

### Method 3: Deploy to Azure Button (ARM Template)

⚠️ **Requires manual resource provider registration first**

### Method 4: Windows Batch Script (User-Friendly)

```cmd
# Double-click or run from command prompt
deploy-sentinel.bat
```

### Method 5: Direct Azure CLI (Bicep)

```bash
# Deploy with Bicep
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters \
    resourceGroupName="rg-sentinel-prod" \
    workspaceName="my-sentinel-workspace" \
    location="eastus"
```

## 🆚 Bicep vs ARM Comparison

| Feature | 🎯 Bicep (Recommended) | 🔧 ARM Template |
|---------|----------------------|----------------|
| **Syntax** | Clean, readable, type-safe | JSON, verbose, complex |
| **Resource Providers** | ✅ Automatic registration | ❌ Manual registration required |
| **Subscription Creation** | ✅ Native support | ⚠️ Limited capability |
| **Error Handling** | ✅ Superior validation | ❌ Basic validation |
| **Dependency Management** | ✅ Automatic | ❌ Manual declaration |
| **Learning Curve** | ✅ Easy | ❌ Steep |
| **Deployment Speed** | ✅ Faster | ⚠️ Slower |
| **Debugging** | ✅ Clear error messages | ❌ Cryptic errors |
| **Maintenance** | ✅ Easy to update | ❌ Complex to modify |

## 🎯 Bicep Template Features

### 🔧 Automatic Resource Provider Registration
```bicep
// Bicep automatically handles this in the background
var requiredResourceProviders = [
  'Microsoft.OperationalInsights'
  'Microsoft.SecurityInsights'
  'Microsoft.OperationsManagement'
  'Microsoft.Security'
  'Microsoft.Automation'
]
```

### 🆕 Native Subscription Creation
```bicep
resource newSub 'Microsoft.Subscription/subscriptions@2021-10-01' = if (createNewSubscription) {
  scope: tenant()
  name: guid(newSubscriptionName)
  properties: {
    subscriptionName: newSubscriptionName
    billingScope: billingAccountId
    workload: 'Production'
  }
}
```

### 📋 Built-in Data Connectors
```bicep
// Azure Activity Logs automatically configured
resource azureActivityConnector 'Microsoft.SecurityInsights/dataConnectors@2023-02-01' = {
  scope: logAnalyticsWorkspace
  name: 'AzureActivity'
  kind: 'AzureActivity'
  properties: {
    subscriptionId: subscription().subscriptionId
    dataTypes: {
      logs: { state: 'Enabled' }
    }
  }
}
```

### 🛡️ Pre-configured Analytics Rules
```bicep
// Suspicious activity detection rule included
resource suspiciousActivityRule 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: logAnalyticsWorkspace
  name: 'SuspiciousActivityRule'
  kind: 'Scheduled'
  properties: {
    displayName: 'Suspicious Activity Detected'
    severity: 'Medium'
    enabled: true
    // KQL query included in template
  }
}
```

## 💰 Pricing Information

### 🏷️ PerGB2018 Pricing Model

Both templates use the **PerGB2018** pricing tier:

| Component | Cost | Details |
|-----------|------|---------|
| **Log Analytics Ingestion** | ~$2.76/GB | Data ingested into workspace |
| **Sentinel Analysis** | ~$2.76/GB | Data analyzed by Sentinel |
| **Data Retention** | FREE (90 days) | Then ~$0.12/GB/month |
| **Search Queries** | Included | No additional cost |

### 💡 Cost Optimization Tips

- Start with **30-day retention** and adjust as needed
- Use **data collection rules** to filter unnecessary data
- Monitor usage with **Azure Cost Management**
- Set up **billing alerts** to track spending
- **Bicep version** includes cost monitoring queries built-in

## 🔐 Required Permissions

### For Bicep Deployment (Subscription Creation):
- **Enterprise Agreement** or **Microsoft Customer Agreement** access
- **Management Group Contributor** role (for subscription creation)
- **Account Owner** or **Billing Account Contributor** role

### For ARM Deployment (Existing Subscription):
- **Contributor** role on target subscription/resource group
- **Resource Policy Contributor** (for resource provider registration)

### For Both Deployment Types:
- **Log Analytics Contributor** role (or higher)
- **Security Admin** role for Sentinel features
- **Reader** role on billing accounts (if creating subscriptions)

## 🔍 Troubleshooting

### Common Issues and Solutions

#### ❌ "MissingSubscriptionRegistration" Error
**Error Message:** `The subscription is not registered to use namespace 'Microsoft.OperationsManagement'`

**Solution:** 
1. **Run the resource provider registration script** (see Quick Deploy section above)
2. **Or manually register providers:**
   ```bash
   az provider register --namespace Microsoft.OperationalInsights
   az provider register --namespace Microsoft.SecurityInsights
   az provider register --namespace Microsoft.OperationsManagement
   az provider register --namespace Microsoft.Security
   az provider register --namespace Microsoft.Automation
   ```
3. **Wait for registration to complete** (can take 2-5 minutes)
4. **Retry the deployment**

#### ❌ "Insufficient permissions to create subscription"
**Solution:** Use `-UseExistingSubscription` parameter or get billing account access

#### ❌ "Resource group name already exists"
**Solution:** Choose a different name or use the existing one when prompted

#### ❌ "Template deployment failed"
**Solutions:**
- Check if Sentinel is available in your region
- Verify subscription has sufficient quota
- Ensure proper permissions

#### ❌ "Azure CLI not found"
**Solution:** Install from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

### 📱 Getting Detailed Logs

Run with verbose output:
```powershell
.\deploy-sentinel.ps1 -ResourceGroupName "test-rg" -Location "East US" -Verbose
```

## 📚 Post-Deployment Configuration

### 🔗 Immediate Next Steps

1. **Access Sentinel Portal:**
   ```
   https://portal.azure.com/#view/Microsoft_Azure_Security_Insights/MainMenuBlade
   ```

2. **Configure Data Connectors:**
   - Azure Activity Logs
   - Microsoft Security Center
   - Office 365 (if applicable)
   - Custom data sources

3. **Enable Analytics Rules:**
   - Built-in detection templates
   - Custom threat detection rules
   - Automated incident response

4. **Set Up Workbooks:**
   - Security monitoring dashboards
   - Executive reporting views
   - Custom visualizations

### 🎯 Recommended Configuration

```powershell
# After deployment, configure basic connectors
# (These commands would be run in Azure CLI or Portal)

# Enable Azure Activity connector
# Enable Azure Security Center connector  
# Enable Office 365 connector (if applicable)
```

## 🧹 Cleanup and Resource Management

### 🗑️ Remove All Resources
```bash
# WARNING: This deletes everything including all data
az group delete --name "your-resource-group-name" --yes --no-wait
```

### 💾 Backup Configuration
```bash
# Export ARM template for backup
az group export --name "your-resource-group-name" > backup-template.json

# Export Sentinel configuration
az sentinel analytics-rule list --resource-group "your-rg" --workspace-name "your-workspace"
```

### 📊 Monitor Resource Usage
```bash
# Check workspace usage
az monitor log-analytics workspace show --resource-group "your-rg" --workspace-name "your-workspace"

# Monitor costs
az consumption usage list --billing-period-name "202412"
```

## 🔄 Updating Your Deployment

### 📝 Modify Configuration
To update your Sentinel deployment:

1. **Update Parameters** in the ARM template
2. **Re-run** the deployment script
3. **Resources will be updated** in-place (no data loss)

```powershell
# Update with new retention period
.\deploy-sentinel.ps1 `
  -UseExistingSubscription `
  -ResourceGroupName "existing-rg" `
  -Location "East US" `
  -WorkspaceName "existing-workspace"
```

### 🔧 Template Modifications
You can customize the `azuredeploy.json` template:

- **Add data connectors** automatically
- **Include analytics rules** in deployment
- **Configure automation** playbooks
- **Set up workbooks** by default

## 📈 Scaling and Performance

### 🚀 Performance Optimization

1. **Data Collection Rules:**
   - Filter unnecessary logs at source
   - Use KQL queries efficiently
   - Implement data sampling for high-volume sources

2. **Workspace Configuration:**
   - Monitor daily ingestion limits
   - Optimize data retention policies
   - Use commitment tiers for predictable workloads

3. **Query Performance:**
   - Use time range filters
   - Optimize KQL queries
   - Implement result caching

### 📊 Monitoring Dashboard

After deployment, set up monitoring:

```kql
// Monitor daily data ingestion
Usage
| where TimeGenerated > ago(7d)
| where IsBillable == true
| summarize DataGB = sum(Quantity) / 1000 by bin(TimeGenerated, 1d)
| render timechart
```

## 🤝 Contributing and Support

### 🐛 Issue Reporting
Found a problem? Please report:

1. **Create an issue** with detailed description
2. **Include error logs** and screenshots
3. **Specify your environment** (OS, PowerShell version, Azure CLI version)

### 🔄 Pull Requests Welcome
We welcome improvements:

1. **Fork** the repository
2. **Create feature branch** from main
3. **Test thoroughly** in your environment
4. **Submit pull request** with clear description

### 📞 Getting Help

- **Azure Sentinel Documentation:** https://docs.microsoft.com/en-us/azure/sentinel/
- **ARM Template Reference:** https://docs.microsoft.com/en-us/azure/templates/
- **Azure CLI Reference:** https://docs.microsoft.com/en-us/cli/azure/
- **PowerShell Documentation:** https://docs.microsoft.com/en-us/powershell/

## 🏷️ Version History

### v1.0.0 (Current)
- ✅ Complete subscription management
- ✅ Required resource group creation
- ✅ PerGB2018 pricing tier enforcement
- ✅ Sectioned deployment process
- ✅ Comprehensive error handling
- ✅ Detailed logging and progress tracking

### 🔮 Planned Features (v1.1.0)
- 🔄 Built-in data connector configuration
- 🔄 Pre-configured analytics rules
- 🔄 Automated workbook deployment
- 🔄 Cost estimation calculator
- 🔄 Multi-environment support

## 📜 License and Disclaimer

### 📄 License
This project is licensed under the **MIT License** - see the LICENSE file for details.

### ⚠️ Important Disclaimers

1. **Billing Responsibility:** You are responsible for all Azure costs incurred
2. **Security Configuration:** Additional security hardening may be required for production
3. **Data Retention:** Understand data retention policies and associated costs
4. **Compliance:** Ensure deployment meets your organization's compliance requirements

### 🛡️ Security Considerations

- **Network Security:** Consider private endpoints for production
- **Access Control:** Implement proper RBAC policies
- **Data Classification:** Classify and protect sensitive data appropriately
- **Monitoring:** Set up security monitoring and alerting

## 🎯 Quick Reference Commands

### 📋 Essential Commands

```powershell
# Basic deployment
.\deploy-sentinel.ps1 -ResourceGroupName "rg-sentinel" -Location "East US"

# With new subscription
.\deploy-sentinel.ps1 -CreateNewSubscription -ResourceGroupName "rg-sentinel" -Location "East US"

# Check deployment status
az deployment group list --resource-group "rg-sentinel"

# View Sentinel workspace
az sentinel workspace show --resource-group "rg-sentinel" --workspace-name "your-workspace"

# Monitor costs
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31
```

### 🔗 Useful Links

| Resource | URL |
|----------|-----|
| **Azure Portal** | https://portal.azure.com |
| **Sentinel Portal** | https://portal.azure.com/#view/Microsoft_Azure_Security_Insights |
| **Cost Management** | https://portal.azure.com/#view/Microsoft_Azure_CostManagement |
| **Pricing Calculator** | https://azure.microsoft.com/en-us/pricing/calculator/ |
| **Sentinel Pricing** | https://azure.microsoft.com/en-us/pricing/details/microsoft-sentinel/ |

---

## 🎉 Ready to Deploy?

**Choose your deployment method:**

1. **🚀 One-Click Deploy:** Click the "Deploy to Azure" button above
2. **💻 PowerShell Script:** Download and run `deploy-sentinel.ps1`
3. **🖱️ Windows GUI:** Double-click `deploy-sentinel.bat`
4. **⌨️ Azure CLI:** Use the CLI commands provided

**Remember:** You **must** provide a Resource Group name, and the system will create it with **PerGB2018 pricing** automatically.

**⭐ If this solution helps you, please star the repository and share it with others!**

---

*Last updated: September 2025*
