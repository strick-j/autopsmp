#!/bin/bash

function main(){
  system_prep
  dir_prompt
  info_prompt
  pass_prompt
  cred_create
  psmpparms_mod
  vaultini_mod
  install_psmp
  system_cleanup
}

# Global Color Variable
  white=`tput setaf 7`
  reset=`tput sgr0`

# Generic output functions
print_head(){
  echo ""
  echo "======================================================================="
  echo "${white}$1${reset}"
  echo "======================================================================="
  echo ""
}
print_info(){
  echo "${white}INFO: $1${reset}"
  echo "INFO: $1" >> autopsmp.log
}
print_success(){
  green=`tput setaf 2`
  echo "${green}SUCCESS: $1${reset}"
  echo "SUCCESS: $1" >> autopsmp.log
}
print_error(){
  red=`tput setaf 1`
  echo "${red}ERROR: $1${reset}"
  echo "ERROR: $1" >> autopsmp.log
}

# Main installation functions
system_prep(){
  print_head "Step 1: System preperation - create log, check for maintenance user"
  
  # Generate initial log file  
  touch autopsmp.log
  echo "Log file generated on $(date)" >> autopsmp.log

  # Verifying maintenance user exists
  local username="proxymng"
  print_info "Checking to see if maintenance user \"$username\" exists"
  if id $username >/dev/null 2>&1; then
    print_info "User exists, moving on to next step. Ensure password is set  prior to reboot"
  else
    local done=0
    while : ; do
      print_error "Maintenance user does not exist, would you like to create \"$username\" user?"
      select yn in "Yes" "No"; do
        case $yn in
          Yes ) createuser "$username"; done=1; break;;
          No ) echo ""; print_error "If you do not create a maintenance user you may not be able to log in after script completes via ssh. Create \"$username\" user?"
            select yn in "Yes" "No"; do
              case $yn in
                Yes ) createuser "$username"; done=1; break;;
                No ) echo ""; print_error "Continuing without creating maintenance user"; done=1; break;;
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
  echo ""
  print_info "System preperation completed"
}
createuser(){
  echo ""
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
        No ) exit 1;; 
      esac
    done
  fi	
}
info_prompt(){
  # Prompt for Vault IP and Username info
  echo
  print_info "Requesting Vault IP and Username for PSMP Installation"
  read -p 'Please enter Vault IP Address: ' ipvar
  read -p 'Please enter Vault Username: ' uservar
}
pass_prompt(){
  # Prompt for Vault Password info
  echo 
  print_info "Requesting Vault Password. Password must be entered twice and will be hidden"
  read -sp 'Please enter Vault Password: ' passvar1
  echo
  read -sp 'Please re-enter Vault Password: ' passvar2
  echo
  # Test if passwords match
  if [[ "$passvar1" == "$passvar2" ]]; then
    print_success "Passwords match as expected, moving on to next step"
    vaultpass="$passvar1"
    # Unset password variables
    unset passvar2
    unset passvar1
  else
    print_error "Passwords do not match. Please try again."
    pass_prompt
  fi
}
cred_create(){
  # Create credential file with username and password provided above
  print_head "Step 3: Modifying Files"
  print_info "Creating Credential File for authorization to Vault"
  # Verify CreateCredFile is present, exit if not
  if [[ -f $foldervar/CreateCredFile ]];then
    # Modify permissions and create credential file
    chmod 755 $foldervar/CreateCredFile
    $foldervar/CreateCredFile $foldervar/user.cred Password -username $uservar -password $vaultpass >> autopsmp.log 2>&1
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
  else
    # Error - File not found
    print_error "psmpparms.sample file not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
  print_success "psmpparms file modified and copied to /var/tmp/"
}
install_psmp(){
  # Installing PSMP using rpm file
  print_head "Step 4: Installing PSMP"
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
    rpm -ih $foldervar/$psmprpm
  else
    # Error - File not found
    print_error "Necessry rpm installer not found, verify needed files have been copied over. Exiting now..."
    exit 1
  fi
}
system_cleanup(){
  # Cleaning up system files used during install
  print_head "Step 5: System Cleanup"
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
