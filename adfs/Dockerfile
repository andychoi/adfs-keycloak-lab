# ./adfs/Dockerfile
# escape=`
FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# Install required Windows features
RUN Install-WindowsFeature AD-Domain-Services, ADFS-Federation, RSAT-AD-Tools -IncludeManagementTools

# Copy bootstrap script into container
COPY bootstrap.ps1 C:/adfs/bootstrap.ps1

# Expose required ports
EXPOSE 80 443
