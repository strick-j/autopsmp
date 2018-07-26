# autopsmp
Automated CyberArk Privileged Session Manager SSH Proxy Installer.

<p align="center">
    <img src="https://cdn.rawgit.com/strick-j/autopsmp/25b02eb8/examples/psmpinstall.svg">
</p>

# Installation
1. Create a non-root Administrative user prior to running this script. Part of the install process will prevent remote logins from the root user.
2. Login as the non-root user and change directories to the home directory for that user.
3. Clone this git
4. Execute using the following syntax "sudo ./autosnmp/autosnmp.sh"
5. Answer the prompts as requested

# Requirements
1. Prior to running this script you must have access to the needed source files from CyberArk. These files will typically be in a zip file named something similar to "Privileged Session Manager SSH Proxy-Rls-v10.x". To obtain these files, work with your CyberArk Account Rep or Sales Engineer. Additionally, these files are obtainable through the CyberArk Support Vault.
2. You must unzip and copy the entire directory to the server which the installation script is being executed on. Recommended location is /opt/. 

# User Prompts
Prior to installation have the following information on hand:
1. Folder path that the above required files were copied to. (e.g. /opt/PSMP/)
2. Vault Username - Note user requires permissions to perform several activities in the vault, more details can be found in the PAS Installation Guide.
3. Vault User Password
4. Vault IP Address
