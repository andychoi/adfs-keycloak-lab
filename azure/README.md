**Setting up testing environment**

The user wants to set up a testing environment mimicking ADFS with Keycloak as a custom IDP and federating between them. I'll recommend using a Windows Server VM, possibly on Azure's free tier or Hyper-V. Since ADFS doesn't work well in containers, using ADFS roles on Windows Server may be best. Alternatively, we can mimic ADFS using SimpleSAMLphp or Azure AD for federation. We should provide step-by-step instructions and offer sample configs, maybe even Docker images, to keep costs low.

**Setting up ADFS and Keycloak federation**

For the testing environment, rather than simulating ADFS, I’ll recommend spinning up a Windows Server VM with the AD FS role on Azure. Then, I’ll configure AD FS to trust Keycloak as a claims provider for federation. This sets up two IDPs: AD FS and Keycloak. I’ll propose using Hyper-V with two VMs, one for AD FS (connected to AD Domain Services) and the other for Keycloak. Alternatively, an Azure Windows VM can be used with AD FS and Keycloak configured.

**Designing ADFS and Keycloak testing environment**

The user wants a testing environment where ADFS and Keycloak are used for federation, with Keycloak as a custom IDP. I’ll recommend using a Windows Server VM in Azure or Hyper-V to set up ADFS, as ADFS can't run in containers easily. Keycloak can be set up as a Docker container, and federating can be done by adding claims provider trusts. Instructions can include high-level steps, with possible Terraform or Azure CLI scripts for automation, though full code isn’t necessary.


Thought for 17 seconds


Below is a step-by-step “lab” you can spin up in Azure (or on-prem/Hyper-V) to test:

1. **ADFS** on Windows Server
2. **Keycloak** as your hmg.Partner custom IdP
3. **Federation** (ADFS trusts Keycloak as a Claims‐Provider)

---

## 1️⃣ Stand up ADFS (Active Directory Federation Services)

AD FS must run on a Windows Server joined to an AD DS domain. You can use an Azure VM with Windows Server evaluation.

### A. Provision a Windows Server VM (Azure CLI)

```bash
# 1. Create resource group & network
az group create -n TestFedRG -l eastus
az network vnet create -g TestFedRG -n TestVNet --address-prefix 10.0.0.0/16 \
  --subnet-name DCSubnet --subnet-prefix 10.0.1.0/24

# 2. Open RDP, HTTP, HTTPS in NSG
az network nsg rule create -g TestFedRG --nsg-name TestVNetNSG -n AllowRDP \
  --protocol Tcp --priority 1000 --destination-port-ranges 3389 --access Allow
az network nsg rule create -g TestFedRG --nsg-name TestVNetNSG -n AllowHTTP \
  --protocol Tcp --priority 1010 --destination-port-ranges 80 --access Allow
az network nsg rule create -g TestFedRG --nsg-name TestVNetNSG -n AllowHTTPS \
  --protocol Tcp --priority 1020 --destination-port-ranges 443 --access Allow

# 3. Create the VM
az vm create -g TestFedRG -n ADFSServer \
  --image Win2022Datacenter --admin-username azureadmin --admin-password 'YourP@ssw0rd!' \
  --vnet-name TestVNet --subnet DCSubnet --nsg TestVNetNSG \
  --public-ip-sku Standard
```

### B. Configure AD DS + ADFS Role (Run in PowerShell via RDP)

1. **Promote to Domain Controller** (this will reboot):

   ```powershell
   Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
   $pw = ConvertTo-SecureString 'YourP@ssw0rd!' -AsPlainText -Force
   Install-ADDSForest `
     -DomainName "contoso.local" `
     -DomainNetbiosName "CONTOSO" `
     -SafeModeAdministratorPassword $pw `
     -InstallDNS
   ```
2. **Install ADFS**:

   ```powershell
   Install-WindowsFeature ADFS-Federation -IncludeManagementTools
   # Obtain or create an SSL cert for adfs.contoso.local, import into Personal store
   $certThumb = (Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -Match "adfs.contoso.local").Thumbprint
   Install-AdfsFarm `
     -CertificateThumbprint $certThumb `
     -FederationServiceName "adfs.contoso.local" `
     -FederationServiceDisplayName "Contoso Test ADFS" `
     -ServiceAccountCredential (Get-Credential CONTOSO\azureadmin)
   ```
3. **Verify**

   * Browse to [https://adfs.contoso.local/FederationMetadata/2007-06/FederationMetadata.xml](https://adfs.contoso.local/FederationMetadata/2007-06/FederationMetadata.xml)

---

## 2️⃣ Stand up Keycloak as hmg.Partner IdP

Keycloak can run in Docker on any Linux VM or even your laptop.

```bash
# On a Linux VM (Ubuntu) or WSL:
sudo apt update && sudo apt install docker.io -y
docker run -d --name keycloak \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:21.1.0 start-dev
```

1. **Log in** at http\://\<keycloak-host>:8080
2. **Create Realm**: `hmg-partner`
3. **Create SAML Client** (so ADFS can import it as a Claims-Provider):

   * Client ID: `hmg-partner-saml`
   * Client Protocol: `saml`
   * Valid Redirect URI / Assertion Consumer Service: (can be left default for metadata)
4. **Export SAML Metadata** at

   ```
   http://<keycloak-host>:8080/realms/hmg-partner/protocol/saml/descriptor
   ```

---

## 3️⃣ Federation: ADFS trusts Keycloak as a Claims‐Provider

1. **Open** “AD FS Management” on your ADFS server.
2. **Right-click** “Claims Provider Trusts” → **Add Claims Provider Trust…**
3. **Import** the Keycloak SAML metadata file (download from the URL above).
4. **Give** it a friendly name (e.g. “hmg.Partner Keycloak”).
5. **Edit** the Claims Rules if needed (e.g. pass-through token, map attributes).

Now when a user goes to an ADFS-protected SP, they will see two login options:

* **CONTOSO** (your AD DS accounts)
* **hmg.Partner** (redirects to Keycloak for authentication)

---

## 4️⃣ Test Your Lab

1. **Relying Party (SP)**: Re-use one of your “Test *…* App” SPs you created earlier (e.g. the SAML 2.0 one).
2. **Configure** its SAML settings in ADFS (as a Relying Party Trust).
3. **Browse** to the SP’s URL → you’ll land at ADFS → choose “hmg.Partner” → Keycloak login → back through ADFS → SP.

---


For a minimal ADFS lab in East US 2 running on a single Standard\_DS1\_v2 VM with Windows Server, you’ll incur three main charge components:

1. **Compute (VM Instance)**

   * **Standard\_DS1\_v2** (1 vCPU, 3.5 GiB RAM) Windows on-demand price in East US 2: **\$0.1170/hour**, which over 30 days →
     \`0.1170 × 24 × 30 ≈ \$85.41/month\` ([CostCalc][1])

2. **OS Disk (Premium SSD P10, 128 GiB)**

   * Premium SSD P10 costs **\$17.92/month** (128 GiB) ([Azure][2])

3. **Public IP (Standard SKU, static IPv4)**

   * Standard public IPv4 static: **\$0.005/hour** → \`0.005 × 24 × 30 ≈ \$3.60/month\` ([Azure][3])

---

### Total Estimated Monthly Cost

| Component     | Monthly Cost |
| ------------- | ------------ |
| VM Compute    | \$85.41      |
| OS Disk (P10) | \$17.92      |
| Public IP     | \$3.60       |
| **Total**     | **\$106.93** |

> **≈ \$107/month** for a single-node ADFS server.

---

## Cost-Saving Opportunities

* **Azure Hybrid Benefit**: If you have existing Windows Server licenses with Software Assurance you can **save up to 40%** on the VM compute cost by removing the built-in OS license charge.
* **1-Year Reserved Instance**: Committing to a 1-year reserved VM can cut compute costs by **up to 40%** as well.
* **Dev/Test Pricing**: If you have an Azure Dev/Test subscription, Windows VM rates are **up to 55% lower**.

