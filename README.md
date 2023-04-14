# autopsmp
Automated CyberArk Privileged Session Manager SSH Proxy Installer.

# Installation
1. Create a non-root Administrative user with the name "proxymng"  prior to running this script. Part of the install process may prevent remote logins from the root user and will only allow logins as "proxymng". If you create an account with a different username the script will ask you if you would like to create the user "proxymng" upon execution.
2. Login as the non-root user, "proxymng" and change to the user home directory.
3. Clone this git (i.e. git clone https://github.com/strick-j/autopsmp).
4. Execute using the following syntax "sudo ./autopsmp/src/main.sh".
5. Answer the prompts as requested, required prompt information is covered below.

# Requirements
1. Prior to running this script you must have access to the needed source files from CyberArk. These files will typically be in a zip file named something similar to "Privileged Session Manager SSH Proxy-Rls-v13.x". To obtain these files, work with your CyberArk Account Rep or Sales Engineer. Additionally, these files are obtainable through the CyberArk Support Vault.
2. You must unzip and copy the entire directory to the server which the installation script is being executed on. Recommended location is /home/proxymng or /home/admin

# User Prompts
Prior to installation have the following information on hand:
1. Accept Eula
2. Folder path that the above required files were copied to. (e.g., /root/PSMP/ or /home/PSMP)
3. Vault IP Address
4. Vault Username - Note user requires permissions to perform several activities in the vault, more details can be found in the PAS Installation Guide.
5. Vault User Password
6. Vault Installation Mode - Integrated, Yes, No
7. Vault AD Bridge Install - Yes, No
8. Maintenance User (proxymng) account creation prompt
