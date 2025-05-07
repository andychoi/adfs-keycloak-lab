**Guiding with Graph PowerShell**

The user's dealing with an issue in WS-Federation creation and asks about using the Microsoft Graph PowerShell SDK. I need to guide them through installing it and showing them how to create an app for various protocols like OpenID Connect, WS-Fed, and SAML.

The necessary steps include installing the module, connecting to Microsoft Graph, and using commands like `New-MgApplication`. However, I should clarify the syntax regarding parameters like `-WebRedirectUri`. Let me double-check the exact command syntax for this.

**Providing Graph PowerShell SDK guidance**

I’ll walk the user through creating an app using Microsoft Graph PowerShell. First, I'll outline how to install and connect to Microsoft Graph. Then, I'll show commands for creating an app and service principal for OpenID Connect and WS-Federation. However, Graph PowerShell doesn’t fully support configuring WS-Fed via the SDK, so I'll guide them to manually complete the protocol-specific settings. For SAML, while it supports some Beta features, I'll focus on showing how to create app registrations and service principals, followed by portal configuration instructions.



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


# three minimal ASP.NET Core apps configured for:

- OpenID Connect (via --auth SingleOrg)
- WS-Federation (using Microsoft.AspNetCore.Authentication.WsFederation)
- SAML 2.0 (using Sustainsys.Saml2.AspNetCore2)



| App               | Protocol       | What You’ll See Before Login  | What You’ll See After Login            |
| ----------------- | -------------- | ----------------------------- | -------------------------------------- |
| **TestOpenIdApp** | OpenID Connect | Browser redirects to Azure AD | Razor page (default home) → you’re in! |
| **TestWsFedApp**  | WS-Federation  | Browser redirects to ADFS     | Plain text “Hello WS-Fed!”             |
| **TestSamlApp**   | SAML 2.0       | Browser redirects to SAML IdP | Plain text “Hello SAML!”               |

---

## How it works under the hood

1. **Authentication middleware**
   In each `Program.cs` we call:

   ```csharp
   app.UseAuthentication();
   app.UseAuthorization();
   ```

   That wires up the challenge flow for the chosen protocol.

2. **Protected endpoint**
   We map the root (`"/"`) with:

   ```csharp
   app.MapGet("/", () => "Hello …!").RequireAuthorization();
   ```

   requiring a valid auth ticket before responding.

3. **Challenge → Callback**

   * **Unauthenticated** requests get a 302 → your IdP.
   * **On success**, the middleware issues a local cookie.
   * **Subsequent** calls to `/` or the callback path return 200 + “Hello …!”

---

## Quick test steps

1. **Run all three** (from the solution folder):

   ```bash
   dotnet run --project TestOpenIdApp
   dotnet run --project TestWsFedApp
   dotnet run --project TestSamlApp
   ```
2. **Browse** (in separate tabs):

   * `https://localhost:5001/` → redirects to Azure AD → back to home page
   * `https://localhost:5002/` → redirects to ADFS → back and shows “Hello WS-Fed!”
   * `https://localhost:5003/` → redirects to Keycloak (or your SAML IdP) → “Hello SAML!”

If you see the “Hello …!” message, the SSO dance succeeded. If you stay on a login page or get a 401, check your redirect/metadata URLs and certs.
