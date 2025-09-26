// ============================================================================
// Microsoft Sentinel Complete Deployment - Bicep Template
// Creates subscription, resource group, Log Analytics workspace, and Sentinel
// ============================================================================

targetScope = 'managementGroup' // Allows subscription creation

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Create a new subscription (requires billing account access)')
param createNewSubscription bool = false

@description('Name for the new subscription')
param newSubscriptionName string = 'Sentinel-Subscription-${utcNow('yyyyMMdd-HHmm')}'

@description('Billing enrollment account ID (required for new subscription)')
param billingAccountId string = ''

@description('Existing subscription ID to use (if not creating new)')
param existingSubscriptionId string = ''

@description('Name for the new Resource Group')
@minLength(1)
@maxLength(90)
param resourceGroupName string

@description('Azure region for all resources')
param location string = 'eastus'

@description('Name of the Log Analytics workspace')
param workspaceName string = 'sentinel-workspace-${uniqueString(resourceGroupName)}'

@description('Data retention period in days')
@minValue(30)
@maxValue(730)
param dataRetentionDays int = 30

@description('Enable Microsoft Sentinel on the workspace')
param enableSentinel bool = true

@description('Daily data ingestion limit in GB (-1 for unlimited)')
param dailyQuotaGb int = -1

// ============================================================================
// VARIABLES
// ============================================================================

var pricingTier = 'PerGB2018'
var subscriptionId = createNewSubscription ? newSub.outputs.subscriptionId : existingSubscriptionId

// Resource providers required for Sentinel
var requiredResourceProviders = [
  'Microsoft.OperationalInsights'
  'Microsoft.SecurityInsights'
  'Microsoft.OperationsManagement'
  'Microsoft.Security'
  'Microsoft.Automation'
]

// ============================================================================
// SUBSCRIPTION CREATION (CONDITIONAL)
// ============================================================================

resource newSub 'Microsoft.Subscription/subscriptions@2021-10-01' = if (createNewSubscription) {
  scope: tenant()
  name: guid(newSubscriptionName)
  properties: {
    subscriptionName: newSubscriptionName
    billingScope: billingAccountId
    workload: 'Production'
  }
}

// ============================================================================
// RESOURCE PROVIDER REGISTRATION
// ============================================================================

resource resourceProviders 'Microsoft.Resources/deployments@2022-09-01' = [for provider in requiredResourceProviders: {
  scope: subscription(subscriptionId)
  name: 'register-${replace(provider, '.', '-')}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: [
        {
          type: 'Microsoft.Resources/providers'
          apiVersion: '2021-04-01'
          name: provider
          properties: {}
        }
      ]
    }
  }
  dependsOn: createNewSubscription ? [newSub] : []
}]

// ============================================================================
// RESOURCE GROUP CREATION
// ============================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  scope: subscription(subscriptionId)
  name: resourceGroupName
  location: location
  tags: {
    Purpose: 'Microsoft Sentinel'
    Environment: 'Production' 
    CreatedBy: 'Bicep Deployment'
    CreatedDate: utcNow('yyyy-MM-dd')
  }
  dependsOn: resourceProviders
}

// ============================================================================
// MAIN DEPLOYMENT MODULE
// ============================================================================

module sentinelDeployment 'modules/sentinel.bicep' = {
  scope: resourceGroup
  name: 'sentinel-deployment-${utcNow('yyyyMMdd-HHmmss')}'
  params: {
    workspaceName: workspaceName
    location: location
    pricingTier: pricingTier
    dataRetentionDays: dataRetentionDays
    enableSentinel: enableSentinel
    dailyQuotaGb: dailyQuotaGb
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The subscription ID used for deployment')
output subscriptionId string = subscriptionId

@description('The resource group name')
output resourceGroupName string = resourceGroupName

@description('The Log Analytics workspace name')
output workspaceName string = workspaceName

@description('The Log Analytics workspace resource ID')
output workspaceResourceId string = sentinelDeployment.outputs.workspaceResourceId

@description('The Log Analytics workspace ID (GUID)')
output workspaceId string = sentinelDeployment.outputs.workspaceId

@description('The pricing tier used')
output pricingTier string = pricingTier

@description('Azure portal link to Sentinel')
output sentinelPortalUrl string = 'https://portal.azure.com/#view/Microsoft_Azure_Security_Insights/MainMenuBlade/~/0/subscriptionId/${subscriptionId}/resourceGroup/${resourceGroupName}'

@description('Azure portal link to resource group')
output resourceGroupUrl string = 'https://portal.azure.com/#@/resource/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}'

@description('Deployment summary')
output deploymentSummary object = {
  subscriptionId: subscriptionId
  subscriptionName: createNewSubscription ? newSubscriptionName : 'Existing'
  resourceGroupName: resourceGroupName
  location: location
  workspaceName: workspaceName
  pricingTier: pricingTier
  dataRetentionDays: dataRetentionDays
  sentinelEnabled: enableSentinel
  deploymentTimestamp: utcNow()
}
