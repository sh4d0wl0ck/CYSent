# ============================================================================
# Azure Template Spec Creation Script
# This creates a Template Spec in Azure for easy reuse via Azure Portal
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "rg-template-specs",
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$TemplateSpecName = "sentinel-deployment-spec",
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0"
)

Write-Host "🚀 CREATING AZURE TEMPLATE SPEC FOR SENTINEL DEPLOYMENT" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""

# Check if logged in
try {
    $account = az account show | ConvertFrom-Json
    Write-Host "✅ Authenticated as: $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Host "🔐 Please log in to Azure..." -ForegroundColor Yellow
    az login
}

# Create resource group for template specs
Write-Host "📁 Creating Template Specs resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none
Write-Host "✅ Resource group created: $ResourceGroupName" -ForegroundColor Green

# Create template spec
Write-Host "📋 Creating Template Spec..." -ForegroundColor Yellow
az ts create \
    --resource-group $ResourceGroupName \
    --name $TemplateSpecName \
    --version $Version \
    --display-name "Microsoft Sentinel Complete Deployment" \
    --description "Complete Microsoft Sentinel deployment with Log Analytics workspace, data connectors, and analytics rules. Uses PerGB2018 pricing model." \
    --template-file "main.bicep" \
    --output table

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "🎉 TEMPLATE SPEC CREATED SUCCESSFULLY!" -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    Write-Host "📋 TEMPLATE SPEC DETAILS:" -ForegroundColor Cyan
    Write-Host "   Name: $TemplateSpecName" -ForegroundColor White
    Write-Host "   Version: $Version" -ForegroundColor White
    Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 HOW TO USE:" -ForegroundColor Cyan
    Write-Host "   1. Go to Azure Portal" -ForegroundColor White
    Write-Host "   2. Search for 'Template Specs'" -ForegroundColor White
    Write-Host "   3. Find '$TemplateSpecName'" -ForegroundColor White
    Write-Host "   4. Click 'Deploy' and fill parameters" -ForegroundColor White
    Write-Host ""
    Write-Host "🌐 DIRECT PORTAL LINK:" -ForegroundColor Cyan
    $subscriptionId = $account.id
    $portalUrl = "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Resources/templateSpecs/$TemplateSpecName/versions/$Version"
    Write-Host "   $portalUrl" -ForegroundColor Blue
    Write-Host ""
    Write-Host "✨ Users can now deploy Sentinel with just a few clicks in the Portal!" -ForegroundColor Green
} else {
    Write-Error "❌ Failed to create Template Spec"
}

Write-Host ""
Write-Host "💡 BENEFITS OF TEMPLATE SPECS:" -ForegroundColor Yellow
Write-Host "   ✅ Deploy directly from Azure Portal" -ForegroundColor White
Write-Host "   ✅ No need to download files" -ForegroundColor White
Write-Host "   ✅ Version control built-in" -ForegroundColor White
Write-Host "   ✅ RBAC permissions supported" -ForegroundColor White
Write-Host "   ✅ Appears in Azure Portal catalog" -ForegroundColor White
