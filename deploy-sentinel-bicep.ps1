#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Microsoft Sentinel Bicep Deployment Script
.DESCRIPTION
    Deploys Microsoft Sentinel using Bicep templates with subscription creation capability
.PARAMETER CreateNewSubscription
    Create a new subscription (requires billing account access)
.PARAMETER NewSubscriptionName
    Name for the new subscription
.PARAMETER BillingAccountId
    Billing enrollment account ID (required for new subscription)
.PARAMETER ExistingSubscriptionId
    Existing subscription ID to use (if not creating new)
.PARAMETER ResourceGroupName
    Name for the new resource group (REQUIRED)
.PARAMETER Location
    Azure region for deployment
.PARAMETER WorkspaceName
    Name for the Log Analytics workspace
.PARAMETER ManagementGroupId
    Management group ID for deployment scope (required for subscription creation)
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$CreateNewSubscription,
    
    [Parameter(Mandatory=$false)]
    [string]$NewSubscriptionName = "Sentinel-Subscription-$(Get-Date -Format 'yyyyMMdd-HHmm')",
    
    [Parameter(Mandatory=$false)]
    [string]$BillingAccountId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ExistingSubscriptionId = "",
    
    [Parameter(Mandatory=$true, HelpMessage="Enter the name for the new Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "sentinel-workspace-$(Get-Random -Maximum 9999)",
    
    [Parameter(Mandatory=$false)]
    [string]$ManagementGroupId = ""
)

# Set error action preference
$ErrorActionPreference = "Stop"

# ============================================================================
# SECTION 1: INITIAL SETUP AND VALIDATION
# ============================================================================

Write-Host ""
Write-Host "🚀 MICROSOFT SENTINEL BICEP DEPLOYMENT" -ForegroundColor Green -BackgroundColor Black
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""

function Write-Section {
    param([string]$Title, [string]$Color = "Yellow")
    Write-Host ""
    Write-Host "📋 SECTION: $Title" -ForegroundColor $Color
    Write-Host ("=" * (10 + $Title.Length)) -ForegroundColor $Color
}

Write-Section "INITIAL SETUP AND VALIDATION"

# Check Azure CLI installation
try {
    $azVersion = (az --version | Select-String "azure-cli" | Out-String).Trim()
    Write-Host "✅ Azure CLI detected: $($azVersion.Split()[1])" -ForegroundColor Green
} catch {
    Write-Error "❌ Azure CLI is not installed. Please install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check Bicep CLI
try {
    $bicepVersion = az bicep version
    Write-Host "✅ Bicep CLI detected: $bicepVersion" -ForegroundColor Green
} catch {
    Write-Host "🔧 Installing Bicep CLI..." -ForegroundColor Yellow
    az bicep install
    Write-Host "✅ Bicep CLI installed successfully" -ForegroundColor Green
}

# Validate Bicep files exist
$mainBicepFile = "main.bicep"
$modulePath = "modules/sentinel.bicep"

if (-not (Test-Path $mainBicepFile)) {
    Write-Error "❌ Main Bicep file '$mainBicepFile' not found in current directory"
    exit 1
}

if (-not (Test-Path $modulePath)) {
    Write-Error "❌ Sentinel module '$modulePath' not found. Please ensure the modules folder exists."
    exit 1
}

Write-Host "✅ Bicep template files found" -ForegroundColor Green

# Display deployment configuration
Write-Host ""
Write-Host "🔧 DEPLOYMENT CONFIGURATION:" -ForegroundColor Cyan
Write-Host "   Resource Group Name: $ResourceGroupName" -ForegroundColor White
Write-Host "   Location: $Location" -ForegroundColor White
Write-Host "   Workspace Name: $WorkspaceName" -ForegroundColor White
Write-Host "   Pricing Tier: PerGB2018 (Pay-per-GB)" -ForegroundColor White
Write-Host "   Create New Subscription: $CreateNewSubscription" -ForegroundColor White

if ($CreateNewSubscription) {
    Write-Host "   New Subscription Name: $NewSubscriptionName" -ForegroundColor White
}

# ============================================================================
# SECTION 2: AZURE AUTHENTICATION
# ============================================================================

Write-Section "AZURE AUTHENTICATION"

try {
    $currentAccount = az account show 2>$null | ConvertFrom-Json
    if ($currentAccount) {
        Write-Host "✅ Already authenticated as: $($currentAccount.user.name)" -ForegroundColor Green
        Write-Host "   Tenant: $($currentAccount.tenantId)" -ForegroundColor Gray
    }
} catch {
    Write-Host "🔐 Initiating Azure login..." -ForegroundColor Yellow
    try {
        az login --output none
        $currentAccount = az account show | ConvertFrom-Json
        Write-Host "✅ Successfully authenticated as: $($currentAccount.user.name)" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to authenticate with Azure"
        exit 1
    }
}

# ============================================================================
# SECTION 3: SUBSCRIPTION AND MANAGEMENT GROUP SETUP
# ============================================================================

Write-Section "SUBSCRIPTION AND MANAGEMENT GROUP SETUP"

if ($CreateNewSubscription) {
    if ([string]::IsNullOrEmpty($BillingAccountId)) {
        Write-Host "🔍 Discovering billing accounts..." -ForegroundColor Yellow
        try {
            $billingAccounts = az billing account list | ConvertFrom-Json
            if ($billingAccounts -and $billingAccounts.Count -gt 0) {
                Write-Host "✅ Found $($billingAccounts.Count) billing account(s)" -ForegroundColor Green
                
                for ($i = 0; $i -lt $billingAccounts.Count; $i++) {
                    Write-Host "   [$i] $($billingAccounts[$i].displayName)" -ForegroundColor Cyan
                }
                
                if ($billingAccounts.Count -eq 1) {
                    $BillingAccountId = $billingAccounts[0].id
                    Write-Host "✅ Using billing account: $($billingAccounts[0].displayName)" -ForegroundColor Green
                } else {
                    do {
                        $choice = Read-Host "Select billing account [0-$($billingAccounts.Count-1)]"
                    } while ($choice -notmatch '^\d+$' -or [int]$choice -ge $billingAccounts.Count)
                    $BillingAccountId = $billingAccounts[[int]$choice].id
                }
            } else {
                Write-Error "❌ No billing accounts found. Cannot create subscription."
                exit 1
            }
        } catch {
            Write-Error "❌ Could not retrieve billing accounts: $($_.Exception.Message)"
            exit 1
        }
    }
} else {
    # Get existing subscription
    if ([string]::IsNullOrEmpty($ExistingSubscriptionId)) {
        $subscriptions = az account list | ConvertFrom-Json
        if ($subscriptions.Count -eq 0) {
            Write-Error "❌ No subscriptions available."
            exit 1
        }
        
        Write-Host "📊 Available subscriptions:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            Write-Host "   [$i] $($subscriptions[$i].name)" -ForegroundColor White
        }
        
        if ($subscriptions.Count -eq 1) {
            $ExistingSubscriptionId = $subscriptions[0].id
        } else {
            do {
                $choice = Read-Host "Select subscription [0-$($subscriptions.Count-1)]"
            } while ($choice -notmatch '^\d+$' -or [int]$choice -ge $subscriptions.Count)
            $ExistingSubscriptionId = $subscriptions[[int]$choice].id
        }
    }
    
    az account set --subscription $ExistingSubscriptionId
    Write-Host "✅ Active subscription set" -ForegroundColor Green
}

# Get management group for deployment scope
if ([string]::IsNullOrEmpty($ManagementGroupId) -and $CreateNewSubscription) {
    try {
        $managementGroups = az account management-group list | ConvertFrom-Json
        if ($managementGroups -and $managementGroups.Count -gt 0) {
            Write-Host "📋 Available management groups:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $managementGroups.Count; $i++) {
                Write-Host "   [$i] $($managementGroups[$i].displayName) ($($managementGroups[$i].name))" -ForegroundColor White
            }
            
            if ($managementGroups.Count -eq 1) {
                $ManagementGroupId = $managementGroups[0].name
            } else {
                do {
                    $choice = Read-Host "Select management group [0-$($managementGroups.Count-1)]"
                } while ($choice -notmatch '^\d+$' -or [int]$choice -ge $managementGroups.Count)
                $ManagementGroupId = $managementGroups[[int]$choice].name
            }
            Write-Host "✅ Using management group: $ManagementGroupId" -ForegroundColor Green
        }
    } catch {
        Write-Warning "⚠️ Could not retrieve management groups. Using tenant root group."
        $ManagementGroupId = $currentAccount.tenantId
    }
}

# ============================================================================
# SECTION 4: BICEP DEPLOYMENT
# ============================================================================

Write-Section "BICEP DEPLOYMENT"

Write-Host "🏗️ Starting Bicep deployment..." -ForegroundColor Yellow
Write-Host "   Template: $mainBicepFile" -ForegroundColor Gray
Write-Host "   Scope: Management Group" -ForegroundColor Gray

try {
    $deploymentName = "sentinel-bicep-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    # Build parameters
    $parameters = @{
        resourceGroupName = $ResourceGroupName
        location = $Location
        workspaceName = $WorkspaceName
        createNewSubscription = $CreateNewSubscription.IsPresent
        dataRetentionDays = 30
        enableSentinel = $true
    }
    
    if ($CreateNewSubscription) {
        $parameters.newSubscriptionName = $NewSubscriptionName
        $parameters.billingAccountId = $BillingAccountId
    } else {
        $parameters.existingSubscriptionId = $ExistingSubscriptionId
    }
    
    # Convert parameters to parameter file format
    $paramString = ($parameters.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
    
    Write-Host "🚀 Executing deployment: $deploymentName" -ForegroundColor Yellow
    
    if ($CreateNewSubscription -and -not [string]::IsNullOrEmpty($ManagementGroupId)) {
        # Deploy to management group scope
        $result = az deployment mg create `
            --management-group-id $ManagementGroupId `
            --name $deploymentName `
            --template-file $mainBicepFile `
            --parameters $paramString `
            --output json | ConvertFrom-Json
    } else {
        # Deploy to subscription scope (simpler)
        $result = az deployment sub create `
            --location $Location `
            --name $deploymentName `
            --template-file $mainBicepFile `
            --parameters $paramString `
            --output json | ConvertFrom-Json
    }
    
    if ($result.properties.provisioningState -eq "Succeeded") {
        Write-Host "✅ Bicep deployment completed successfully!" -ForegroundColor Green
    } else {
        Write-Error "❌ Deployment failed with state: $($result.properties.provisioningState)"
    }
    
} catch {
    Write-Error "❌ Failed to execute Bicep deployment: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# SECTION 5: DEPLOYMENT SUMMARY
# ============================================================================

Write-Section "DEPLOYMENT SUMMARY" "Green"

$outputs = $result.properties.outputs

Write-Host "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green -BackgroundColor Black
Write-Host ""
Write-Host "📊 RESOURCE SUMMARY:" -ForegroundColor Cyan
if ($outputs) {
    Write-Host "   ✅ Subscription ID: $($outputs.subscriptionId.value)" -ForegroundColor White
    Write-Host "   ✅ Resource Group: $($outputs.resourceGroupName.value)" -ForegroundColor White
    Write-Host "   ✅ Location: $($outputs.deploymentSummary.value.location)" -ForegroundColor White
    Write-Host "   ✅ Workspace: $($outputs.workspaceName.value)" -ForegroundColor White
    Write-Host "   ✅ Pricing Tier: $($outputs.pricingTier.value)" -ForegroundColor White
    Write-Host "   ✅ Sentinel: Enabled" -ForegroundColor White
}

Write-Host ""
Write-Host "🔗 ACCESS LINKS:" -ForegroundColor Cyan
if ($outputs.sentinelPortalUrl) {
    Write-Host "   🛡️ Sentinel Portal: $($outputs.sentinelPortalUrl.value)" -ForegroundColor Blue
}
if ($outputs.resourceGroupUrl) {
    Write-Host "   📋 Resource Group: $($outputs.resourceGroupUrl.value)" -ForegroundColor Blue
}

Write-Host ""
Write-Host "🎯 Bicep deployment completed with automatic resource provider registration!" -ForegroundColor Green
Write-Host ""
