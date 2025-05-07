**Guiding with Graph PowerShell**

The user's dealing with an issue in WS-Federation creation and asks about using the Microsoft Graph PowerShell SDK. I need to guide them through installing it and showing them how to create an app for various protocols like OpenID Connect, WS-Fed, and SAML.

The necessary steps include installing the module, connecting to Microsoft Graph, and using commands like `New-MgApplication`. However, I should clarify the syntax regarding parameters like `-WebRedirectUri`. Let me double-check the exact command syntax for this.

**Providing Graph PowerShell SDK guidance**

I’ll walk the user through creating an app using Microsoft Graph PowerShell. First, I'll outline how to install and connect to Microsoft Graph. Then, I'll show commands for creating an app and service principal for OpenID Connect and WS-Federation. However, Graph PowerShell doesn’t fully support configuring WS-Fed via the SDK, so I'll guide them to manually complete the protocol-specific settings. For SAML, while it supports some Beta features, I'll focus on showing how to create app registrations and service principals, followed by portal configuration instructions.


Thought for 10 seconds


Below is a **pure Microsoft Graph PowerShell SDK** approach. It avoids all the JSON-in-CLI quoting headaches and uses idiomatic cmdlets to:

1. **Create** an AAD application
2. **Set** its redirect URIs
3. **Instantiate** its service principal

You’ll still need to finish **WS-Fed** and **SAML** SSO configuration in the Azure portal, but everything up through SP creation is handled here.

---

## 📦 1. Install & Connect

```powershell
# Install just the Applications module (or install Microsoft.Graph for everything)
Install-Module Microsoft.Graph.Applications -Scope CurrentUser

# Sign in with an account that has Application.ReadWrite.All
Connect-MgGraph -Scopes Application.ReadWrite.All
```

---

## 🔑 2. OpenID Connect App

```powershell
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
```

---

## 🔗 3. WS-Federation App

```powershell
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
```

---

## 🔒 4. SAML 2.0 App

```powershell
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
```

---

### ✅ What This Gives You

* **App registrations** for OIDC, WS-Fed, and SAML in your tenant
* **Service principals** so Azure AD will actually emit tokens/assertions
* **Redirect URIs** set for OIDC and a placeholder for WS-Fed
* A pure-PowerShell workflow with **no manual JSON files**

You can now:

* Upload your **custom IdP metadata** into each SP’s SSO blade
* Test sign-in flows via **SAML-Tracer**, **jwt.ms**, or your own test client

Let me know if you’d like a **PowerShell function** that wraps all three protocols into a single cmdlet!
