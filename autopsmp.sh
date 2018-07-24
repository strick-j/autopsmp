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

# Generic output functions
print_head(){
	white=`tput setaf 7`
	reset=`tput sgr0`
	echo ""
	echo "======================================================"
	echo "${white}$1${reset}"
	echo "======================================================"
	echo ""
}
print_info(){
	white=`tput setaf 7`
	reset=`tput sgr0`
	echo "${white}INFO: $1${reset}"
	echo "INFO: $1" >> autopsmp.log
}
print_success(){
	green=`tput setaf 2`
	reset=`tput sgr0`
	echo "${green}SUCCESS: $1${reset}"
	echo "SUCCESS: $1" >> autopsmp.log
}
print_error(){
	red=`tput setaf 1`
	reset=`tput sgr0`
	echo "${red}ERROR: $1${reset}"
	echo "ERROR: $1" >> autopsmp.log
}

# Main installation functions
system_prep(){
	# Generate initial log file  
	touch autopsmp.log
	echo "Log file generated on $(date)" >> autopsmp.log
}
dir_prompt(){
	print_head "Step 1: Collecting Info"
	# Prompt for directory info of installation folder, verify directory exists
	print_info "Requesting installation directory information"
	read -p 'Please enter the full path for the installation folder directory [e.g. /opt/psmp]: ' foldervar
	if [ -d $foldervar ]; then
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
        if [ "$passvar1" == "$passvar2" ]; then
                print_success "Passwords match as expected, moving on to next step"
                unset passvar2
        else
                print_error "Passwords do not match. Please try again."
                pass_prompt 
        fi
}
cred_create(){
	# Create credential file with username and password provided above
	print_head "Step 2: Modifying Files"
	print_info "Creating Credential File for authorization to Vault"
	# Verify CreateCredFile is present, exit if not
	if [ -f $foldervar/CreateCredFile ];then
		# Modify permissions and create credential file
		chmod 755 $foldervar/CreateCredFile
		$foldervar/CreateCredFile $foldervar/user.cred Password -username $uservar -password $passvar1
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
	if [ -f $foldervar/vault.ini ]; then
		# Modify IP address in vault.ini file
        	cp $foldervar/vault.ini $foldervar/vault.ini.bak
        	sed -i "s+ADDRESS=.*+ADDRESS=$ipvar+g" $foldervar/vault.ini
 	else
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
	if [ -f $foldervar/psmpparms.sample ]; then
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
	print_head "Step 3: Installing PSMP"
	print_info "Verifying rpm GPG Key is present"
	if [ -f $foldervar/RPM-GPG-KEY-CyberArk  ]; then
		# Import GPG Key
		print_info "GPG Key present - Importing..."
		rpm --import $foldervar/RPM-GPG-KEY-CyberArk
	else
		# Error - File not found
		print_error "RPM GPG Key not found, verify needed files have been copied over. Exiting now..."
	fi
	print_info "Verifying PSMP rpm installer is present"
	if [ -f $foldervar/CARKpsmp* ]; then
		# Install CyberArk RPM
		psmprpm=`ls $foldervar | grep CARKpsmp*`
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
	print_head "Step 4: System Cleanup"
	print_info "Removing user.cred, vault.ini, and CreateCredFile Utility"
	rm -f $foldervar/user.cred
	rm -f $foldervar/vault.ini
	rm -f $foldervar/CreateCredFile
	if [ -f $foldervar/user.cred ]||[ -f $foldervar/vault.ini ]||[ -f $foldervar/CreateCredFile ]; then
		print_error "Files could not be deleted, please manually remove..."
	else
		print_success "System cleanup completed"
	fi
}

main
