 #!/bin/bash

function main(){
  system_prep
  dir_prompt
  info_prompt
  pass_prompt
  mode_prompt
  cred_create
  psmpparms_mod
  vaultini_mod
  install_prerequisites
  install_psmp
  system_cleanup
}

# Global Color Variable
white=`tput setaf 7`
green=`tput setaf 2`
yellow=`tput setaf 3`
red=`tput setaf 1`
reset=`tput sgr0`

# Global Variables
OS=""
VERSION=0
DOCKER=0

# Generic output functions
print_head(){
  echo ""
  echo "======================================================================="
  echo "${white}$1${reset}"
  echo "======================================================================="
  echo ""
}
print_info(){
  echo "${white}$(date) | INFO    | $1${reset}"
  echo "$(date) | INFO    | $1" >> autopsmp.log
}
print_success(){
  echo "${green}$(date) | SUCCESS | $1${reset}"
  echo "$(date) | SUCCESS | $1" >> autopsmp.log
}
print_warning(){
  echo "${yellow}$(date) | WARNING | $1${reset}"
  echo "$(date) | WARNING | $1" >> autopsmp.log
}
print_error(){
  echo "${red}$(date) | ERROR   | $1${reset}"
  echo "$(date) | ERROR   | $1" >> autopsmp.log
}

# Main installation functions
system_prep(){
  print_head "Step 1: System preperation - create log, check for maintenance user"
  
  # Generate initial log file  
  touch autopsmp.log
  echo "Log file generated on $(date)" >> autopsmp.log
  
  # Gather OS Information
  gatherFacts

  # Verifying maintenance user exists
  local username="proxymng"
  print_info "Checking to see if maintenance user \"$username\" exists"
  if id $username >/dev/null 2>&1; then
    print_info "User exists, ensure password is set prior to reboot. Proceeding..."
  else
    local done=0
    while : ; do
      print_warning "Maintenance user does not exist, would you like to create \"$username\" user?"
      select yn in "Yes" "No"; do
        case $yn in
          Yes ) createuser "$username"; done=1; break;;
          No ) print_warning "If you do not create a maintenance user you may not be able to log in after script completes via ssh. Create \"$username\" user?"
            select yn in "Yes" "No"; do
              case $yn in
                Yes ) createuser "$username"; done=1; break;;
                No ) print_warning "Proceeding maintenance user. Manually create before rebooting..."; done=1; break;;
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

  # Check SELinux and recommend enabling if not enabled
  local selinuxEnforcing=""
  selinuxEnforcing=$(sestatus | grep enabled )
  if [! -z "$selinuxEnforcing"] ; then
    print_success "SELinux enabled. Proceeding..."
  else
    print_error "SELinux is not enabled. CyberArk recommends enabling SELinux prior to installation. Exit and enable SELinux?"
    select yn in "Yes" "No"; do
      case $yn in
        Yes ) print_info "Exiting now..."; exit 1;;
        No ) print_warning "Proceeding with SELinux disabled..."; break;;
      esac
    done
  fi

  # Prompt for EULA Acceptance
  print_info "Have you read and accepted the CyberArk EULA?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) print_success "EULA Accepted, proceeding..."; break;;
      No ) print_error "EULA not accepted, exiting now..."; exit 1;;
    esac
  done
 
  # Print Success
  print_info "System preperation completed"
}

gatherFacts(){
  # Container
  if [ -f /.dockerenv ] ; then
    print_warning "Installing PSMP in a docker container is not officially supported. Proceeding...";
    DOCKER=1;
  else
    DOCKER=0;
  fi

  # OS Detection
  if [ -f /etc/os-release ] ; then 
    OS=$(cat /etc/os-release | awk '{ FS = "="} /^ID=/ {print $2}' | sed 's/\"//g');
    VERSION=$(cat /etc/os-release | awk '{ FS = "="} /^VERSION_ID=/ {print $2}' | sed 's/\"//g');
    priint_info "Detected OS: $OS";
    print_info "Detected OS Version: $VERSION";
  fi
}

createuser(){
  echo ""
  #TODO: Add check for wheel group
  print_info "Creating \"$1\" user and setting permissions"
  adduser -g wheel "$1" >/dev/null 2>&1
 
  print_info "Verifying user was created"
  if id "$1" >/dev/null 2>&1; then
    print_success "User created and added to wheel group"
    print_info "Please set password for \"$1\""
    passwd "$1"
  else
    print_error "User could not be created, manually add user prior to reboot"
  fi
}

dir_prompt(){
  print_head "Step 2: Collecting Info"
  # Prompt for directory info of installation folder, verify directory exists
  print_info "Requesting installation directory information"
  read -p 'Please enter the full path for the installation folder directory [e.g. /opt/psmp]: ' foldervar
  if [[ -d $foldervar ]]; then
    # Directory present, subfolders have not been verified
    print_success "Directory information confirmed as: $foldervar"
  else
    # Directory not present, allow user to re-enter path or exit
    print_error "Directory not found, would you like to try again?"
    select yn in "Yes" "No"; do
      case $yn in
        Yes ) dir_prompt; break;;
        No ) print_error "Unable to find installation folder, exiting..."; exit 1;; 
      esac
    done
  fi	
}

info_prompt(){
  # Prompt for Vault IP and Username info
  echo
  print_info "Requesting Vault IP and Username for PSMP Installation"
  print_info "Note: Vault user should be a predefined Administrator or have the appropriate permissions as described in the PSMP install instructions."
  read -erp 'Please enter Vault IP Address: ' ipvar
  read -erp 'Please enter Vault Username: ' uservar
  print_info "Captured $ipvar for Address and $uservar for username. Proceed?"
  select pc in "Proceed" "Change"; do
    case $pc in 
      Proceed ) print_info "Proceeding..."; break;;
      Change ) info_prompt; break ;;
    esac
  done
}

pass_prompt(){
  # Prompt for Vault Password info
  echo 
  print_info "Requesting Vault Password. Password must be entered twice and will be hidden"
  read -serp 'Please enter Vault Password: ' passvar1
  echo
  read -serp 'Please re-enter Vault Password: ' passvar2
  echo
  # Test if passwords match
  if [[ "$passvar1" == "$passvar2" ]]; then
    print_success "Passwords match as expected, moving on to next step"
    vaultpass="$passvar1"
    # Unset password variables
    unset passvar2
    unset passvar1
    echo ""
  else
    print_error "Passwords do not match. Please try again."
    pass_prompt
  fi
}

mode_prompt(){
  # Prompt for CyberArkInstallSSHD mode
  print_info "Desired InstallCyberArkSSHD setting (Integrated, Yes, No): "
  select method in "Integrated" "Yes" "No"; do
    case $method in
      Integrated ) 
        print_info "InstallCyberArkSSHD=Integrated. Proceeding..."
        cyberarksshd="Integrated"
        break;;
      Yes ) 
        print_info "InstallCyberArkSSHD=Yes. Proceeding..."
        cyberarksshd="Yes"
        break;;
      No ) 
        print_info "InstallCyberArkSSHD=No, some limitations apply. Proceeding..."
        cyberarksshd="No"
        break;;
      *)
        Print_error "Invalid option"
        mode_prompt
    esac
  done
  echo ""
}

cred_create(){
  # Create credential file with username and password provided above
  print_head "Step 3: Modifying Files"
  print_info "Creating Credential File for authorization to Vault"
  # Verify CreateCredFile is present, exit if not
  if [[ -f $foldervar/CreateCredFile ]];then
    # Modify permissions and create credential file
    chmod 755 $foldervar/CreateCredFile
    $foldervar/CreateCredFile $foldervar/user.cred Password -username $uservar -password $vaultpass -EntropyFile >> autopsmp.log 2>&1
    # Unset password variable
    unset vaultpass
    vercredvar=$(tail -1 autopsmp.log)
    if [[ "$vercredvar" == "Command ended successfully" ]]; then
      print_success "Credential file created successfully"
    else
      print_error "Credential file not created sueccessfully. Exiting now..."
      exit 1
    fi
  else
    print_error "CreateCredFile file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
}

vaultini_mod(){
  # Modifing vault.ini file with information provided above
  echo
  print_info "Updating vault.ini file with Vault IP: $ipvar"
  # Verify vault.ini file is present, exit if not
  if [[ -f $foldervar/vault.ini ]]; then
    # Modify IP address in vault.ini file
    cp $foldervar/vault.ini $foldervar/vault.ini.bak
    sed -i "s+ADDRESS=.*+ADDRESS=$ipvar+g" $foldervar/vault.ini
  else
    # Error - File not found
    print_error "vault.ini file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  print_success "Completed vault.ini file modifications"
}

psmpparms_mod(){
  # Update psmpparms file with information provided above
  echo
  print_info "Updating psmpparms file with user provided information"
  # Verify psmpparms.sample is present, exit if not
  if [[ -f $foldervar/psmpparms.sample ]]; then
    # Create psmpparms file and modify variables
    cp $foldervar/psmpparms.sample /var/tmp/psmpparms
    sed -i "s+InstallationFolder.*+InstallationFolder=$foldervar+g" /var/tmp/psmpparms
    sed -i "s+AcceptCyberArkEULA=No+AcceptCyberArkEULA=Yes+g" /var/tmp/psmpparms
    sed -i "s+InstallCyberArkSSHD=Integrated+InstallCyberArkSSHD=$cyberarksshd+g" /var/tmp/psmpparms
  else
    # Error - File not found
    print_error "psmpparms.sample file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  print_success "psmpparms file modified and copied to /var/tmp/"
}

install_prerequisites(){
  # Installing PSMP Pre-Requisites using rpm files
  print_head "Step 4: Installing PSMP Pre-Requisites"
  print_info "Verifying Pre-Requisites are present"
  if rpm -qa libssh 2>&1 > /dev/null; then
    print_info "libssh is already installed, skipping..."
  else
    prereqfolder=$foldervar
    prereqfolder+="/Pre-Requisites"
    libsshrpm=`ls $prereqfolder | grep libssh*`
    if [[ -f $prereqfolder/$libsshrpm ]]; then
      # Install libssh
      print_info "libssh present - Installing $librsshrpm"
      echo ""
      rpm -ih $prereqfolder/$libsshrpm
    else
      # Error - File not found
      print_error "libssh rpm not found, verify needed Pre-Requisites have been copied over. Exiting now..."
      exit 1
    fi
  fi

  # Check if installing in integrated mode, if so install infra package
  if [[ $cyberarksshd == "Integrated" ]]; then
    print_info "CyberArkSSHD set to integrated mode. CARKpsmp-infra will be installed."
    infrafolder=$foldervar
    infrafolder+="/IntegratedMode"
    infrarpm=`ls $infrafolder | grep CARKpsmp-infra*`
    if [[ -f $infrafolder/$infrarpm ]]; then
      # Install CARKpsmp-infra
      print_info "CARKpsmp-infra present - Installing $infrarpm"
      echo ""
      rpm -ih $infrafolder/$infrarpm
    else
      # Error - File not found
      print_error "CARKpsmp-infra rpm not found and is required for integrated mode, verify needed Pre-Requisites have been copied over. Exiting now..."
      exit 1
    fi
  fi
}

install_psmp(){
  # Installing PSMP using rpm file
  print_head "Step 5: Installing PSMP"
  print_info "Verifying rpm GPG Key is present"
  if [[ -f $foldervar/RPM-GPG-KEY-CyberArk ]]; then
    # Import GPG Key
    print_info "GPG Key present - Importing..."
    rpm --import $foldervar/RPM-GPG-KEY-CyberArk
  else
    # Error - File not found
    print_error "RPM GPG Key not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  print_info "Verifying PSMP rpm installer is present"
  psmprpm=`ls $foldervar | grep CARKpsmp*`
  if [[ -f $foldervar/$psmprpm ]]; then
    # Install CyberArk RPM
    print_info "PSMP rpm installer present - installing $psmprpm"
    echo ""
    rpm -ih $foldervar/$psmprpm
  else
    # Error - File not found
    print_error "Necessry rpm installer not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
}

service_verification(){
  # Verify services are running. If not running warn user.
  shopt -s nocasematch
  # Docker Container
  if [ $DOCKER == 1 ] ; then
    psmpsrvStatus=$(/etc/init.d/psmpsrv status psmp | grep -i -c "running")
    #psmpadbStatus=$(/etc/init.d/psmpsrv status psmpadb | grep -i -c "running")
  else if [ $DOCKER == 0 ] ; then
  # RHEL 7 / CentOS 7 
    if [ $OS == "centos" ] || [ $OS == "rhel" ]; then
      if [ $VERSION == 7 ] ; then
        psmpsrvStatus=$(service psmpsrv status psmp | grep -i -c "active")
        #psmpadbStatus=$(service psmpsrv status psmpadb | grep -i -c "active")
      else if [ $VERSION == 8 ] ; then
        psmpsrvStatus=$(systemctl status psmpsrv | grep -i -c "active")
      fi
    fi
  fi
  
  if [ $psmpsrvStatus == 0 ] ; then
    print_error "PSM SSH Proxy service is not active. Review logs for errors."
  else
    print_success "PSM SSH Proxy service is active."
  fi
}
system_cleanup(){
  # Cleaning up system files used during install
  print_head "Step 6: System Cleanup"
  print_info "Removing user.cred, vault.ini, and CreateCredFile Utility"
  rm -f $foldervar/user.cred
  rm -f $foldervar/vault.ini
  rm -f $foldervar/CreateCredFile
  if [[ -f $foldervar/user.cred ]]||[[ -f $foldervar/vault.ini ]]||[[ -f $foldervar/CreateCredFile ]]; then
    print_error "Files could not be deleted, please manually remove..."
  else
    print_success "System cleanup completed"
  fi
  echo ""
}
main
