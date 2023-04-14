#!/usr/bin/env bash

set -e

# Version
AUTOPSMP_VERSION="0.0.2-alpha"

# Logging
VAR_TMP_D="/var/tmp"
VAR_INSTALL_LOG_F=$VAR_TMP_D/autopsmp_install.log
SHOULD_SHOW_LOGS=1
CYBR_DEBUG=1
DEBUG=0

# Generic Variables
ENABLEADBRIDGE=0
CYBERARKSSHD="Integrated"
DRYRUN=0

# Generic output functions (logging, terminal, etc..)
function write_log() {
  if [ ${SHOULD_SHOW_LOGS} -eq 1 ] ; then
    echo "$(date) | INFO  | $1" >> $VAR_INSTALL_LOG_F
    [ ${CYBR_DEBUG} -eq 1 ] && printf 'DEBUG: %s\n' "$1"
  fi
}

function write_error() {
  echo "$(date) | ERROR | $1" >> $VAR_INSTALL_LOG_F
  printf 'ERROR: %s\n' "$1"
}
function write_to_terminal() {
  echo "$(date) | INFO  | $1" >> $VAR_INSTALL_LOG_F
  printf 'INFO: %s\n' "$1"
}

function write_header() {
  echo ""
  echo "======================================================================="
  echo "$1"
  echo "======================================================================="
  echo ""
}

function check_uid() {
  if [[ $(id -u) != "0" ]] ; then
    write_to_terminal "This script must be run as root. Exiting..."
    exit 1
  fi
}

# Functional checks
function check_se_linux() {
  # Check SELinux and recommend enabling if not enabled
  write_to_terminal "Checking SELinux status"
  local selinuxconfig=/etc/selinux/config
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
  printf "\n"
}

function verify_se_linux() {
  select yn in "Yes" "No"; do
    case $yn in
      Yes )  write_to_terminal "Exiting now..."; exit 1;;
      No ) write_to_terminal "Proceeding with SELinux disabled..."; break;;
    esac
  done
}

function disable_nscd() {
  # Check status of nscd service and socket
  nscd_array=("service" "socket")
  for nscd in ${nscd_array[@]}
  do
    nscd="$nscd"
    # Check if service is active, stop if so
    if [[ $(systemctl status nscd.$nscd | awk '/Active:/ {print $2}') = "active" ]] ; then
      write_to_terminal "nscd.${nscd} is active. Stopping nsdc.${nscd}"
      systemctl stop nscd.${nscd}
      if [[ $(systemctl status nscd.$nscd | awk '/Active:/ {print $2}') = "active" ]] ; then
        write_to_terminal "Failed to stop nscd.${nscd} service. Please stop and remove manually. Exiting..."
        exit 1
      else
        write_to_terminal "nscd.${nscd} successfully stopped. Proceeding..."
      fi
    else
      write_to_terminal "nscd.${nscd} is not active. Proceeding..."
    fi

    if [[ $(systemctl is-enabled nscd.$nscd) = "enabled" ]] ; then
      write_to_terminal "nscd.${nscd} is loaded. Attempting to disable"
      systemctl disable nscd.${nscd}
      if [[ $(systemctl is-enabled nscd.$nscd) = "enabled" ]] ; then
        write_to_terminal "Failed to disable nscd.${nscd} service. Please disable manually. Exiting..."
        exit 1
      else
        write_to_terminal "nscd.${nscd} successfully disabled Proceeding..."
      fi
    else
      write_to_terminal "nscd.${nscd} is not loaded. Proceeding..."
    fi
  done   
}

function gather_facts() {
  write_to_terminal "Gathering installation system facts..."
  # Check if system is being installed in docker container and warn end user
  if [[ -f /.dockerenv ]] ; then
    write_to_terminal "Installing PSMP in a docker container is not officially supported. Proceeding..."
    export CYBR_DOCKER=1
  else
    export CYBR_DOCKER=0
  fi

  # Check Operating System
  if [[ -f /etc/os-release ]] ; then
    local os
    local osversion
    os=$(awk '{ FS = "="} /^ID=/ {print $2}' /etc/os-release | sed -e 's/^"//' -e 's/"$//' )
    osversion=$(awk '{ FS = "="} /^VERSION_ID=/ {print $2}' /etc/os-release | sed -e 's/^"//' -e 's/"$//' )
    export CYBR_OS="$os"
    export CYBR_OSVERSION="$osversion"
    write_to_terminal "Detected OS: ${CYBR_OS}"
    write_to_terminal "Detected OS Version: ${CYBR_OSVERSION}"
    write_to_terminal "Proceeding..."
  else
    write_to_terminal "Unable to determine system OS, exiting..."
    exit 1
  fi
}

function accept_eula() {
  # Prompt for EULA Acceptance
  write_to_terminal "Have you read and accepted the CyberArk EULA?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) write_to_terminal "EULA Accepted, proceeding..."; break;;
      No ) write_to_terminal "EULA not accepted, exiting now..."; exit 1;;
    esac
  done
  printf "\n"
}

function enable_ad_bridge() {
  # Prompt to enable AD Bridge
  write_to_terminal "Enable PSMP AD Bridging?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) write_to_terminal "Install will enable AD Bridging capability, proceeding..."; export CYBR_BRIDGE=0; break;;
      No ) write_to_terminal "Install will not enable AD Bridging capability, proceeding..."; export CYBR_BRIDGE=1; break;;
    esac
  done
  printf "\n"
}

function dir_prompt() {
  # Prompt for directory info of installation folder, verify directory exists
  local cybr_dir
  write_to_terminal "Requesting installation directory information:"
  read -rp 'Please enter the full path for the folder containing installation media [e.g. /tmp/psmp]: ' cybr_dir
  if [[ -d $cybr_dir ]]; then
    # Check for required installation files in directory
    if [[ ! -f $cybr_dir/vault.ini ]] || [[ ! -f $cybr_dir/psmpparms.sample ]] ; then 
      write_to_terminal "Required files not found within directory, would you like to try again?"
      select yn in "Yes" "No"; do
        case $yn in
          Yes ) dir_prompt; break;;
          No ) write_to_terminal "Unable to find required installation files, exiting..."; exit 1;;
        esac
      done
    fi
    write_to_terminal "Directory information confirmed as: $cybr_dir, proceeding..."
    export CYBR_DIR=$cybr_dir
    printf "\n"
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

function address_prompt() {
  local cybr_address
  write_to_terminal "Requesting Vault IP for installation:"
  read -erp 'Please enter Vault IP Address: ' cybr_address
  local res=0
  # Check Address  validity
  res=$(valid_ip "$cybr_address")
  if [[ $res -eq 0 ]] ; then
    write_to_terminal "Valid IP Address provided, proceeding..."
    confirm_input "$cybr_address" "Address"
    export CYBR_ADDRESS=$cybr_address
  else
    write_to_terminal "Invalid address provided, would you like to try again?"
    select yn in "Yes" "No"; do
      case $yn in 
        Yes ) address_prompt; break;;
        No ) write_to_terminal "Invalid address provided, exiting..."; exit 1;;
      esac
    done
  fi
  printf "\n"
}

function username_prompt() {
  local cybr_username
  write_to_terminal "Requesting Vault Username for installation:"
  read -erp 'Please enter Vault Username: ' cybr_username
  local res=0
  # Check Username validity
  res=$(valid_username "$cybr_username")
  if [[ $res -eq 0 ]] ; then
    write_to_terminal "Valid username provided, proceeding..."
    confirm_input "$cybr_username" "Username"
    export CYBR_USERNAME=$cybr_username
  else
    case $res in
      2) write_to_terminal "Invalid Username: Username is too long.";;
      3) write_to_terminal "Invalid Username: Username has a leading or trailing dot or space.";;
      4) write_to_terminal "Invalid Username: Username contains invalid characters.";;
      *) write_to_terminal "Invalid Username: Invalid Username provided."
    esac
    write_to_terminal "Would you like to try again?"
    select yn in "Yes" "No"; do
      case $yn in 
        Yes ) username_prompt; break;;
        No ) write_to_terminal "Invalid username provided, exiting..."; exit 1;;
      esac
    done
  fi
  printf "\n"
}

function pass_prompt() {
  local passvar1
  local passvar2
  # Prompt for Vault Password info
  write_to_terminal "Requesting Vault Password. Password must be entered twice and will be hidden:"
  read -serp 'Please enter Vault Password: ' passvar1
  printf "\n"
  read -serp 'Please re-enter Vault Password: ' passvar2
  printf "\n"
  # Test if passwords match
  if [[ "$passvar1" == "$passvar2" ]]; then
    # Check password validity
    res=$(valid_pass "$passvar1")
    if [[ $res -eq 0 ]] ; then
      write_to_terminal "Valid password provided, proceeding..."
      export CYBR_PASS=$passvar1
      # Unset password variables
      unset passvar1 
      unset passvar2
    else
      write_to_terminal "Password is not valid. Please try again."
      pass_prompt
    fi
  else
    write_to_terminal "Passwords do not match. Please try again."
    pass_prompt
  fi
  printf "\n"
}

function mode_prompt() {
  # Prompt for CyberArkInstallSSHD mode
  write_to_terminal "Desired InstallCyberArkSSHD setting (Integrated, Yes, No): "
  select method in "Integrated" "Yes" "No"; do
    case $method in
      Integrated ) 
        write_to_terminal "InstallCyberArkSSHD=Integrated, proceeding..."
        export CYBR_MODE="Integrated"
        break;;
      Yes ) 
        write_to_terminal "InstallCyberArkSSHD=Yes, proceeding..."
        export CYBR_MODE="Yes"
        break;;
      No ) 
        write_to_terminal "InstallCyberArkSSHD=No, some limitations apply, proceeding..."
        export CYBR_MODE="No"
        break;;
      *)
        write_to_terminal "Invalid option selected..."
        mode_prompt
    esac
  done
  printf "\n"
}

# Check environment Variables for non-interactive install:
function read_installation_var() {
  write_to_terminal "Silent installation detected, checking installation variables..."

  env_vars=("CYBR_DIR" "CYBR_ADDRESS" "CYBR_USERNAME" "CYBR_PASS" "CYBR_MODE" "CYBR_BRIDGE")
  for var in "${env_vars[@]}" ; do
    write_log "Reading Variable ${var}"
    installvar=$(awk -F "=" '/'${var}'=/{print $2} ' installconfig.ini | sed -e 's/^"//' -e 's/"$//')
    if [[ $installvar ]] ; then
      write_log "Variable ${var} found, proceeding..."
      write_to_terminal "${installvar}"
      export ${var}="${installvar}"
    else
      write_to_terminal "${var} is not set, exiting..."
      exit 1
    fi
  done

  write_to_terminal "All Environment Variables found, proceeding..."
}

function validate_installation_var() {
  # Use validators to check installation variables read from installconfig.ini
  write_to_terminal "Validating installation variables:"
  [[ $(valid_ip "${CYBR_ADDRESS}") -eq 0 ]] && (write_log "Valid IP found") || (write_error "Invalid IP provided exiting..."; exit 1)
  [[ $(valid_username "${CYBR_USERNAME}") -eq 0 ]] && (write_log "Valid Username found") || (write_error "Invalid Username provided, exiting..."; exit 1)
  [[ $(valid_pass "${CYBR_PASS}") -eq 0 ]] && (write_log "Valid password found") || (write_error "Invalid password provided, exiting..."; exit 1)
  [[ $CYBR_MODE =~ (^[Yy][Ee][Ss]$)|(^[Nn][Oo]$)|(^Integrated$) ]] && (write_log "Valide Installation mode found") || (write_error "Invalid Installation mode provided, exiting..."; exit 1)
  [[ $CYBR_BRIDGE =~ [0-1] ]] && (write_log "Valid AD Bridge mode found") || (write_error "Invalid AD Bridge mode provided, exiting..."; exit 1)
  write_to_terminal "Required installation variables validated, proceeding"
}

function create_vault_ini() {
  # Modifing vault.ini file with information provided above
  write_to_terminal "Updating vault.ini file with Vault IP: ${CYBR_ADDRESS}"
  # Verify vault.ini file is present, exit if not
  if [[ -f ${CYBR_DIR}/vault.ini ]]; then
    write_to_terminal "Found vault.ini, making backup and proceeding..."
    # Modify IP address in vault.ini file
    cp "${CYBR_DIR}"/vault.ini "${CYBR_DIR}"/vault.ini.bak
    sed -i "s+ADDRESS=.*+ADDRESS=${CYBR_ADDRESS}+g" "${CYBR_DIR}"/vault.ini
    write_to_terminal "Completed vault.ini file modifications, proceeding..."
  else
    # Error - File not found
    write_to_terminal "vault.ini file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  printf "\n"
}

function create_credfile() {
  local verifycredfile
  # Create credential file with username and password provided above
  write_to_terminal "Creating Credential File for authorization to Vault"
  # Verify CreateCredFile is present, exit if not
  if [[ -f ${CYBR_DIR}/CreateCredFile ]];then
    # Modify permissions and create credential file
    chmod 755 "${CYBR_DIR}"/CreateCredFile
    "${CYBR_DIR}"/CreateCredFile "${CYBR_DIR}"/user.cred Password -username "${CYBR_USERNAME}" -password "${CYBR_PASS}" -EntropyFile >> autopsmp.log 2>&1
    # Unset password variable
    unset CYBR_PASS
    verifycredfile=$(tail -1 autopsmp.log)
    if [[ "$verifycredfile" == "Command ended successfully" ]]; then
      rm -f autopsmp.log
      write_to_terminal "Credential file created successfully, proceeding..."
    else
      write_to_terminal "Credential file not created sueccessfully. Exiting now..."
      exit 1
    fi
  else
    write_to_terminal "CreateCredFile file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  printf "\n"
}

function create_psmpparms() {
  # Update psmpparms file with userprovided information
  write_to_terminal "Updating psmpparms file with user provided information"
  # Verify psmpparms.sample is present, exit if not
  if [[ -f ${CYBR_DIR}/psmpparms.sample ]]; then
    # Create psmpparms file and modify variables
    cp "${CYBR_DIR}"/psmpparms.sample "$VAR_TMP_D"/psmpparms
    sed -i "s+InstallationFolder.*+InstallationFolder=${CYBR_DIR}+g" "$VAR_TMP_D"/psmpparms
    sed -i "s+AcceptCyberArkEULA=No+AcceptCyberArkEULA=Yes+g" "$VAR_TMP_D"/psmpparms
    sed -i "s+InstallCyberArkSSHD=Integrated+InstallCyberArkSSHD=${CYBR_MODE}+g" "$VAR_TMP_D"/psmpparms
    if [[ ${CYBR_BRIDGE} -eq 0 ]] ; then
      sed -i "s+#EnableADBridge=no+EnableADBridge=Yes+g" "$VAR_TMP_D"/psmpparms
    fi
    if [[ ${CYBR_OS} =~ ^([sS][uUlL][sSeE][eEsS])$ ]] ; then
      sed -i "s+Hardening=Yes+Hardening=No+g" "$VAR_TMP_D"/psmpparms
    fi
    write_to_terminal "psmpparms file modified and copied to $VAR_TMP_D, proceeding..."
  else
    # Error - File not found
    write_to_terminal "psmpparms.sample file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  printf "\n"
}

function preinstall_gpgkey() {
  write_to_terminal "Verifying rpm GPG Key is present"
  if [[ -f ${CYBR_DIR}/RPM-GPG-KEY-CyberArk ]] ; then
    # Import GPG Key
    write_to_terminal "GPG Key present - Importing..."
    #TODO: Catch import error
    rpm --import ${CYBR_DIR}/RPM-GPG-KEY-CyberArk
    write_to_terminal "GPG Key imported, proceeding..."
  else
    # Error - File not found
    write_to_terminal "RPM GPG Key not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi  
  printf "\n"
}

function preinstall_libssh() {
  write_to_terminal "Verifying Pre-Requisites are present"
  if [[ $(rpm -qa | grep "libssh-") ]]; then
    write_to_terminal "libssh is already installed, skipping..."
  else
    local libsshrpm=$(find ${CYBR_DIR} -name '*libssh*')
    if [[ -f $libsshrpm ]]; then
      # Install libssh
      write_to_terminal "libssh present - Installing $libsshrpm"
      rpm -ih "$libsshrpm"
      write_to_terminal "$libsshrpm installed, proceeding..."
    else
      # Error - File not found
      write_to_terminal "libssh rpm not found, verify needed Pre-Requisites have been copied over. Exiting now..."
      exit 1
    fi
  fi
  printf "\n"
}

function preinstall_infra() {
  write_to_terminal "CyberArkSSHD set to integrated mode. CARKpsmp-infra will be installed."
  local infrarpm=$(find ${CYBR_DIR} -name '*CARKpsmp-infra*.rpm')
  if [[ -f $infrarpm ]] ; then
    # Install CARKpsmp-infra
    write_to_terminal "CARKpsmp-infra present - Installing $infrarpm"
    if [ $DRYRUN -eq 0 ] ; then
      write_to_terminal "Starting install - $infrarpm"
      rpm -ih "$infrarpm"
      write_to_terminal "$infrarpm installed, proceeding..."
    else
      write_to_terminal "CARKpsmp-infra rpm found: $infrarpm"
      write_to_terminal "Skipping installation for dryrun, proceeding..."
    fi
  else
    # Error - File not found
    write_to_terminal "CARKpsmp-infra rpm not found and is required for integrated mode, verify needed Pre-Requisites have been copied over. Exiting now..."
    exit 1
  fi
  printf "\n"
}

function install_psmp() {
  write_to_terminal "Verifying PSMP rpm installer is present"
  local psmprpm=$(find ${CYBR_DIR} -name '*CARKpsmp*.rpm' -not -path "*/IntegratedMode*")
  if [[ -f $psmprpm ]] ; then
    # Install CyberArk RPM
    write_to_terminal "PSMP rpm installer present..."
    # Skip installation if dryrun
    if [ $DRYRUN -eq 0 ] ; then
      write_to_terminal "Starting install - $psmprpm"
      rpm -ih "$psmprpm"
      write_to_terminal "PSMP install complete, proceeding..."
    else
      write_to_terminal "CARKpsmp rpm found: $psmprpm"
      write_to_terminal "Skipping installation for dryrun, proceeding..."
    fi
  else
    # Error - File not found
    write_to_terminal "PSMP rpm install file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  printf "\n"
}

function postinstall_integratedsuse() {
  write_to_terminal "Running post installation steps for Integrated Mode on SUSE"
  # Disble nscd module
  local disable_rcnscd=$(rcnscd stop && chkconfig nscd off)
  $disable_rcnscd

  # Fix Symbolic Link
  if [[ -f /etc/pki/tls/certs ]] ; then
    write_log "/etc/pki/tls/certs exists already"
    # Check for symbolic link
  else
    write_to_terminal "Creating /etc/pki/tls/certs"
    mkdir -p /etc/pki/tls/certs
    if [[ -f /etc/pki/tls/certs ]] ; then
      write_to_terminal "Directory created"
    else 
      write_error "Failed to create /etc/pki/tls/certs, manually create directory and symbolic link"
    fi
    # Create symbolic link
    if [[ -f /etc/ssl/ca-bundle.pem ]] ; then 
      ln -s /etc/ssl/ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt
      # TODO: Verify Symbolic link created
    fi
    # Restart PSMP Servive
    if [[ $CYBR_OS = "rhel" ]] && [[ $CYBR_OSVERSION = 8* ]]; then 
      systemctl restart psmpsrv
    else
      service psmpsrv restart
    fi
  fi
  printf "\n"
}

function verify_psmp_rpms() {
  # Add checks for rpm
  if [[ ${CYBR_BRIDGE} -eq 0 ]] ; then 
    write_to_terminal "Verifying libssh rpm is installed"
    local installedlibsshrpm=$(rpm -qa | grep "libssh-")
    if [[ ${installedlibsshrpm} ]] ; then
      write_to_terminal "${installedlibsshrpm} found, proceeding..."
    else 
      write_to_terminal "Required libssh rpm not installed, review logs for errors. Exiting..."
      exit 1
    fi
  fi

  if [[ ${CYBR_MODE} == "Integrated" ]]; then
    write_to_terminal "Verifying PSMP Infra rpm is installed"
    local installedinfrarpm=$(rpm -qa | grep "CARKpsmp-infra")
    if [[ ${installedinfrarpm} ]] ; then
      write_to_terminal "${installedinfrarpm} found, proceeding..."
    else 
      write_to_terminal "PSMP Infra rpm not installed, review logs for errors. Exiting..."
      exit 1
    fi
  fi

  write_to_terminal "Verifying PSMP rpm is installed."
  local installedrpm=$(rpm -q CARKpsmp)
  if [[ ${installedrpm} ]] ; then
    write_to_terminal "${installedrpm} found, proceeding..."
  else 
    write_to_terminal "PSMP rpm not installed, review logs for errors. Exiting..."
    exit 1
  fi
  printf "\n"
}

function verify_psmp_services() {
  # Add checks for service(s) status
  if [[ ${CYBR_BRIDGE} -eq 0 ]] ; then 
    local services_array=("psmp" "psmpadb")
  else
    local services_array=("psmp")
  fi

  for service in ${services_array[@]}
  do
    service="$service"
    write_to_terminal "Checking status of ${service}"
    if [[ $CYBR_OS = "rhel" ]] && [[ $CYBR_OSVERSION = 8* ]]; then 
      if [[ $(systemctl status psmpsrv-${service}server | awk '/Active:/ {print $2}') = "active" ]] ; then
        write_to_terminal "${service} service is active, proceeding..."
      else
        write_to_terminal "${service} service is not active, review logs for errors. Proceeding..."
      fi
    else
      if [[ $(service psmpsrv status ${service} | grep "running") ]] ; then
        write_to_terminal "${service} service is active, proceeding..."
      else
        write_to_terminal "${service} service is not active, review logs for errors. Proceeding..."
      fi
    fi
  done
  printf "\n"
}

function clean_install() {
  # Cleaning up system files used during install
  write_to_terminal "Removing user.cred, vault.ini, and CreateCredFile Utility"
  rm -f "${CYBR_DIR}"/user.cred
  rm -f "${CYBR_DIR}"/vault.ini
  rm -f "${CYBR_DIR}"/CreateCredFile
  if [[ -f ${CYBR_DIR}/user.cred ]]||[[ -f ${CYBR_DIR}/vault.ini ]]||[[ -f ${CYBR_DIR}/CreateCredFile ]]; then
    write_to_terminal "Files could not be deleted, please manually remove..."
    exit 1
  else
    write_to_terminal "PSMP installation and cleanup completed."
    exit 0
  fi

  # Move vault.ini.bak to vault.ini
  mv -f "${CYBR_DIR}"/vault.ini.bak "${CYBR_DIR}"/vault.ini
  printf "\n"
}

function check_maintenance_user() {
  # Verifying maintenance user exists
  local username="proxymng"
  write_to_terminal "Checking to see if maintenance user ${username} exists"
  if id $username >/dev/null 2>&1 ; then
    write_to_terminal "${username} exists. Ensure password is set prior to reboot. Proceeding..."
  else
    local done=0
    while : ; do
      write_to_terminal "Maintenance user ${username} does not exist, would you like to create ${username} user?"
      select yn in "Yes" "No"; do
        case $yn in
          Yes ) create_user "$username"; done=1; break;;
          No ) write_to_terminal "If you do not create a maintenance user you may not be able to log in after script completes via ssh. Create ${username} user?"
            select yn in "Yes" "No"; do
              case $yn in
                Yes ) create_user "$username"; done=1; break;;
                No ) write_to_terminal "Proceeding without creating maintenance user. Manually create before rebooting..."; done=1; break;;
              esac
            done
            if [[ "$done" -ne 0 ]]; then
              break
            fi
        esac
        if [[ "$done" -ne 0 ]]; then
          break
        fi
      done
      if [[ "$done" -ne 0 ]]; then
        break
      fi
    done
  fi
  printf "\n"
}

function create_user() {
  write_to_terminal "Creating ${1} user and setting permissions"
  adduser "$1" >/dev/null 2>&1

  local usergroup_array=("wheel" "admin" "PSMConnectUsers")

  for usergroup in ${usergroup_array[@]}
  do
    usergroup="$usergroup"
    write_to_terminal "Checking for group - ${usergroup}"
    if [ $(getent group ${usergroup}) ] ; then
      write_to_terminal "${usergroup} found. Adding ${1} to ${usergroup}"
      usermod -aG ${usergroup} "$1" >/dev/null 2>&1
    fi
  done
  
  write_to_terminal "Verifying user ${1} was created"
  if id "$1" >/dev/null 2>&1 ; then
    write_to_terminal "User ${1} created"
    write_to_terminal "Please set password for \"$1\""
    passwd "$1"
  else
    write_to_terminal "User could not be created, manually add user prior to reboot"
  fi
  printf "\n"
}

function confirm_input() {
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
  declare desc="Validates password meets CyberArk requirements."
  local pass=$1
  local stat=1

  if [ "${#pass}" -le 39 ] ; then
    stat=0
  fi
  
  echo $stat
}

function _start_silent_install() {
  # TODO: Build out SILENT INSTALL

  # Check to verify script is being run as root
  check_uid

  # Check Operating System
  gather_facts

  # Disable NSCD - CyberArk recommends disabling to prevent unexpected behavior
  disable_nscd

  # Check for required environment variables
  read_installation_var

  # Validate installation variables
  validate_installation_var

  # Create vault.ini
  create_vault_ini

  # Create psmpparms
  create_psmpparms

  # Create credential file
  create_credfile

  # Import GPGKEY
  preinstall_gpgkey

  # Install AD Bridge based on user input
  if [ ${CYBR_BRIDGE} -eq 0 ] ; then
    preinstall_libssh
  fi

  # Check for Integrated Mode - Install infra package
  if [[ ${CYBR_MODE} == "Integrated" ]] ; then
    preinstall_infra
  fi

  # Install PSMP
  install_psmp

  # Check if OS is SUSE, if so check for integrated mode and run post install steps
  if [[ ${CYBR_OS} =~ ^([sS][uUlL][sSeE][eEsS])$ ]] ; then
    if [[ ${CYBR_MODE} == "Integrated" ]] ; then
      postinstall_integratedsuse
    fi
  fi

  # Verify RPM Status
  verify_psmp_rpms

  # Check Service Status
  verify_psmp_services
 
  # Check for maintenance user  
  check_maintenance_user
 
  # Clean up files created during install (credfile, vault.ini, etc...)
  clean_install

  # Clean exit
  exit 0
}

function _start_interactive_install() {
  ### Begin System Validation

  write_header "Step 1: Validating installation requirements"

  # Check to verify script is being run as root
  check_uid

  # Check Operating System
  gather_facts

  # Check SELinux Status - CyberArk recommends enabling before install
  check_se_linux

  # Disable NSCD - CyberArk recommends disabling to prevent unexpected behavior
  disable_nscd
  
  ### System validation completed
  ###
  ### Begin Gathering information from user

  write_header "Step 2: Collecting installation information."
  # Prompt for EULA Acceptance
  accept_eula

  # Prompt for directory with installation media
  dir_prompt

  # Prompt for Vault IP Address
  address_prompt

  # Prompt for Vault Username
  username_prompt

  # Prompt for Vault Password
  pass_prompt

  # Prompt for Installation Mode
  mode_prompt

  # Prompt to Enable AD Bridging?
  enable_ad_bridge

  ### Information gathering completed
  ###
  ### Begin installation prep

  write_header "Step 3: Installation Prep"

  # Create vault.ini
  create_vault_ini

  # Create psmpparms
  create_psmpparms

  # Create credential file
  create_credfile

  ### Installation Prep completed
  ###
  ### Being Pre-Installation

  write_header "Step 4: Pre-Installation"

  # Import GPGKEY
  preinstall_gpgkey

  # Install AD Bridge based on user input
  if [ ${CYBR_BRIDGE} -eq 0 ] ; then
    preinstall_libssh
  fi

  # Check for Integrated Mode - Install infra package
  if [[ ${CYBR_MODE} == "Integrated" ]] ; then
    preinstall_infra
  fi
  
  ### Pre-Installation Completed
  ###
  ### Begin Installation

  write_header "Step 5: Installation"

  # Install PSMP
  install_psmp

  ### Installation Complete
  ### 
  ### Begin Post Installation Steps

  write_header "Step 6: Post Installation"

  if [[ ${CYBR_OS} =~ ^([sS][uUlL][sSeE][eEsS])$ ]] ; then
    if [[ ${CYBR_MODE} == "Integrated" ]] ; then
      postinstall_integratedsuse
    fi
  fi

  write_header "Step 7: Installation Verification"
  
  # Verify RPM Status
  verify_psmp_rpms

  # Check Service Status
  verify_psmp_services

  ### Installation Verification Complete
  ### 
  ### Check for maintenance existence and user access

  write_header "Step 8: Maintenance Access Verification"
  
  # Check for maintenance user  
  check_maintenance_user

  ### Installation Complete
  ### 
  ### Begin Installation Cleanup
  
  write_header "Step 9: Installation Cleanup"
  
  # Clean up files created during install (credfile, vault.ini, etc...)
  clean_install

  # Clean exit
  exit 0
}

function _show_help {
  printf "%s" "$(<help.txt)"  
  exit 0
}

function _show_version {
  echo "$AUTOPSMP_VERSION"
  exit 0
}

function main {
  if [[ $# == 0 ]] ; then
    _start_interactive_install
  fi

  while [[ $# -gt 0 ]]; do
    local opt="$1"

    case "$opt" in
      # Options for quick-exit strategy:
      --silent) _start_silent_install;;
      --dryrun) export CYBR_DRYRUN=1; _start_interactive_install;;
      --debug) export CYBR_DEBUG=1; _start_interactive_install;;
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
