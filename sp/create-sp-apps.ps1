# Install just the Applications module (or install Microsoft.Graph for everything)
Install-Module Microsoft.Graph.Applications -Scope CurrentUser

# Sign in with an account that has Application.ReadWrite.All
Connect-MgGraph -Scopes Application.ReadWrite.All

Write-Host "`n=== [OIDC] Create Test OIDC App ==="

# 2.1 Create the App Registration
$oidcApp = New-MgApplication `
  -DisplayName 'Test-OpenID-App' `
  -SignInAudience 'AzureADMyOrg'

# 2.2 Add the Redirect URI
Update-MgApplication `
  -ApplicationId $oidcApp.Id `
  -Web @{ RedirectUris = @('https://localhost:5001/signin-oidc') }

# 2.3 Create its Service Principal
New-MgServicePrincipal -AppId $oidcApp.AppId | Out-Null

Write-Host "→ OpenID Connect App created. AppId = $($oidcApp.AppId)"

Write-Host "`n=== [WS-Fed] Create Test WS-Fed App ==="

# 3.1 Create the base App Registration
$wsFedApp = New-MgApplication `
  -DisplayName 'Test-WSFed-App' `
  -SignInAudience 'AzureADMyOrg'

# 3.2 Assign a (dummy) redirect URI so the portal UI will let you turn on WS-Fed
#      Note: WS-Fed SSO protocol settings must be completed in the portal.
Update-MgApplication `
  -ApplicationId $wsFedApp.Id `
  -Web @{ RedirectUris = @('https://localhost:5002/wsfed') }

# 3.3 Create its Service Principal
New-MgServicePrincipal -AppId $wsFedApp.AppId | Out-Null

Write-Host "→ WS-Fed App created. AppId = $($wsFedApp.AppId)"
Write-Host "⚠️ Now go to Azure Portal → Enterprise Applications → Test-WSFed-App → Single sign-on → WS-Federation to finish configuration."

Write-Host "`n=== [SAML] Create Test SAML App ==="

# 4.1 Create the App Registration
$samlApp = New-MgApplication `
  -DisplayName 'Test-SAML-App' `
  -SignInAudience 'AzureADMyOrg'

# 4.2 (No redirectUri property—SAML setup is portal-driven)
#      You can still pre-populate an IdentifierUris if desired:
# Update-MgApplication -ApplicationId $samlApp.Id -IdentifierUris @('https://test-saml-app')

# 4.3 Create its Service Principal
New-MgServicePrincipal -AppId $samlApp.AppId | Out-Null

Write-Host "→ SAML App created. AppId = $($samlApp.AppId)"
Write-Host "⚠️ Now go to Azure Portal → Enterprise Applications → Test-SAML-App → Single sign-on → SAML to configure:"
Write-Host "   • Identifier (Entity ID):   https://test-saml-app"
Write-Host "   • Reply URL (ACS):          https://localhost:5003/saml/acs"
