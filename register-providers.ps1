# ============================================================================
# Azure Resource Provider Registration Script (PowerShell)
# This script registers the required resource providers for Microsoft Sentinel
# ============================================================================

Write-Host ""
Write-Host "🔧 AZURE SENTINEL RESOURCE PROVIDER REGISTRATION" -ForegroundColor Green -BackgroundColor Black
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = (az --version | Select-String "azure-cli" | Out-String).Trim()
    Write-Host "✅ Azure CLI detected: $($azVersion.Split()[1])" -ForegroundColor Green
} catch {
    Write-Error "❌ Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if user is logged in
try {
    $currentAccount = az account show 2>$null | ConvertFrom-Json
    if ($currentAccount) {
        Write-Host "✅ Already authenticated as: $($currentAccount.user.name)" -ForegroundColor Green
        Write-Host "📋 Current subscription: $($currentAccount.name)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "🔐 Please log in to Azure..." -ForegroundColor Yellow
    az login --output none
    $currentAccount = az account show | ConvertFrom-Json
    Write-Host "✅ Successfully authenticated as: $($currentAccount.user.name)" -ForegroundColor Green
}

Write-Host ""

# Array of required resource providers
$requiredProviders = @(
    "Microsoft.OperationalInsights",
    "Microsoft.SecurityInsights", 
    "Microsoft.OperationsManagement",
    "Microsoft.Security",
    "Microsoft.Automation"
)

Write-Host "🚀 Registering required resource providers..." -ForegroundColor Yellow
Write-Host ""

# Register each provider
foreach ($provider in $requiredProviders) {
    Write-Host "📋 Checking: $provider" -ForegroundColor Yellow
    
    try {
        # Check current registration status
        $providerStatus = az provider show --namespace $provider --query "registrationState" --output tsv 2>$null
        
        if ($providerStatus -eq "Registered") {
            Write-Host "✅ $provider is already registered" -ForegroundColor Green
        } else {
            Write-Host "🔄 Registering $provider..." -ForegroundColor Yellow
            az provider register --namespace $provider --output none
            
            # Wait for registration to complete
            Write-Host "   Waiting for registration to complete..." -ForegroundColor Gray
            do {
                Start-Sleep -Seconds 5
                $providerStatus = az provider show --namespace $provider --query "registrationState" --output tsv 2>$null
                Write-Host "   Status: $providerStatus" -ForegroundColor Gray
            } while ($providerStatus -eq "Registering")
            
            if ($providerStatus -eq "Registered") {
                Write-Host "✅ $provider registered successfully" -ForegroundColor Green
            } elseif ($providerStatus -eq "RegistrationFailed") {
                Write-Host "❌ $provider registration failed" -ForegroundColor Red
            } else {
                Write-Warning "⚠️ $provider registration status: $providerStatus"
            }
        }
    } catch {
        Write-Warning "⚠️ Could not register $provider : $($_.Exception.Message)"
    }
    
    Write-Host ""
}

Write-Host "🎉 RESOURCE PROVIDER REGISTRATION COMPLETE!" -ForegroundColor Green -BackgroundColor Black
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ All required resource providers are now registered" -ForegroundColor Green
Write-Host "✅ You can now use the 'Deploy to Azure' button safely" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Go back to the GitHub README" -ForegroundColor White
Write-Host "   2. Click the 'Deploy to Azure' button" -ForegroundColor White
Write-Host "   3. Fill in the required parameters" -ForegroundColor White
Write-Host "   4. Deploy Microsoft Sentinel" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
