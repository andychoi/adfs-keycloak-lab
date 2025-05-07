Here's the starting point of your infrastructure-as-code ADFS + Keycloak lab, including:

A docker-compose.yml with:
- ADFS service (built from ./adfs/Dockerfile)
- Keycloak container (latest dev-mode image)
- Persisted state volume for ADFS

The ADFS + Keycloak lab is now fully scripted for docker-compose up --build.

🧱 What’s Included
1. docker-compose.yml

ADFS container (hostname: adfs.contoso.local)

Keycloak (hostname: keycloak.local)

Volume adfs-state for persistent AD + ADFS config

2. ./adfs/ directory

Dockerfile (next step)

bootstrap.ps1: Installs AD DS + ADFS, creates self-signed cert, promotes and provisions

    
---

### 📂 Final Directory Structure

```
adfs-keycloak-lab/
├── docker-compose.yml
└── adfs/
    ├── Dockerfile
    └── bootstrap.ps1
```

---

### ✅ To Run the Lab

1. **Switch Docker to Windows Containers**

   * Right-click Docker tray icon → “Switch to Windows containers…”

2. **Update your `hosts` file**

   ```
   127.0.0.1  adfs.contoso.local
   127.0.0.1  keycloak.local
   ```

3. **Launch the lab**

   ```powershell
   docker-compose up --build
   ```

---

# Must be in Windows container mode
docker-compose -f adfs-docker-compose.yml up --build

cd keycloak
docker-compose up -d

# Hosts File (Windows)
Ensure this is in your C:\Windows\System32\drivers\etc\hosts:

127.0.0.1 adfs.contoso.local
127.0.0.1 keycloak.local

# Admin UI & Test Access
- ADFS Metadata: https://adfs.contoso.local/FederationMetadata/2007-06/FederationMetadata.xml
- Keycloak Admin UI: http://keycloak.local:8080 → admin / admin


# Expose your local apps publicly (via ngrok)
If you don’t want to fuss with certificates or host files, use ngrok to get a real HTTPS endpoint:

```
ngrok http 5001
ngrok will give you a URL like https://abcd1234.ngrok.io.
```

Go back to your Azure AD app’s Redirect URIs and replace https://localhost:5001/signin-oidc with https://abcd1234.ngrok.io/signin-oidc.

Restart your SP app (still listening on localhost:5001).

Now Azure AD can redirect through the ngrok URL → your local server.