// ============================================================================
// Microsoft Sentinel Module - Creates Log Analytics Workspace and Sentinel
// ============================================================================

@description('Name of the Log Analytics workspace')
param workspaceName string

@description('Azure region for resources')
param location string

@description('Pricing tier for Log Analytics')
@allowed(['PerGB2018', 'Free', 'Standalone', 'PerNode'])
param pricingTier string = 'PerGB2018'

@description('Data retention period in days')
@minValue(30)
@maxValue(730)
param dataRetentionDays int = 30

@description('Enable Microsoft Sentinel')
param enableSentinel bool = true

@description('Daily data ingestion limit in GB (-1 for unlimited)')
param dailyQuotaGb int = -1

// ============================================================================
// LOG ANALYTICS WORKSPACE
// ============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: {
    Purpose: 'Microsoft Sentinel'
    Environment: 'Production'
    CreatedBy: 'Bicep Template'
    PricingTier: pricingTier
  }
  properties: {
    sku: {
      name: pricingTier
    }
    retentionInDays: dataRetentionDays
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: false
    }
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// MICROSOFT SENTINEL
// ============================================================================

resource sentinelOnboarding 'Microsoft.SecurityInsights/onboardingStates@2023-02-01' = if (enableSentinel) {
  scope: logAnalyticsWorkspace
  name: 'default'
  properties: {
    customerManagedKey: false
  }
}

// ============================================================================
// COMMON DATA CONNECTORS (OPTIONAL)
// ============================================================================

// Azure Activity Logs Connector
resource azureActivityConnector 'Microsoft.SecurityInsights/dataConnectors@2023-02-01' = if (enableSentinel) {
  scope: logAnalyticsWorkspace
  name: 'AzureActivity'
  kind: 'AzureActivity'
  properties: {
    subscriptionId: subscription().subscriptionId
    dataTypes: {
      logs: {
        state: 'Enabled'
      }
    }
  }
  dependsOn: [sentinelOnboarding]
}

// Azure Security Center Connector
resource securityCenterConnector 'Microsoft.SecurityInsights/dataConnectors@2023-02-01' = if (enableSentinel) {
  scope: logAnalyticsWorkspace
  name: 'SecurityCenter'
  kind: 'AzureSecurityCenter'
  properties: {
    subscriptionId: subscription().subscriptionId
    dataTypes: {
      alerts: {
        state: 'Enabled'
      }
    }
  }
  dependsOn: [sentinelOnboarding]
}

// ============================================================================
// BASIC ANALYTICS RULES
// ============================================================================

// Suspicious Activity Rule
resource suspiciousActivityRule 'Microsoft.SecurityInsights/alertRules@2023-02-01' = if (enableSentinel) {
  scope: logAnalyticsWorkspace
  name: 'SuspiciousActivityRule'
  kind: 'Scheduled'
  properties: {
    displayName: 'Suspicious Activity Detected'
    description: 'Detects suspicious activities across Azure resources'
    severity: 'Medium'
    enabled: true
    query: '''
      SecurityEvent
      | where TimeGenerated > ago(1h)
      | where EventID in (4625, 4648, 4719, 4720)
      | summarize Count = count() by Account, Computer, EventID
      | where Count > 5
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT5H'
    suppressionEnabled: false
    tactics: [
      'CredentialAccess'
      'PrivilegeEscalation'
    ]
    techniques: [
      'T1110'
      'T1078'
    ]
    alertRuleTemplateName: null
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: false
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: []
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    alertDetailsOverride: null
    customDetails: null
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'Account'
          }
        ]
      }
      {
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'Computer'
          }
        ]
      }
    ]
  }
  dependsOn: [sentinelOnboarding]
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Log Analytics workspace resource ID')
output workspaceResourceId string = logAnalyticsWorkspace.id

@description('Log Analytics workspace ID (GUID)')
output workspaceId string = logAnalyticsWorkspace.properties.customerId

@description('Log Analytics workspace name')
output workspaceName string = logAnalyticsWorkspace.name

@description('Sentinel onboarding status')
output sentinelEnabled bool = enableSentinel

@description('Pricing tier')
output pricingTier string = pricingTier

@description('Data retention days')
output dataRetentionDays int = dataRetentionDays

@description('Workspace details')
output workspaceDetails object = {
  resourceId: logAnalyticsWorkspace.id
  workspaceId: logAnalyticsWorkspace.properties.customerId
  name: logAnalyticsWorkspace.name
  location: location
  pricingTier: pricingTier
  retentionDays: dataRetentionDays
  sentinelEnabled: enableSentinel
}
