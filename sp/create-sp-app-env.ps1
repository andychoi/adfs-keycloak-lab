# Load environment variables
. "$PSScriptRoot\..\dotenv.ps1"

# Install Graph module if not installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Applications)) {
  Install-Module Microsoft.Graph.Applications -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Applications

# Sign in with an account that has Application.ReadWrite.All
Connect-MgGraph -Scopes Application.ReadWrite.All

# Retrieve access token for beta REST API
$token = (Get-MgContext).AccessToken
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

Write-Host "`n=== [OIDC] Create Test OIDC App ==="

$oidcApp = New-MgApplication `
  -DisplayName 'Test-OpenID-App' `
  -SignInAudience 'AzureADMyOrg'

Update-MgApplication `
  -ApplicationId $oidcApp.Id `
  -Web @{ RedirectUris = @($env:OIDC_REDIRECT_URI) }

New-MgServicePrincipal -AppId $oidcApp.AppId | Out-Null

Write-Host "→ OpenID Connect App created. AppId = $($oidcApp.AppId)"

Write-Host "`n=== [WS-Fed] Create Test WS-Fed App ==="

$wsFedApp = New-MgApplication `
  -DisplayName 'Test-WSFed-App' `
  -SignInAudience 'AzureADMyOrg'

Update-MgApplication `
  -ApplicationId $wsFedApp.Id `
  -Web @{ RedirectUris = @($env:WSFED_REDIRECT_URI) }

New-MgServicePrincipal -AppId $wsFedApp.AppId | Out-Null

Write-Host "→ WS-Fed App created. AppId = $($wsFedApp.AppId)"

$wsFedSettings = @{
  preferredSingleSignOnMode = "wsFed"
  singleSignOnSettings = @{
    relayState = $env:WSFED_REDIRECT_URI
  }
}
Invoke-RestMethod `
  -Uri "https://graph.microsoft.com/beta/applications/$($wsFedApp.Id)" `
  -Headers $headers `
  -Method PATCH `
  -Body ($wsFedSettings | ConvertTo-Json -Depth 3)
Write-Host "✅ WS-Federation SSO mode set via Graph Beta API"

Write-Host "`n=== [SAML] Create Test SAML App ==="

$samlApp = New-MgApplication `
  -DisplayName 'Test-SAML-App' `
  -SignInAudience 'AzureADMyOrg'

New-MgServicePrincipal -AppId $samlApp.AppId | Out-Null

Write-Host "→ SAML App created. AppId = $($samlApp.AppId)"

$samlSp = Get-MgServicePrincipal -Filter "AppId eq '$($samlApp.AppId)'"
$samlSettings = @{
  preferredSingleSignOnMode = "saml"
  singleSignOnSettings = @{
    relayState = $env:SAML_ACS
  }
}
Invoke-RestMethod `
  -Uri "https://graph.microsoft.com/beta/servicePrincipals/$($samlSp.Id)" `
  -Headers $headers `
  -Method PATCH `
  -Body ($samlSettings | ConvertTo-Json -Depth 3)
Write-Host "✅ SAML SSO mode set via Graph Beta API"

Write-Host "`n✅ All three test SPs created and configured successfully."
