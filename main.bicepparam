// ============================================================================
// Microsoft Sentinel Bicep Parameters File
// Configure your deployment parameters here
// ============================================================================

using './main.bicep'

// ============================================================================
// SUBSCRIPTION PARAMETERS
// ============================================================================

// Set to true to create a new subscription (requires billing account access)
param createNewSubscription = false

// Name for the new subscription (only used if createNewSubscription = true)
param newSubscriptionName = 'Sentinel-Production-Subscription'

// Billing account ID (required for new subscription)
// Get this from: az billing account list
param billingAccountId = ''

// Existing subscription ID (only used if createNewSubscription = false)
// Get this from: az account list
param existingSubscriptionId = ''

// ============================================================================
// RESOURCE PARAMETERS
// ============================================================================

// Name for the new Resource Group (REQUIRED)
param resourceGroupName = 'rg-sentinel-production'

// Azure region for deployment
param location = 'eastus'

// Log Analytics workspace name
param workspaceName = 'sentinel-workspace-prod'

// Data retention period (30-730 days)
param dataRetentionDays = 30

// Enable Microsoft Sentinel
param enableSentinel = true

// Daily data ingestion limit in GB (-1 for unlimited)
param dailyQuotaGb = -1
