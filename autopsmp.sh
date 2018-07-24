#!/bin/bash

function main(){
#	system_prep
#	dir_prompt
	info_prompt
	pass_prompt
#	cred_create
#	psmpparms_mod
#	vaultini_modi
#	install_psmp
}

# Generic output functions
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
        echo
}
cred_create(){
	# Create credential file with username and password provided above
	echo
	print_info "Creating Credential File for authorization to Vault"
	chmod 755 $foldervar/CreateCredFile
	$foldervar/CreateCredFile user.cred /Username admin /Password Cyberark1 /ExternalAuth No
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
		print_error "psmpparms.sample file not found, verify needed files have been copied over. Exiting now..."
		exit 1
	fi
	print_success "psmpparms file modified and copied to /var/tmp/"
}
install_psmp(){
	# Installing PSMP using rpm file
	echo
	print_info "Verifying rpm GPG Key is present and importing..."
	if [ -f $foldervar/RPM-GPG-KEY-CyberArk  ]; then
		rpm --import $foldervar/RPM-GPG-KEY-CyberArk
	else
		print_error "RPM GPG Key not found, verify needed files have been copied over. Exiting now..."
	fi
	print_info "Verifying PSMP rpm installer is present and installing..."
	if [ -f $foldervar/CARKpsmp-10.4.0-15.x86_64.rpm ]; then
		rpm -ih CARKpsmp-10.4.0-15.x86_64.rpm
	else
		print_error "necessry rpm installer not found, verify needed files have been copied over. Exiting now..."
		exit 1
	fi
}
main
