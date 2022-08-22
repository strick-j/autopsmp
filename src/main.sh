#!/usr/bin/env bash

set -e

# Version
AUTOPSMP_VERSION="0.0.1-alpha"

# Logging
VAR_TMP_D=/var/tmp
VAR_INSTALL_LOG_F=$VAR_TMP_D/autopsmp_install.log
SHOULD_SHOW_LOGS=1
DEBUG=0

# Generic Variables
ENABLEADBRIDGE=0
CYBERARKSSHD="Integrated"
CYBERARKUSERNAME="Administrator"
CYBERARKPASSWORD="Placeholder"
CYBERARKADDRESS="192.168.100.1"
INSTALLFILES="/tmp"
DRYRUN=0

# Generic output functions (logging, terminal, etc..)
function write_log() {
  if [ $SHOULD_SHOW_LOGS = "1" ] ; then
    echo "$(date) | $1" >> $VAR_INSTALL_LOG_F
    if [ $DEBUG = "1" ] ; then
      echo "debug: $1"
    fi
  fi
}

function write_to_terminal() {
  echo "$(date) |  $1" >> $VAR_INSTALL_LOG_F
  echo "$1"
}

function write_header_to_terminal() {
  echo ""
  echo "======================================================================="
  echo "$1"
  echo "======================================================================="
  echo ""
}

# Functional checks
function check_se_linux() {
  printf "\n"
  # Check SELinux and recommend enabling if not enabled
  write_to_terminal "Checking SELinux status"
  selinuxconfig=/etc/selinux/config
  if test -f "$selinuxconfig" ; then
    local selinuxEnforcing=""
    selinuxEnforcing=$(sestatus | grep enabled )
    if [[ -n $selinuxEnforcing ]] ; then
      write_to_terminal "SELinux enabled, proceeding..."
    else
      write_to_terminal "SELinux is not enabled. CyberArk recommends enabling SELinux prior to installation. Exit and enable SELinux?"
      verify_se_linux
    fi
  else
    write_to_terminal "SELinux config file not found. CyberArk recommends enabling SELinux prior to installation. Exit and enable SELinx?"
    verify_se_linux
  fi
}

function verify_se_linux() {
  select yn in "Yes" "No"; do
    case $yn in
      Yes )  write_to_terminal "Exiting now..."; exit 1;;
      No ) write_to_terminal "Proceeding with SELinux disabled..."; break;;
    esac
  done
}

function accept_eula() {
  printf "\n"
  # Prompt for EULA Acceptance
  write_to_terminal "Have you read and accepted the CyberArk EULA?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) write_to_terminal "EULA Accepted, proceeding..."; break;;
      No ) write_to_terminal "EULA not accepted, exiting now..."; exit 1;;
    esac
  done
}

function enable_ad_bridge {
  printf "\n"
  # Prompt to enable AD Bridge
  write_to_terminal "Enable PSMP AD Bridging?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) write_to_terminal "Install will enable AD Bridging capability, proceeding..."; ENABLEADBRIDGE=1; break;;
      No ) write_to_terminal "Install will not enable AD Bridging capability, proceeding..."; ENABLEADBRIDGE=0; break;;
    esac
  done
}

function dir_prompt {
  printf "\n"
  # Prompt for directory info of installation folder, verify directory exists
  write_to_terminal "Requesting installation directory information:"
  read -rp 'Please enter the full path for the installation folder directory [e.g. /opt/psmp]: ' INSTALLFILES
  if [[ -d $INSTALLFILES ]]; then
    # Check for required installation files in directory
    if [[ ! -f $INSTALLFILES/vault.ini ]] || [[ ! -f $INSTALLFILES/psmpparms.samplei ]] ; then 
      write_to_terminal "Required files not found within directory, would you like to try again?"
      select yn in "Yes" "No"; do
        case $yn in
          Yes ) dir_prompt; break;;
          No ) write_to_terminal "Unable to find required installation files, exiting..."; exit 1;;
        esac
      done
    fi
    # Directory present #TODO: Verify files are present
    write_to_terminal "Directory information confirmed as: $INSTALLFILES, proceeding..."
  else
    # Directory not present, allow user to re-enter path or exit
    write_to_terminal "Directory not found, would you like to try again?"
    select yn in "Yes" "No"; do
      case $yn in
        Yes ) dir_prompt; break;;
        No ) write_to_terminal "Unable to find installation folder, exiting..."; exit 1;; 
      esac
    done
  fi
}

function address_prompt {
  printf "\n"
  write_to_terminal "Requesting Vault IP for installation:"
  read -erp 'Please enter Vault IP Address: ' CYBERARKADDRESS
  local res=0
  
# Check Address  validity
res=$(valid_ip "$CYBERARKADDRESS")
  if [[ $res -eq 0 ]] ; then
    write_to_terminal "Valid IP Address provided, proceeding..."
    confirm_input "$CYBERARKADDRESS" "Address"
  else
    write_to_terminal "Invalid address provided, would you like to try again?"
    select yn in "Yes" "No"; do
      case $yn in 
        Yes ) address_prompt; break;;
        No ) write_to_terminal "Invalid address provided, exiting..."; exit 1;;
      esac
    done
  fi
}

function username_prompt {
  printf "\n"
  write_to_terminal "Requesting Vault Username for installation:"
  read -erp 'Please enter Vault Username: ' CYBERARKUSERNAME
  local res=0

  # Check Username validity
  res=$(valid_username "$CYBERARKUSERNAME")
  if [[ $res -eq 0 ]] ; then
    write_to_terminal "Valid username provided, proceeding..."
    confirm_input "$CYBERARKUSERNAME" "Username"
  else
    case $res in
      2) write_to_terminal "Username is too long.";;
      3) write_to_terminal "Username has a leading or trailing dot or space";;
      4) write_to_terminal "Username contains invalid characters";;
      *) write_to_terminal "Invalid username provided."
    esac
    write_to_terminal "Would you like to try again?"
    select yn in "Yes" "No"; do
      case $yn in 
        Yes ) username_prompt; break;;
        No ) write_to_terminal "Invalid username provided, exiting..."; exit 1;;
      esac
    done
  fi
}

function pass_prompt {
  # Prompt for Vault Password info
  printf "\n"
  write_to_terminal "Requesting Vault Password. Password must be entered twice and will be hidden:"
  read -serp 'Please enter Vault Password: ' passvar1
  echo
  read -serp 'Please re-enter Vault Password: ' passvar2
  echo
  # Test if passwords match
  if [[ "$passvar1" == "$passvar2" ]]; then
    write_to_terminal "Valid password provided, proceeding..."
    CYBERARKPASSWORD="$passvar1"
    # Unset password variables
    unset passvar2
    unset passvar1
  else
    write_to_terminal "Passwords do not match. Please try again."
    pass_prompt
  fi
}

function mode_prompt {
  # Prompt for CyberArkInstallSSHD mode
  printf "\n"
  write_to_terminal "Desired InstallCyberArkSSHD setting (Integrated, Yes, No): "
  select method in "Integrated" "Yes" "No"; do
    case $method in
      Integrated ) 
        write_to_terminal "InstallCyberArkSSHD=Integrated, proceeding..."
        CYBERARKSSHD="Integrated"
        break;;
      Yes ) 
        write_to_terminal "InstallCyberArkSSHD=Yes, proceeding..."
        CYBERARKSSHD="Yes"
        break;;
      No ) 
        write_to_terminal "InstallCyberArkSSHD=No, some limitations apply, proceeding..."
        CYBERARKSSHD="No"
        break;;
      *)
        write_to_terminal "Invalid option."
        mode_prompt
    esac
  done
}

function create_vault_ini {
  # Modifing vault.ini file with information provided above
  printf "\n"
  write_to_terminal "Updating vault.ini file with Vault IP: $CYBERARKADDRESS"
  # Verify vault.ini file is present, exit if not
  if [[ -f $INSTALLFILES/vault.ini ]]; then
    # Modify IP address in vault.ini file
    cp "$INSTALLFILES"/vault.ini "$INSTALLFILES"/vault.ini.bak
    sed -i "s+ADDRESS=.*+ADDRESS=$CYBERARKADDRESS+g" "$INSTALLFILES"/vault.ini
  else
    # Error - File not found
    write_to_terminal "vault.ini file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  write_to_terminal "Completed vault.ini file modifications"
}

function create_credfile {
  printf "\n"
  # Create credential file with username and password provided above
  print_info "Creating Credential File for authorization to Vault"
  # Verify CreateCredFile is present, exit if not
  if [[ -f $INSTALLFILES/CreateCredFile ]];then
    # Modify permissions and create credential file
    chmod 755 "$INSTALLFILES"/CreateCredFile
    "$INSTALLFILES"/CreateCredFile "$INSTALLFILES"/user.cred Password -username "$CYBERARKUSERNAME" -password "$CYBERARKPASSWORD" -EntropyFile >> autopsmp.log 2>&1
    # Unset password variable
    unset CYBERARKPASSWORD 
    vercredvar=$(tail -1 autopsmp.log)
    if [[ "$vercredvar" == "Command ended successfully" ]]; then
      write_to_terminal "Credential file created successfully, proceeding..."
    else
      write_to_terminal "Credential file not created sueccessfully. Exiting now..."
      exit 1
    fi
  else
    write_to_terminal "CreateCredFile file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
}

function create_psmpparms {
  printf "\n"
  # Update psmpparms file with userprovided information
  write_to_terminal "Updating psmpparms file with user provided information"
  # Verify psmpparms.sample is present, exit if not
  if [[ -f $INSTALLFILES/psmpparms.sample ]]; then
    # Create psmpparms file and modify variables
    cp "$INSTALLFILES"/psmpparms.sample /var/tmp/psmpparms
    sed -i "s+InstallationFolder.*+InstallationFolder=$INSTALLFILES+g" /var/tmp/psmpparms
    sed -i "s+AcceptCyberArkEULA=No+AcceptCyberArkEULA=Yes+g" /var/tmp/psmpparms
    sed -i "s+InstallCyberArkSSHD=Integrated+InstallCyberArkSSHD=$CYBERARKSSHD+g" /var/tmp/psmpparms
    if [[ $ENABLEADBRIDGE -eq 0 ]] ; then
      sed -i "s+#EnableADBridge=No+EnableADBridge=Yes+g" /var/tmp/psmparms
    fi
  else
    # Error - File not found
    print_error "psmpparms.sample file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  print_success "psmpparms file modified and copied to /var/tmp/"
}

function validiate_gpgkey {
  printf "\n"
  print_info "Verifying rpm GPG Key is present"
  if [[ -f $INSTALLFILES/RPM-GPG-KEY-CyberArk ]]; then
    # Import GPG Key
    write_to_terminal "GPG Key present - Importing..."
    #TODO: Catch import error
    rpm --import "INSTALLFILES"/RPM-GPG-KEY-CyberArk
  else
    # Error - File not found
    write_to_terminal "RPM GPG Key not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi  
}

function preinstall_libssh {
  write_to_terminal "Verifying Pre-Requisites are present"
  if rpm -qa libssh 2>&1 > /dev/null; then
    write_to_terminal "libssh is already installed, skipping..."
  else
    prereqfolder=$INSTALLFILES
    prereqfolder+="/Pre-Requisites"
    libsshrpm=`ls $prereqfolder | grep libssh*`
    if [[ -f $prereqfolder/$libsshrpm ]]; then
      # Install libssh
      write_to_terminal "libssh present - Installing $librsshrpm"
      rpm -ih $prereqfolder/$libsshrpm
      write_to_terminal "libssh installed, proceeding"
    else
      # Error - File not found
      write_to_terminal "libssh rpm not found, verify needed Pre-Requisites have been copied over. Exiting now..."
      exit 1
    fi
  fi
}

function preinstall_infra {
  printf "\n"
  write_to_terminal "CyberArkSSHD set to integrated mode. CARKpsmp-infra will be installed."
  infrafolder=$INSTALLFILES
  infrafolder+="/IntegratedMode"
  infrarpm=$(find "$infrafolder" -name '*CARKpsmp-infra*')
  if [[ -f $infrarpm ]]; then
    # Install CARKpsmp-infra
    print_info "CARKpsmp-infra present - Installing $infrarpm"
    if [ $DRYRUN -eq 0 ] ; then
      write_to_terminal "Starting install - $infrarpm"
      rpm -ih "$infrarpm"
    else
      write_to_terminal "CARKpsmp-infra rpm found: $infrarpm"
      write_to_terminal "Skipping installation for dryrun, proceeding..."
    fi
  else
    # Error - File not found
    write_to_terminal "CARKpsmp-infra rpm not found and is required for integrated mode, verify needed Pre-Requisites have been copied over. Exiting now..."
    exit 1
  fi
}

function install_psmp {
  printf "\n"
  write_to_terminal "Verifying PSMP rpm installer is present"
  psmprpm=$(find "$INSTALLFILES" -name '*CARKpsmp*')
  if [[ -f $psmprpm ]]; then
    # Install CyberArk RPM
    write_to_terminal "PSMP rpm installer present..."
    printf "\n"
    # Skip installation if dryrun
    if [ $DRYRUN -eq 0 ] ; then
      write_to_terminal "Starting install - $psmprpm"
      rpm -ih "$psmprpm"
    else
      write_to_terminal "CARKpsmp rpm found: $psmprpm"
      write_to_terminal "Skipping installation for dryrun, proceeding..."
    fi
  else
    # Error - File not found
    write_to_terminal "PSMP rpm install file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
}

function clean_install {
  # Cleaning up system files used during install
  write_to_terminal "Removing user.cred, vault.ini, and CreateCredFile Utility"
  rm -f "$INSTALLFILES"/user.cred
  rm -f "$INSTALLFILES"/vault.ini
  rm -f "$INSTALLFILES"/CreateCredFile
  if [[ -f $INSTALLFILES/user.cred ]]||[[ -f $INSTALLFILES/vault.ini ]]||[[ -f $INSTALLFILES/CreateCredFile ]]; then
    write_to_terminal "Files could not be deleted, please manually remove..."
    exit 1
  else
    write_to_terminal "PSMP installation and cleanup completed."
    exit 0
  fi
}

function confirm_input {
  local userinput=$1
  local inputfield=$2
  write_to_terminal "You entered ${userinput} for Vault ${inputfield}. Proceed or enter again?"
  select pc in "Proceed" "Change"; do
    case $pc in
      Proceed ) write_to_terminal "Input confirmed, proceeding..."; break;;
      Change ) 
        case $inputfield in
          Address ) address_prompt; break;;
          Username ) username_prompt; break;;
        esac
    esac
  done
}

function valid_ip() {
  # Check for valid IP Address from user input
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ; then
    OIFS=$IFS
    IFS='.' read -r -a ip <<< "$ip"
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  echo $stat
}

function valid_username() {
  # Vault usernames have the following requirements
  # - No larger than 128 Characters
  # - Cannot start or end with a period or space
  # - cannot contain the following characters
  #   - \/:*?"<>|\t\r\n\x1F
  local username=$1
  local stat=1

  local leading="${username:0:1}"
  local trailing="${username: -1}"

  # Check length, leading and trailing characters, and invalid characters
  if [ "${#username}" -ge 129 ] ; then
    stat=2
  elif [[ $leading = *[\.[:space:]]* ]] || [[ $trailing = *[\.[:space:]]* ]] ; then
    stat=3
  elif [[ $username = *[\\/:*?'"''<''>''|'$'\t\r\n\x1f']* ]] ; then
    stat=4
  else
    stat=0
  fi

  echo $stat
}

function valid_pass() {
  local pass=$1
  local stat=1

  if [ "${#pass}" -le 39 ] ; then
    stat=0
  fi
  
  echo $stat
}
 
function _start_installation {
  write_log "Starting script execution..."

  write_header_to_terminal "Step 1: Validating installation requirements"

  # Check Operating System
  #check_os
  # Check SELinux Status - CyberArk recommends enabling before install
  check_se_linux
  
  # Check for maintenance user  
  #check_maintenance_user

  ### System checks completed
  ###
  ### Begin Gathering information from user

  write_header "Step 2: Collecting installation information."
  # Prompt for EULA Acceptance
  accept_eula

  # Prompt to Enable AD Bridging?
  enable_ad_bridge

  # Prompt for Vault IP Address
  address_prompt

  # Prompt for Vault Username
  username_prompt

  # Prompt for Vault Password
  pass_prompt

  # Prompt for Installation Mode
  mode_prompt

  ### Information gathering completed
  ###
  ### Start installation prep

  write_header "Step 3: Installation Prep"

  # Create vault.ini
  create_vault_ini

  # Create psmpparms
  create_psmpparms

  # Create credential file
  create_credfile

  ### Installation Prep completed
  ###
  ### Start pre installation tasks

  write_header "Step 4: Pre-Installation"

  # Install AD Bridge based on user input
  if [ "$ENABLEADBRIDGE" -eq "1" ] ; then
    preinstall_libssh
  fi

  # Check for Integrated Mode - Install infra package
  if [[ $CYBERARKSSHD == "Integrated" ]] ; then
    preinstall_infra
  fi

  write_header "Step 5: Installation"

  # Install PSMP
  install_psmp

  write_header "Step 5: Installation Verification"
  
  # Check Service Status
  #verify_services

  write_header "Step 5: Installation cleanup"

  # Clean up files created during install (credfile, vault.ini, etc...)
  clean_installation

  write_log "Script execution completed."
}

function _show_help {
  echo "Help Placeholder"  
  exit 0
}

function _show_version {
  echo "$AUTOPSMP_VERSION"
  exit 0
}

function main {
  if [[ $# == 0 ]] ; then
    _start_installation
  fi

  while [[ $# -gt 0 ]]; do
    local opt="$1"

    case "$opt" in
      # Options for quick-exit strategy:
      --dryrun) DRYRUN=1; _start_installation;;
      --debug) DEBUG=1; _start_installation;;
      --help) _show_help;;
      --version) _show_version;;
      *) break;;  # do nothing
    esac
  done
}

if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
  main "$@" # To pass the argument list
fi
