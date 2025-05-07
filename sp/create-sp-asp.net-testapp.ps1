<#
.SYNOPSIS
    Automates creation of three ASP.NET Core SP test apps:
      - OpenID Connect
      - WS-Federation
      - SAML 2.0

.DESCRIPTION
    This script scaffolds a solution and three minimal ASP.NET Core Web apps,
    configures each with the respective authentication protocol, and adds them
    to a single solution. Prerequisites:
      - .NET 6+ SDK installed
      - PowerShell 7+ on Windows or macOS/Linux

.PARAMETER TenantId
    Azure AD tenant (GUID or domain)
.PARAMETER OpenIdClientId
    App ID for the OpenID Connect SP registered in Azure AD
.PARAMETER WsFedMetadataAddress
    Metadata URL of your ADFS (e.g., https://adfs.contoso.local/FederationMetadata/2007-06/FederationMetadata.xml)
.PARAMETER WsFedRealm
    Realm (Wtrealm) configured in your WS-Fed SP registration (e.g., https://localhost:5002/)
.PARAMETER SamlIdpMetadata
    SAML IdP metadata URL (e.g., your custom IdP's metadata endpoint)
.PARAMETER SamlEntityId
    Entity ID configured in your SAML SP registration (e.g., https://localhost:5003/Saml2)
.PARAMETER SamlAcsUrl
    Assertion Consumer Service URL (e.g., https://localhost:5003/Saml2/Acs)
#>
param(
    [Parameter(Mandatory)] [string]$TenantId,
    [Parameter(Mandatory)] [string]$OpenIdClientId,
    [Parameter(Mandatory)] [string]$WsFedMetadataAddress,
    [Parameter(Mandatory)] [string]$WsFedRealm,
    [Parameter(Mandatory)] [string]$SamlIdpMetadata,
    [Parameter(Mandatory)] [string]$SamlEntityId,
    [Parameter(Mandatory)] [string]$SamlAcsUrl
)

# Create a new solution
Write-Host "Creating solution 'TestSPsSolution'..." -ForegroundColor Cyan
dotnet new sln -n TestSPsSolution

# 1) OpenID Connect App
Write-Host "`n[1] Scaffolding OpenID Connect App..." -ForegroundColor Green
dotnet new webapp -o TestOpenIdApp --auth SingleOrg `
    --client-id $OpenIdClientId --tenant-id $TenantId --aad-instance "https://login.microsoftonline.com/"

# Add to solution
dotnet sln add .\TestOpenIdApp\TestOpenIdApp.csproj

# 2) WS-Federation App
Write-Host "`n[2] Scaffolding WS-Federation App..." -ForegroundColor Green

dotnet new webapp -o TestWsFedApp
Push-Location TestWsFedApp

# Add WS-Fed package
dotnet add package Microsoft.AspNetCore.Authentication.WsFederation

# Overwrite Program.cs
$wsFedProgram = @"
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.WsFederation;
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthentication(options => {
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = WsFederationDefaults.AuthenticationScheme;
})
.AddCookie()
.AddWsFederation(options => {
    options.MetadataAddress = "$WsFedMetadataAddress";
    options.Wtrealm = "$WsFedRealm";
});
var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/", () => "Hello WS-Fed!").RequireAuthorization();
app.Run();
"@
Set-Content -Path Program.cs -Value $wsFedProgram -Encoding UTF8
Pop-Location

# Add to solution
dotnet sln add .\TestWsFedApp\TestWsFedApp.csproj

# 3) SAML 2.0 App
Write-Host "`n[3] Scaffolding SAML 2.0 App..." -ForegroundColor Green

dotnet new webapp -o TestSamlApp
Push-Location TestSamlApp

# Add Sustainsys.Saml2 package
dotnet add package Sustainsys.Saml2.AspNetCore2

# Overwrite Program.cs
$samlProgram = @"
using System;
using Microsoft.AspNetCore.Authentication.Cookies;
using Sustainsys.Saml2;
using Sustainsys.Saml2.Configuration;
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthentication(options => {
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = Saml2Defaults.Scheme;
})
.AddCookie()
.AddSaml2(options => {
    options.SPOptions.EntityId = new EntityId("$SamlEntityId");
    options.SPOptions.ReturnUrl = new Uri("$SamlAcsUrl");
    var idp = new IdentityProvider(new EntityId("$SamlIdpMetadata"), options.SPOptions) {
        MetadataLocation = "$SamlIdpMetadata",
        LoadMetadata = true
    };
    options.IdentityProviders.Add(idp);
});
var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/", () => "Hello SAML!").RequireAuthorization();
app.Run();
"@
Set-Content -Path Program.cs -Value $samlProgram -Encoding UTF8
Pop-Location

# Add to solution
dotnet sln add .\TestSamlApp\TestSamlApp.csproj

Write-Host "`n✅ All three SP test apps created in solution 'TestSPsSolution'." -ForegroundColor Green
