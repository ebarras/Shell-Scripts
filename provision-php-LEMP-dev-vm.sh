#!/bin/bash
#set -x

# This script will set up a LEMP environment for local development on CentOS7.
# - Erik Barras 2018-08-30

## Prework
# Install EPEL
sudo yum -y install epel-release
# Install IUS
sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
# Install Sublime Text GPG Key
sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
# Install Sublime Text Repo
sudo yum-config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
# Update + Upgrade everything
sudo yum -y update
sudo yum -y upgrade

## Sublime Text 3
# Install Sublime Text from Repoe
sudo yum -y install sublime-text
    # Figure Out License and Add to Desktop in Gnome #

## Git
sudo yum -y install git

## MariaDB
sudo yum -y install mariadb-server mariadb
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

mysql_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16);
# Secure the Install, write random DB password to file.
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('$mysql_password') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

if mysql -u root -p$mysql_password -e "exit"; then
	echo -e "MySQL Password: $mysql_password" > ~/install-passwords.txt
else
	echo "Could Not Log In with New Random Password. Install Competed Previously, Leaving Password as Old Password."
fi

## Nginx
sudo yum -y install nginx
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

## PHP 7.2
#sudo yum install -y



## Composer