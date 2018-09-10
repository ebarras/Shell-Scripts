#!/bin/bash
set -x

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
sudo systemctl start mariadb
sudo systemctl enable mariadb

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
	# Here you need to set this as an ENV variable in bashrc local to the user.
else
	echo "Could Not Log In with New Random Password. Install Competed Previously, Leaving Password as Old Password."
fi

# PHPMyAdmin
if [ ! -d ~/Code/phpmyadmin/public/ ]; then
    sudo wget -nc -O /tmp/phpMyAdmin-4.8.3-english.tar.gz https://files.phpmyadmin.net/phpMyAdmin/4.8.3/phpMyAdmin-4.8.3-english.tar.gz
    mkdir -p ~/Code/phpmyadmin/public && tar -xzvf /tmp/phpMyAdmin-4.8.3-english.tar.gz -C ~/Code/phpmyadmin/public --strip-components 1
else
    echo "PHPMyAdmin Already Installed... Skipping"
fi

## Nginx
sudo yum -y install nginx

# update the nginx user
sudo sed -i -e "s/user nginx;/user $USER;/g" /etc/nginx/nginx.conf
sudo sed -i -e "s/80 default_server;/80;/g" /etc/nginx/nginx.conf

# Add test.conf Nginx VHost File
sudo dd of=/etc/nginx/conf.d/test.conf << EOF
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name ~^(?<vhost>.+)\\.localtest.me\$;
  root /home/$USER/Code/\$vhost/public;
  index index.php index.html;
  server_name _;
  location / {
    try_files \$uri \$uri/ /index.php\$is_args\$args;
  }
  location ~ \.php\$ {
    include fastcgi.conf;
    fastcgi_pass unix:/run/php-fpm/php-fpm.sock;
  }
}
EOF

sudo systemctl start nginx
sudo systemctl enable nginx

## PHP 7.2
sudo yum -y install php72u-fpm php72u-cli php72u-mysqlnd php72u-gd php72u-common \
php72u-opcache php72u-pecl-memcached php72u-mbstring php72u-xml php72u-soap php72u-intl

# Update PHP Settings
sudo sed -i -e "s/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/g" /etc/php.ini
sudo sed -i -e "s/memory_limit = 128M/memory_limit = 512M/g" /etc/php.ini
sudo sed -i -e "s/;date.timezone =/date.timezone = UTC/g" /etc/php.ini
sudo sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php.ini
# create a socket instead of a port
sudo sed -i -e "s/listen = 127.0.0.1:9000/listen = \/run\/php-fpm\/php-fpm.sock/g" /etc/php-fpm.d/www.conf
sudo sed -i -e "s/;listen.acl_users = nginx/listen.acl_users = $USER/g" /etc/php-fpm.d/www.conf

# fix permissions on run directory
sudo chown -R $USER:$(id -gn $USER) /run/php-fpm

# fix permissions on session directory
sudo chown -R $USER:$(id -gn $USER) /var/lib/php/fpm/

# Update PHP User to My User
sudo sed -i -e "s/user = php-fpm/user = $USER/g" /etc/php-fpm.d/www.conf
sudo sed -i -e "s/group = php-fpm/group = $(id -gn)/g" /etc/php-fpm.d/www.conf

# set up the ~/Code directory and http://info.test website
mkdir -p /home/"$USER"/Code/info/public
echo "<?php phpinfo();" > /home/"$USER"/Code/info/public/index.php

sudo systemctl start php-fpm
sudo systemctl enable php-fpm

## Composer
# Install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

## Redis
# Install Redis
sudo yum -y install redis40u

# Set Redis Password Here in the future, add it to the pw file, add to ENV.

sudo systemctl start redis
sudo systemctl enable redis

## Cleanup
# restart all services
sudo systemctl restart php-fpm
sudo systemctl restart nginx
sudo systemctl restart mariadb
sudo systemctl restart redis

# fix permissions
sudo chown -R $USER:$(id -gn $USER) ~/
sudo chmod 755 /var/log/nginx/

# turn off bullshit selinux. This should be researched after vacation to work with SeLinux just to learn that.
sudo setenforce 0
sudo sed -i -e "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

# open firewalls for external testing
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
sudo firewall-cmd --reload

## quality of life improvements
# git
git config --global user.name "ebarras"
git config --global user.email "ebarras@gmail.com"

# aliases
grep -q -F '# Load the shell dotfiles' ~/.bashrc || cat <<EOT >> ~/.bashrc

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend \`\$PATH\`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra}; do
	[ -r "\$file" ] && [ -f "\$file" ] && source "\$file";
done;
unset file;
EOT

yes | cp aliases ~/.aliases

# source .bashrc to pick up changes
. ~/.bashrc
