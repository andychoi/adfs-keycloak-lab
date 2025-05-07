# ─────────────────────────────────────────────────────────────────────────────
#  Prereqs:  
#   Install-Module Az           (if you haven’t already)
#   Connect-AzAccount
# ─────────────────────────────────────────────────────────────────────────────

#───────────────────────────────────────────────────────────────────────────────
# 1) Variables
#───────────────────────────────────────────────────────────────────────────────
$rgName          = "TestFedRG"
$location        = "EastUS2"
$vnetName        = "TestVNet"
$subnetName      = "DCSubnet"
$vnetPrefix      = "10.0.0.0/16"
$subnetPrefix    = "10.0.1.0/24"
$nsgName         = "TestVNetNSG"
$vmName          = "ADFSServer"
$adminUser       = "azureadmin"
$adminPassword   = ConvertTo-SecureString "YourP@ssw0rd!" -AsPlainText -Force
$publicIpName    = "$vmName-PublicIP"
$nicName         = "$vmName-NIC"
$vmSize          = "Standard_DS1_v2"
$imagePublisher  = "MicrosoftWindowsServer"
$imageOffer      = "WindowsServer"
$imageSku        = "2019-Datacenter"   # Datacenter edition (publicly available)

#───────────────────────────────────────────────────────────────────────────────
# 2) Create Resource Group
#───────────────────────────────────────────────────────────────────────────────
Write-Host "Creating Resource Group..." -ForegroundColor Cyan
New-AzResourceGroup -Name $rgName -Location $location | Out-Null

#───────────────────────────────────────────────────────────────────────────────
# 3) Create VNet + Subnet
#───────────────────────────────────────────────────────────────────────────────
Write-Host "Creating VNet and Subnet..." -ForegroundColor Cyan
$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetPrefix

New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $rgName `
    -Location $location `
    -AddressPrefix $vnetPrefix `
    -Subnet $subnet | Out-Null

#───────────────────────────────────────────────────────────────────────────────
# 4) Create NSG + Rules
#───────────────────────────────────────────────────────────────────────────────
Write-Host "Creating NSG and Inbound Rules (RDP/HTTP/HTTPS)..." -ForegroundColor Cyan
$nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $rgName `
    -Location $location `
    -Name $nsgName

# RDP
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "Allow-RDP" `
    -Description "Allow RDP" `
    -Access Allow -Protocol Tcp -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix "*" -SourcePortRange "*" `
    -DestinationAddressPrefix "*" -DestinationPortRange 3389 | Out-Null

# HTTP
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "Allow-HTTP" `
    -Description "Allow HTTP" `
    -Access Allow -Protocol Tcp -Direction Inbound `
    -Priority 1010 `
    -SourceAddressPrefix "*" -SourcePortRange "*" `
    -DestinationAddressPrefix "*" -DestinationPortRange 80 | Out-Null

# HTTPS
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "Allow-HTTPS" `
    -Description "Allow HTTPS" `
    -Access Allow -Protocol Tcp -Direction Inbound `
    -Priority 1020 `
    -SourceAddressPrefix "*" -SourcePortRange "*" `
    -DestinationAddressPrefix "*" -DestinationPortRange 443 | Out-Null

# Apply the NSG
$nsg | Set-AzNetworkSecurityGroup | Out-Null

#───────────────────────────────────────────────────────────────────────────────
# 5) Create Public IP + NIC
#───────────────────────────────────────────────────────────────────────────────
Write-Host "Creating Public IP and Network Interface..." -ForegroundColor Cyan
$pip = New-AzPublicIpAddress `
    -Name $publicIpName `
    -ResourceGroupName $rgName `
    -Location $location `
    -AllocationMethod Dynamic `
    -Sku Standard

$subnetRef = (Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName).Subnets[0]

$nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $rgName `
    -Location $location `
    -SubnetId $subnetRef.Id `
    -NetworkSecurityGroupId $nsg.Id `
    -PublicIpAddressId $pip.Id

#───────────────────────────────────────────────────────────────────────────────
# 6) Create the VM
#───────────────────────────────────────────────────────────────────────────────
Write-Host "Creating Windows Server 2019 VM ($imageSku)..." -ForegroundColor Cyan
$cred = New-Object System.Management.Automation.PSCredential($adminUser, $adminPassword)

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize |
    Set-AzVMOperatingSystem -Windows `
        -ComputerName $vmName `
        -Credential $cred `
        -ProvisionVMAgent `
        -EnableAutoUpdate |
    Set-AzVMSourceImage `
        -PublisherName $imagePublisher `
        -Offer $imageOffer `
        -Skus $imageSku `
        -Version "latest" |
    Add-AzVMNetworkInterface -Id $nic.Id

New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig | Out-Null

Write-Host "✅ VM '$vmName' provisioned in RG '$rgName' (East US 2) with Windows Server 2019 Datacenter." -ForegroundColor Green
