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
