#!/bin/bash

# Tonton Jo - 2021
# Join me on Youtube: https://www.youtube.com/c/tontonjo

# This little tool is aimed to set some default configurations up and running in not time

# DISCLAIMER
# I assume you know what you are doing have a backup and have a default configuration.
# I'm responsible in no way if something get broken - even if there's likely no chance to happen:-)
# I am no programmer - just tying to get some begginers life a bit easier
# There will be bugs or things i did not thinked about - sorry - if so, try to solve-it yourself, let me kindly know and PR
# Backup and restore has not been extensivly tested - and has never been tested on cluster configurations - Dont count on it too much

# USAGE
# You can use this tool either with:
# git clone https://github.com/Tontonjo/proxmox_toolbox.git
# bash proxmox_toolbox/proxmox_toolbox.sh
# OR
# wget https://raw.githubusercontent.com/Tontonjo/proxmox_toolbox/main/proxmox_toolbox.sh
# bash proxmox_toolbox.sh

# SOURCES:
# https://pve.proxmox.com/wiki/Fail2ban
# https://github.com/inettgmbh/fail2ban-proxmox-backup-server
# https://forum.proxmox.com/threads/how-do-i-set-the-mail-server-to-be-used-in-proxmox.23669/
# https://linuxscriptshub.com/configure-smtp-with-gmail-using-postfix/
# https://suoption_pickedpport.google.com/accounts/answer/6010255
# https://www.howtoforge.com/community/threads/solved-problem-with-outgoing-mail-from-server.53920/
# http://mhawthorne.net/posts/2011-postfix-configuring-gmail-as-relay/
# https://docs.oracle.com/en/cloud/cloud-at-customer/occ-get-started/add-ssh-enabled-user.html
# https://www.noobunbox.net/serveur/monitoring/configurer-snmp-v3-sous-debian
# https://blog.lbdg.me/proxmox-best-performance-disable-swappiness/
# https://gist.github.com/mrpeardotnet/6bdc4b504f43ce57fa7eaee96d376edf
# https://github.com/DerDanilo/proxmox-stuff/blob/master/prox_config_backup.sh
# https://pve.proxmox.com/wiki/Upgrade_from_6.x_to_7.0
# https://www.linuxtricks.fr/wiki/proxmox-quelques-infos


# TODO:
# settings for zram -> https://pve.proxmox.com/wiki/Zram
# PBS: add support for user creation and backup / restoration
# make things stupid-proof (deny characters when numbers expected ans so on)
# add "sleep" when needed to read output
# Cosmetic corrections

# Proxmox_toolbox
version=3.0
# V1.0: Initial Release
# V1.1: correct detecition of subscription message removal
# V2.0: Add backup and restore - reworked menu order - lots of small changes
# V2.2: add confirmation to disable root@pam which is required to update from web UI - add more choices in security settings
# V2.3: Add check of swap existence to allow swap setting configuration
# V2.4: Add check of root rights
# V2.5: Ensure swap setting resist reboot
# V2.6: Much better and smarter way to remove subscription message (credits to @adrien Linuxtricks)
# V2.7: Fix remove subscription message detection
# V3.0: Remove useless mutiple versions for better clarity

# check if root
if [[ $(id -u) -ne 0 ]] ; then echo "- Please run as root / sudo" ; exit 1 ; fi

# -----------------ENVIRONNEMENT VARIABLES----------------------
dnstesthost=google.ch
pve_log_folder="/var/log/pve/tasks/"
proxmoxlib="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
distribution=$(. /etc/*-release;echo $VERSION_CODENAME)
execdir=$(dirname $0)
hostname=$(hostname)
date=$(date +%Y_%m_%d-%H_%M_%S)
backupdir="/root/" #trailing slash is mandatory
pve_backup_content="/etc/ssh/sshd_config /root/.ssh/ /etc/fail2ban/ /etc/systemd/system/*.mount /etc/network/interfaces /etc/sysctl.conf /etc/resolv.conf /etc/hosts /etc/hostname /etc/cron* /etc/aliases /etc/snmp/ /etc/smartd.conf /usr/share/snmp/snmpd.conf /etc/postfix/ /etc/pve/ /etc/lvm/ /etc/modprobe.d/ /var/lib/pve-firewall/ /var/lib/pve-cluster/  /etc/vzdump.conf /etc/ksmtuned.conf"
pbs_backup_content="/etc/ssh/sshd_config /root/.ssh/ /etc/fail2ban/ /etc/systemd/system/*.mount /etc/network/interfaces /etc/sysctl.conf /etc/resolv.conf /etc/hosts /etc/hostname /etc/cron* /etc/aliases /etc/snmp/ /etc/smartd.conf /usr/share/snmp/snmpd.conf /etc/postfix/ /etc/proxmox-backup/"
# ---------------END OF ENVIRONNEMENT VARIABLES-----------------

main_menu(){
    clear
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"` #Blue
    NUMBER=`echo "\033[33m"` #yellow
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[33m"`
    echo -e "${MENU}****************** Proxmox Toolbox **********************${NORMAL}"
    echo -e "${MENU}*********** Tonton Jo - 2021 - Version $version ************${NORMAL}"
    echo -e "${MENU}********** https://www.youtube.com/c/tontonjo **************${NORMAL}"
    echo " "
    echo -e "${MENU}**${NUMBER} 1)${MENU} No-subscription Sources Configuration ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 2)${MENU} Update host ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 3)${MENU} Install usefull dependencies ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 4)${MENU} Security settings (fail2ban & users)${NORMAL}"
    echo -e "${MENU}**${NUMBER} 5)${MENU} SWAP Settings ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 6)${MENU} Enable S.M.A.R.T self-tests ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 7)${MENU} SNMP settings ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 8)${MENU} Email notification configuration ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 9)${MENU} Proxmox configuration backup and restoration ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 0)${MENU} Exit ${NORMAL}"
    echo " "
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Please enter a menu option and enter or ${RED_TEXT}enter to exit. ${NORMAL}"
    read -rsn1 opt
	while [ opt != '' ]
  do
    if [[ $opt = "" ]]; then
      exit;
    else
      case $opt in
	  	  1) clear;
		read -p "This will configure sources for no-enterprise repository - Continue? y = yes / anything = no: " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				if [ -d "$pve_log_folder" ]; then
					  echo "- Server is a PVE host"
					#2: Edit sources list:
					  echo "- Checking Sources list"
						if grep -Fxq "deb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" /etc/apt/sources.list
						 then
						  echo "-- Source looks alredy configured - Skipping"
						else
						  echo "-- Adding new entry to sources.list"
						  sed -i "\$adeb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" /etc/apt/sources.list
						fi
					  echo "- Checking Enterprise Source list"
						if grep -Fxq "#deb https://enterprise.proxmox.com/debian/pve $distribution pve-enterprise" /etc/apt/sources.list.d/pve-enterprise.list
						then
						 echo "-- Entreprise repo looks already commented - Skipping"
						else
						 echo "-- Hiding Enterprise sources list"
						 sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
					   fi
					else
					  echo "- Server is a PBS host"
					  echo "- Checking Sources list"
						if grep -Fxq "deb http://download.proxmox.com/debian/pbs $distribution pbs-no-subscription" /etc/apt/sources.list
						then
						  echo "-- Source looks alredy configured - Skipping"
						else
						 echo "-- Adding new entry to sources.list"
						  sed -i "\$adeb http://download.proxmox.com/debian/pbs $distribution pbs-no-subscription" /etc/apt/sources.list
						fi
					  echo "- Checking Enterprise Source list"
						if grep -Fxq "#deb https://enterprise.proxmox.com/debian/pbs $distribution pbs-enterprise" /etc/apt/sources.list.d/pbs-enterprise.list
						  then
						  echo "-- Entreprise repo looks already commented - Skipping"
						else
						  echo "-- Hiding Enterprise sources list"
						  sed -i 's/^/#/' /etc/apt/sources.list.d/pbs-enterprise.list
						fi
				fi
			sleep 3
			fi
		main_menu
	   ;;
	   	  2) clear;
	  
		echo "- Updating System"
		apt-get update -y -qq
		apt-get upgrade -y -qq
		apt-get dist-upgrade -y -qq
		if grep -Ewqi "no-subscription" /etc/apt/sources.list; then
			if grep -q ".data.status.toLowerCase() == 'active') {" $proxmoxlib; then
					echo "- Subscription Message already removed - Skipping"
				else
					if [ -d "$pve_log_folder" ]; then
						echo "- Removing No Valid Subscription Message for PVE"
						sed -Ezi.bak "s/!== 'active'/== 'active'/" $proxmoxlib && systemctl restart pveproxy.service
					else 
						echo "- Removing No Valid Subscription Message for PBS"
						sed -Ezi.bak "s/!== 'active'/== 'active'/" $proxmoxlib && systemctl restart proxmox-backup-proxy.service
					fi
			fi
		sleep 3
		fi
		main_menu
	   ;;
      3) clear;
			read -p "- This will install thoses libraries if missing: ifupdown2 - git - sudo - libsasl2-modules - Continue? y = yes / anything = no: " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				echo " "
				if [ $(dpkg-query -W -f='${Status}' ifupdown2 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					apt-get install -y ifupdown2;
				else
					echo "- ifupdown2 already installed"
				fi
				if [ $(dpkg-query -W -f='${Status}' git 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					apt-get install -y git;
				else
					echo "- git already installed"
				fi
				if [ $(dpkg-query -W -f='${Status}' sudo 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					apt-get install -y sudo;
				else
					echo "- sudo already installed"
				fi
				if [ $(dpkg-query -W -f='${Status}' libsasl2-modules 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					apt-get install -y libsasl2-modules;.
				else
					echo "- libsasl2-modules already installed"
				fi
			sleep 3
			fi	
		main_menu
      ;;
	4) clear;
		read -p "Do you want to enable fail2ban? y = yes / anything = no: " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				if [ $(dpkg-query -W -f='${Status}' fail2ban 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					apt-get install -y fail2ban;
				else
					echo "- fail2ban already installed"
				fi
				git clone -q https://github.com/Tontonjo/proxmox_toolbox.git
					if [ -d "$pve_log_folder" ]; then
						echo "- Host is a PVE Host"	
						# Put filter.d/proxmox-backup-server.conf contents to /etc/fail2ban/filter.d/proxmox-backup-server.conf
						cp -f proxmox_toolbox/pve/filter.d/proxmox-virtual-environement.conf /etc/fail2ban/filter.d/proxmox-virtual-environement.conf
						# Put jail.d/proxmox-backup-server.conf to /etc/fail2ban/jail.d/proxmox-backup-server.conf
						cp -f proxmox_toolbox/pve/jail.d/proxmox-virtual-environement.conf /etc/fail2ban/jail.d/proxmox-virtual-environement.conf
					else
						echo "- Host is a PBS Host"
						# Put filter.d/proxmox-backup-server.conf contents to /etc/fail2ban/filter.d/proxmox-backup-server.conf
						cp -f proxmox_toolbox/pbs/filter.d/proxmox-backup-server.conf /etc/fail2ban/filter.d/proxmox-backup-server.conf
						# Put jail.d/proxmox-backup-server.conf to /etc/fail2ban/jail.d/proxmox-backup-server.conf
						cp -f proxmox_toolbox/pbs/jail.d/proxmox-backup-server.conf /etc/fail2ban/jail.d/proxmox-backup-server.conf
					fi
			clear
			# Restart Fail2Ban Service
			systemctl restart fail2ban.service
			fi
		clear
		echo "- Do you want to use another user than root?"
		echo "- This will guide you to create another user, add it as a sudo user and allow sudo users to connect trough ssh"
		read -p "- Press: y = yes / anything = no: " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				clear
				if [ $(dpkg-query -W -f='${Status}' sudo 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					apt-get install -y sudo;
				else
					echo "- sudo already installed"
				fi
				echo "- What is the new username: "
				read username
				clear
				useradd -m $username
				passwd $username
				mkdir /home/$username/.ssh/
				ssh-keygen -t rsa -b 4096 -f /home/$username/.ssh/id_rsa -q -N ""
				cp /home/$username/.ssh/id_rsa.pub /home/$username/.ssh/authorized_keys
				chown -R $username:users /home/$username/.ssh/
				echo "- New user $username created"
				echo "- Adding user to sudo users"
				adduser $username sudo
				echo "AllowGroups sudo" >> "/etc/ssh/sshd_config"
				read -p "- Do you want to deny root ssh login?  y = yes / anything = no: " -n 1 -r
					if [[ $REPLY =~ ^[Yy]$ ]]; then
						if grep -qF "PermitRootLogin yes" /etc/ssh/sshd_config; then
							sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
						else
						main_menu
						fi
				service ssh restart && service sshd restart
					fi
				clear
			fi
			clear
			if [ -d "$pve_log_folder" ]; then
					read -p "- Do you want to create an alternate PVE admin user? y = yes / anything = no: " -n 1 -r
					if [[ $REPLY =~ ^[Yy]$ ]]; then
						clear
						echo "- What is the new pve username: "
						read pveusername
						clear
						echo "- What is the new admin group name: "
						read admingroup	
						clear
						echo "- Creating PVE user $pveusername"
						pveum user add $pveusername@pve
						pveum passwd $pveusername@pve
						echo "- Creating PVE admin group $admingroup"
						pveum group add $admingroup -comment "System Administrators"
						echo "- Defining administrators right"
						pveum acl modify / -group $admingroup -role Administrator
						echo "- adding $pveusername to $admingroup"
						pveum user modify $pveusername@pve -group $admingroup
					fi
					clear
					echo "!! Warning - root@pam is required to update host from Proxmox web ui !!"
					read -p "- Do you want to disable "root@pam"?  y = yes / anything = no: " -n 1 -r
						if [[ $REPLY =~ ^[Yy]$ ]]; then
							read -p "- Are you sure you want to disable root@pam? y = yes / anything = no: " -n 1 -r
								if [[ $REPLY =~ ^[Yy]$ ]]; then
									echo "- Removing root user from PVE"
									pveum user modify root@pam -enable 0
								fi
						fi
				else
					echo "- Host is a PBS host - user management not implemented ATM"
			fi
		main_menu
	   ;;
	   5) clear;
		lsblk | grep -qi swap
		swapenabled=$?
	   	if [ $swapenabled -eq 0 ]; then
		read -p "- Do you want to edit swappiness value or disable SWAP? y = yes / anything = no: " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				swapvalue=$(cat /proc/sys/vm/swappiness)
				echo ""
				echo "- SWAP is actually set on $swapvalue"
				echo "- Recommanded value: 1 - The lower the value - the less SWAP will be used - 0 to use SWAP only when out of memory"
				echo ""
				echo "- What is the new swapiness value? 0 to 100 "
				read newswapvalue
				echo "- Setting swapiness to $newswapvalue"
				sysctl vm.swappiness=$newswapvalue
				echo "vm.swappiness=$newswapvalue" > /etc/sysctl.d/swappiness.conf
				echo "- Emptying swap - This may take some time"
				swapoff -a
				echo "- Re-enabling swap with $newswapvalue value"
				swapon -a
				sleep 3	
			fi
		else
			echo " - System has no swap - Nothing to do"
			sleep 3	
		fi
		main_menu
      ;;
	   6) clear;
	   	read -p "- Do you want to enable short and long S.M.A.R.T self-tests? y = yes / anything = no: " -n 1 -r
		clear
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				if grep -Ewqi "(S/../../7/22|L/../01/./22)" /etc/smartd.conf; then
					echo "- Self tests looks already configured"
					echo "- Short smart test will occure every sunday at 22H and long smart tests every 1 of month at 22H"
				else
					cp /etc/smartd.conf /etc/smartd.conf.BCK
					echo "- Enabling short and long self-tests"
					echo "- Short smart test will occure every sunday at 22H and long smart tests every 1 of month at 22H"
					echo "DEVICESCAN -d auto -n never -a -s (S/../../7/22|L/../01/./22) -m root -M exec /usr/share/smartmontools/smartd-runner" > "/etc/smartd.conf"
				fi
			sleep 3	
			fi
		main_menu
      ;;
	   7) clear;
		read -p "- Install and configure SNMP? y = yes / anything = no: " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				echo " "
				git clone -q https://github.com/Tontonjo/proxmox_toolbox.git
				if [ $(dpkg-query -W -f='${Status}' snmpd 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
					apt-get install -y snmpd libsnmp-dev;
				else
					echo "- snmpd already installed"
				fi
				clear
				read -p "- Press y for snmpv2 or anything for SNMP V3 (ReadOnly): " -n 1 -r
				if [[ $REPLY =~ ^[Yy]$ ]]; then
					clear
					echo "- Read only community name? (ex: ro_tontonjo): "
					read rocommunity
					echo "- Allowed subnet? Enter for none (x.x.x.x/xx): "
					read allowedsubnet
					cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.backup
					cp -f proxmox_toolbox/snmp/snmpd.conf /etc/snmp/snmpd.conf
					echo "rocommunity $rocommunity $allowedsubnet" >> /etc/snmp/snmpd.conf
				else
					clear
					cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.backup
					cp -f proxmox_toolbox/snmp/snmpd.conf /etc/snmp/snmpd.conf
					echo "- Encryption will be MD5 and DES"
					service snmpd stop
					echo "- Deleting old SNMPv3 users in /usr/share/snmp/snmpd.conf"
					rm -f /usr/share/snmp/snmpd.conf
					echo "!! min 8 charachters password !!"
					net-snmp-config --create-snmpv3-user -ro -a MD5 -x DES
				fi
			service snmpd restart
			sleep 3	
			fi
		main_menu
	   ;;
	   	 8) clear;
		mail_menu
      ;;
	     9) clear;
		backup_menu
      ;;
      0)
	  clear
      exit
      ;;
      esac
    fi
  done
  main_menu
}

mail_menu(){
			echo "- Installing missing libraries"
			if ping -c 1 $dnstesthost &> /dev/null; then
				if [ $(dpkg-query -W -f='${Status}' libsasl2-modules 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
				  apt-get install -yqq libsasl2-modules;
				fi
				if [ $(dpkg-query -W -f='${Status}' mailutils 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
				  apt-get install -yqq mailutils;
				fi
			else
				echo "- Looks like your host cant reach test domain $dnstesthost"
				echo "- Please control your network and DNS settings"
				sleep 7
				main_menu
fi


			clear
			ALIASESBCK=/etc/aliases.BCK
			if test -f "$ALIASESBCK"; then
				echo "backup OK"
				else
				cp -n /etc/aliases /etc/aliases.BCK
			fi
			MAINCFBCK=/etc/postfix/main.cf.BCK
			if test -f "$MAINCFBCK"; then
				echo "backup OK"
				else
				cp -n /etc/postfix/main.cf /etc/postfix/main.cf.BCK
			fi
			clear
			NORMAL=`echo "\033[m"`
			MENU=`echo "\033[36m"` #Blue
			NUMBER=`echo "\033[33m"` #yellow
			FGRED=`echo "\033[41m"`
			RED_TEXT=`echo "\033[31m"`
			ENTER_LINE=`echo "\033[33m"`
  			echo -e "${MENU}************* Ez Proxmox Mail Configurator ***************${NORMAL}"
			echo -e "${MENU}********** Tonton Jo - 2021 - Version $version *****${NORMAL}"
   			echo -e "${MENU}********* https://www.youtube.com/c/tontonjo ***********${NORMAL}"
			echo " "
			echo -e "${MENU}**${NUMBER} 1)${MENU} Configure ${NORMAL}"
			echo -e "${MENU}**${NUMBER} 2)${MENU} Test ${NORMAL}"
			echo -e "${MENU}**${NUMBER} 3)${MENU} Check logs for known errors - attempt to correct ${NORMAL}"
			echo -e "${MENU}**${NUMBER} 4)${MENU} Restore original conf ${NORMAL}"
			echo -e "${MENU}**${NUMBER} 0)${MENU} Back ${NORMAL}"
			echo " "
			echo -e "${MENU}*********************************************${NORMAL}"
			echo -e "${ENTER_LINE}Please enter a menu option and enter or ${RED_TEXT}enter to exit. ${NORMAL}"
			read -rsn1 opt
			while [ opt != '' ]
		  do
			if [[ $opt = "" ]]; then
			  exit;
			else
			  case $opt in
			  1) clear;
					echo "- System administrator recipient mail address (user@domain.tld) (root alias): "
					read 'varrootmail'
					echo "- What is the mail server hostname? (smtp.gmail.com): "
					read 'varmailserver'
					echo "- What is the mail server port? (Usually 587 - can be 25 (no tls)): "
					read 'varmailport'
					read -p  "- Does the server require TLS? y = yes / anything = no: " -n 1 -r 
					if [[ $REPLY =~ ^[Yy]$ ]]; then
					vartls=yes
					else
					vartls=no
					fi
					echo " "
					echo "- What is the AUTHENTIFICATION USERNAME? (user@domain.tld or username): "
					read 'varmailusername'
					echo "- What is the AUTHENTIFICATION PASSWORD?: "
					read 'varmailpassword'
					echo "- Is the SENDER mail address the same as the AUTHENTIFICATION USERNAME?"
					read -p " y to use $varmailusername / Enter to set something else: " -n 1 -r 
					if [[ $REPLY =~ ^[Yy]$ ]]; then
					varsenderaddress=$varmailusername
					else
					echo " "
					echo "- What is the sender email address?: "
					read 'varsenderaddress'
					fi
					echo " "
				echo "- Working on it!"
				echo " "
				echo "- Setting Aliases"
				if grep "root:" /etc/aliases
					then
					echo "- Alias entry was found: editing for $varrootmail"
					sed -i "s/^root:.*$/root: $varrootmail/" /etc/aliases
				else
					echo "- No root alias found: Adding"
					echo "root: $varrootmail" >> /etc/aliases
				fi
				
				#Setting canonical file for sender - :
				echo "root $varsenderaddress" > /etc/postfix/canonical
				chmod 600 /etc/postfix/canonical
				
				# Preparing for password hash
				echo [$varmailserver]:$varmailport $varmailusername:$varmailpassword > /etc/postfix/sasl_passwd
				chmod 600 /etc/postfix/sasl_passwd 
				
				# Add mailserver in main.cf
				sed -i "/#/!s/\(relayhost[[:space:]]*=[[:space:]]*\)\(.*\)/\1"[$varmailserver]:"$varmailport""/"  /etc/postfix/main.cf
				
				# Checking TLS settings
				echo "- Setting correct TLS Settings: $vartls"
				postconf smtp_use_tls=$vartls
				
				# Checking for password hash entry
					if grep "smtp_sasl_password_maps" /etc/postfix/main.cf
					then
					echo "- Password hash already setted-up"
				else
					echo "- Adding password hash entry"
					postconf smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd
				fi
				#checking for certificate
				if grep "smtp_tls_CAfile" /etc/postfix/main.cf
					then
					echo "- TLS CA File looks setted-up"
					else
					postconf smtp_tls_CAfile=/etc/ssl/certs/ca-certificates.crt
				fi
				# Adding sasl security options
				# eliminates default security options which are imcompatible with gmail
				if grep "smtp_sasl_security_options" /etc/postfix/main.cf
					then
					echo "- Google smtp_sasl_security_options setted-up"
					else
					postconf smtp_sasl_security_options=noanonymous
				fi
				if grep "smtp_sasl_auth_enable" /etc/postfix/main.cf
					then
					echo "- Authentification already enabled"
					else
					postconf smtp_sasl_auth_enable=yes
				fi 
				if grep "sender_canonical_maps" /etc/postfix/main.cf
					then
					echo "- Canonical entry already existing"
					else
					postconf sender_canonical_maps=hash:/etc/postfix/canonical
				fi 
				
				echo "- Encrypting password and canonical entry"
				postmap /etc/postfix/sasl_passwd
				postmap /etc/postfix/canonical
				echo "- Restarting postfix and enable automatic startup"
				systemctl restart postfix && systemctl enable postfix
				echo "- Cleaning file used to generate password hash"
				rm -rf "/etc/postfix/sasl_passwd"
				echo "- Files cleaned"
				
			  mail_menu;
      ;;

     2) clear;
		echo "- What is the recipient email address? :"
		read vardestaddress
		echo "- An email will be sent to: $vardestaddress"
		echo “If you reveive this, it means your email configurations looks correct. Yay!” | mail -s "test mail - $hostname - $date" $vardestaddress
		echo "- Email should have been sent - If none received, you may want to check for errors in menu 3"
		sleep 3
	  
	  mail_menu;	
      ;;
	        3) clear;
			echo "- Checking for known errors that may be found in logs"
			if grep "SMTPUTF8 is required" "/var/log/mail.log"
			then
			echo "- Errors im log found - SMTPUTF8 is required"
					if grep "smtputf8_enable = no" /etc/postfix/main.cf
						then
						echo "- Fix looks already applied!"
					else
						echo " "
						echo "- Setting "smtputf8_enable=no" to correct "SMTPUTF8 was required but not supported""
						postconf smtputf8_enable=no
						postfix reload
				 	 fi 

			elif grep "Network is unreachable" "/var/log/mail.log"; then
				read -p "- Are you on IPv4 AND your host can resolve and access public adresses? y = yes / anything = no: " -n 1 -r
				if [[ $REPLY =~ ^[Yy]$ ]]; then
					if grep "inet_protocols = ipv4" /etc/postfix/main.cf
					then
						echo "- Fix looks already applied!"
					else
						echo " "
						echo "- Setting "inet_protocols = ipv4 " to correct ""Network is unreachable" caused by ipv6 resolution""
						postconf inet_protocols=ipv4
						postfix reload
					fi
				fi
			elif grep "smtp_tls_security_level = encrypt" "/var/log/mail.log"; then		
				echo "- Errors im log found - smtp_tls_security_level = encrypt is required"
				if grep "smtp_tls_security_level = encrypt" /etc/postfix/main.cf; then
					echo "- Fix looks already applied!"
				else
					echo " "
					echo "- Setting "smtp_tls_security_level = encrypt" to correct"
					postconf inet_protocols=ipv4
					postfix reload
				fi
			elif grep "smtp_tls_wrappermode = yes" "/var/log/mail.log"; then		
				echo "- Errors im log found - smtp_tls_wrappermode = yes is required"
				if grep "smtp_tls_wrappermode = yes" /etc/postfix/main.cf; then
					echo "- Fix looks already applied!"
				else
					echo " "
					echo "- Setting "smtp_tls_wrappermode = yes" to correct"
					postconf smtp_tls_wrappermode=yes
					postfix reload
				fi
		    else
			echo "- No configured error found - nothing to do!"
			sleep 3
			fi
	  mail_menu;	
      ;;
      4) clear;
		read -p "- Do you really want to restore? y = yes / anything = no: " -n 1 -r
			if [[ $REPLY =~ ^[Yy]$ ]]; then
					echo " "
					echo "- Restoring default configuration files"
				        cp -rf /etc/aliases.BCK /etc/aliases
					cp -rf /etc/postfix/main.cf.BCK /etc/postfix/main.cf
					echo "- Restarting services "
					systemctl restart postfix
					echo "- Restoration done"
			fi
	  mail_menu;
	     ;;

      0) clear;
      main_menu;
      ;;

      x)exit;
      ;;

      \n)exit;
      ;;

      *)clear;
      main_menu;
      ;;
      esac
    fi
  done
}

backup_menu(){
			clear
			NORMAL=`echo "\033[m"`
			MENU=`echo "\033[36m"` #Blue
			NUMBER=`echo "\033[33m"` #yellow
			FGRED=`echo "\033[41m"`
			RED_TEXT=`echo "\033[31m"`
			ENTER_LINE=`echo "\033[33m"`
  			echo -e "${MENU}**************** Proxmxo backup and restore ***************${NORMAL}"
			echo -e "${MENU}********** Tonton Jo - 2021 - Version $version *****${NORMAL}"
   			echo -e "${MENU}********** https://www.youtube.com/c/tontonjo ***********${NORMAL}"
			echo " "
			echo -e "${MENU}**${NUMBER} 1)${MENU} Backup configuration ${NORMAL}"
			echo -e "${MENU}**${NUMBER} 2)${MENU} Restore configuration ${NORMAL}"
			echo -e "${MENU}**${NUMBER} 0)${MENU} Back ${NORMAL}"
			echo " "
			echo -e "${MENU}*********************************************${NORMAL}"
			echo -e "${ENTER_LINE}Please enter a menu option and enter or ${RED_TEXT}enter to exit. ${NORMAL}"
			read -rsn1 opt
			while [ opt != '' ]
		  do
			if [[ $opt = "" ]]; then
			  exit;
			else
			case $opt in
			  1) clear;
			  backupname=$(hostname)
			  mkdir -p $backupdir
			  echo "- Creating backup"
			  if [ -d "$pve_log_folder" ]; then
			 	 echo "- Server is a PVE host"
			 	 tar -czf $backupdir$backupname-$(date +%Y_%m_%d-%H_%M_%S).tar.gz --absolute-names $pve_backup_content
			  else
			  	 echo "- Server is a PBS host"
			 	 tar -czf $backupdir$backupname-$(date +%Y_%m_%d-%H_%M_%S).tar.gz --absolute-names $pbs_backup_content
			  fi
			  clear
			  echo "- Backup done - please control and test it"
			  echo "- Archive is located in $backupdir"
			  sleep 3
			  clear
			  backup_menu
			;;
			2) clear;
			unset options i
			while IFS= read -r -d $'\0' f; do
			options[i++]="$f"
			done < <(find $backupdir -maxdepth 1 -type f -name "*.tar.gz" -print0 )
			select opt in "${options[@]}" "- Return to backup menu"; do
			  case "$opt" in 
			  *.tar.gz)
				  echo "- Backup $opt selected"
				  read -p "- Proceed with the restoration?  y = yes / anything = no: " -n 1 -r
				  if [[ $REPLY =~ ^[Yy]$ ]]; then
					 tar -xf "$opt" -C /
					 clear
					 echo "- File restauration done"
					 echo "- Installing missind dependencies if missing"
					 if [ -d "/etc/snmp/" ]; then
						echo "- snmp config found - installing snmpd"
						apt-get -yqq install snmpd libsnmp-dev
					 fi
					 if [ -d "/etc/fail2ban/" ]; then
						echo "- fail2ban config found - installing fail2ban"
						apt-get -yqq install fail2ban
					 fi
					 read -p "- Do you want to reboot host now? y = yes / anything = no: " -n 1 -r
					if [[ $REPLY =~ ^[Yy]$ ]]; then
						reboot now
					else
						main_menu
					fi
				  else
					clear
					backup_menu
				  fi
				  ;;
				"- Return to backup menu")
				 backup_menu
				  ;;
				*)
				  echo "- Please choose using an number"
				  ;;
			  esac
			done
			;;
      0) clear;
      main_menu;
      ;;

      x)exit;
      ;;

      \n)exit;
      ;;

      *)clear;
      main_menu;
      ;;
      esac
    fi
  done
}

main_menu
