# Azure Sentinel Automated Deployment

This repository contains scripts to automatically deploy Microsoft Sentinel with all required Azure resources.

## 🚀 Quick Deploy

Click the button below to deploy directly to Azure:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsh4d0wl0ck%2FCYSent%2Fmain%2Fazuredeploy.json)

## 📋 What Gets Deployed

This deployment creates:
- ✅ New Resource Group (if specified)
- ✅ Log Analytics Workspace
- ✅ Microsoft Sentinel (enabled on the workspace)
- ✅ Proper configurations and permissions

## 📁 Files Included

- `azuredeploy.json` - ARM template for Azure resources
- `deploy-sentinel.ps1` - PowerShell deployment script
- `README.md` - This file

## 🛠️ Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed (for PowerShell script method)
- PowerShell 5.1+ or PowerShell Core 6+ (for PowerShell script method)

## 🚀 Deployment Methods

### Method 1: Deploy to Azure Button (Recommended)

1. Click the "Deploy to Azure" button above
2. Sign in to your Azure account
3. Fill in the required parameters:
   - **Resource Group**: Create new or use existing
   - **Location**: Select your preferred Azure region
   - **Workspace Name**: Name for your Log Analytics workspace
   - **Pricing Tier**: Choose pricing tier (PerGB2018 recommended)
   - **Data Retention**: Days to retain data (30-730)
4. Click "Review + create"
5. Click "Create" to start deployment

### Method 2: PowerShell Script

1. Clone this repository:
   ```bash
   git clone [YOUR_REPO_URL]
   cd [YOUR_REPO_NAME]
   ```

2. Run the PowerShell script:
   ```powershell
   .\deploy-sentinel.ps1 -ResourceGroupName "rg-sentinel-prod" -Location "East US"
   ```

   Optional parameters:
   ```powershell
   .\deploy-sentinel.ps1 `
     -ResourceGroupName "rg-sentinel-prod" `
     -Location "East US" `
     -WorkspaceName "my-sentinel-workspace" `
     -SubscriptionName "My-Sentinel-Subscription"
   ```

### Method 3: Azure CLI

```bash
# Create resource group
az group create --name "rg-sentinel-prod" --location "East US"

# Deploy template
az deployment group create \
  --resource-group "rg-sentinel-prod" \
  --template-file azuredeploy.json \
  --parameters workspaceName="my-sentinel-workspace"
```

## 🔧 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `workspaceName` | string | Auto-generated | Name of the Log Analytics workspace |
| `location` | string | Resource group location | Azure region for deployment |
| `pricingTier` | string | PerGB2018 | Pricing tier for Log Analytics |
| `dataRetention` | int | 30 | Number of days to retain data (7-730) |

## 📊 Estimated Costs

Microsoft Sentinel pricing includes:
- **Log Analytics ingestion**: ~$2.76/GB
- **Sentinel analysis**: ~$2.76/GB  
- **Data retention**: Free for first 90 days, then ~$0.12/GB/month

> 💡 **Tip**: Start with the free tier if available in your region, then scale as needed.

## 🔐 Required Permissions

The deployment requires:
- Contributor access to the subscription or resource group
- Permission to create Log Analytics workspaces
- Permission to enable Sentinel

## 📝 Post-Deployment Steps

After deployment:

1. **Access Sentinel**:
   - Go to [Azure Portal](https://portal.azure.com)
   - Search for "Microsoft Sentinel"
   - Select your workspace

2. **Configure Data Connectors**:
   - Azure Activity logs
   - Security Center
   - Office 365 (if applicable)
   - Custom data sources

3. **Set up Analytics Rules**:
   - Enable built-in detection rules
   - Create custom analytics rules
   - Configure automated responses

4. **Configure Workbooks**:
   - Enable security monitoring dashboards
   - Create custom visualizations

## 🔍 Troubleshooting

### Common Issues

**Deployment Failed - Insufficient Permissions**
- Ensure you have Contributor role on the subscription/resource group
- Check if Sentinel is available in your selected region

**Workspace Already Exists**
- Choose a different workspace name
- Or use the existing workspace if intended

**Pricing Tier Not Available**
- Some regions may not support all pricing tiers
- Try "PerGB2018" which is widely available

### Getting Help

- Check deployment logs in Azure Portal → Resource Group → Deployments
- Review the Activity Log for detailed error messages
- Ensure all prerequisites are met

## 🔄 Updating the Deployment

To update your Sentinel configuration:

1. Modify the `azuredeploy.json` template
2. Run the deployment again (it will update existing resources)
3. Or use the "Deploy to Azure" button with new parameters

## 🧹 Cleanup

To remove all resources:

```bash
# Delete the entire resource group (removes all resources)
az group delete --name "rg-sentinel-prod" --yes --no-wait
```

⚠️ **Warning**: This will permanently delete all data and configurations.

## 📚 Additional Resources

- [Microsoft Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)
- [Log Analytics Pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/)
- [Sentinel Pricing](https://azure.microsoft.com/en-us/pricing/details/microsoft-sentinel/)
- [ARM Template Reference](https://docs.microsoft.com/en-us/azure/templates/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**⭐ If this helped you, please star the repository!**
