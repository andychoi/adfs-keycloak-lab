# ./adfs/bootstrap.ps1

$ErrorActionPreference = 'Stop'

Write-Host "[ADFS] Installing Windows Features..."
Install-WindowsFeature AD-Domain-Services, ADFS-Federation, RSAT-AD-Tools -IncludeManagementTools

Write-Host "[ADFS] Promoting to Domain Controller..."
$domain = $env:DOMAIN
$adminPass = ConvertTo-SecureString $env:ADMIN_PASS -AsPlainText -Force
Install-ADDSForest -DomainName $domain -SafeModeAdministratorPassword $adminPass -Force

# Wait a bit after promotion (reboot would normally occur)
Start-Sleep -Seconds 10

Write-Host "[ADFS] Installing Self-Signed Cert..."
$cert = New-SelfSignedCertificate -DnsName $env:ADFS_FQDN -CertStoreLocation Cert:\LocalMachine\My
$thumbprint = $cert.Thumbprint

Write-Host "[ADFS] Installing ADFS Farm..."
$cred = New-Object PSCredential ("$domain\\Administrator", $adminPass)
Install-AdfsFarm -CertificateThumbprint $thumbprint -FederationServiceName $env:ADFS_FQDN -FederationServiceDisplayName "Local ADFS" -ServiceAccountCredential $cred

Write-Host "[ADFS] Bootstrap complete."

# Add Claims Provider Trust for Keycloak
Write-Host "[ADFS] Adding Keycloak Claims Provider Trust..."

$metadataUrl = "http://keycloak.local:8080/realms/hmg-partner/protocol/saml/descriptor"
$displayName = "Keycloak (hmg.partner)"
$trustName = "KeycloakPartner"

Add-AdfsClaimsProviderTrust `
  -Name $trustName `
  -MetadataURL $metadataUrl `
  -EnableAlwaysRequireAuthentication $true `
  -Identifier "urn:keycloak:hmg-partner" `
  -AcceptanceTransformRules '=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", Value = c.Value);'

Write-Host "[ADFS] Keycloak Claims Provider Trust added."

Write-Host "[ADFS] Adding Relying Party Trust for Test SAML SP..."

$relyingPartyName = "Test-SAML-SP"
$spMetadataUrl = "https://localhost:5003/Saml2"  # Your SP metadata URL
$identifier = "https://localhost:5003/Saml2"

Add-AdfsRelyingPartyTrust `
  -Name $relyingPartyName `
  -MetadataUrl $spMetadataUrl `
  -Identifier $identifier `
  -EnableSamlResponseSignature $true `
  -SigningCertificateRevocationCheck None `
  -EncryptClaims $false

Set-AdfsRelyingPartyTrust -TargetName $relyingPartyName `
  -IssuanceAuthorizationRules '=> issue(Type = "http://schemas.microsoft.com/authorization/claims/permit", Value = "true");'

Write-Host "[ADFS] Relying Party Trust for Test-SAML-SP added."
