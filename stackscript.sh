#!/bin/bash
set -e
SOFTWARE_CHEVERETO="chevereto-free"
SOFTWARE_TAG="1.3.0"
SOFTWARE_INSTALLER_TAG="2.2.2"
WORKING_DIR="/var/www/html"
CHEVERETO_SOFTWARE=${SOFTWARE_CHEVERETO}
CHEVERETO_TAG=${SOFTWARE_TAG}
CHEVERETO_INSTALLER_TAG=${SOFTWARE_INSTALLER_TAG}
CHEVERETO_LICENSE=
source <ssinclude StackScriptID="1"> #https://cloud.linode.com/stackscripts/1
system_update
apt install -y apache2
apt install -y mysql-server
apt install -y php
apt install -y php-{common,cli,curl,fileinfo,gd,imagick,intl,json,mbstring,mysql,opcache,pdo,pdo-mysql,xml,xmlrpc,zip}
set -eux
{
    echo "log_errors = On"
    echo "upload_max_filesize = 50M"
    echo "post_max_size = 50M"
    echo "max_execution_time = 30"
    echo "memory_limit = 512M"
} >/etc/php/7.4/apache2/conf.d/chevereto.ini
rm -rf /var/www/html/*
set -eux
{
    echo "<VirtualHost *:80>"
    echo "    <Directory /var/www/html>"
    echo "        Options Indexes FollowSymLinks"
    echo "        AllowOverride All"
    echo "        Require all granted"
    echo "    </Directory>"
    echo "    ServerAdmin webmaster@localhost"
    echo "    DocumentRoot /var/www/html"
    echo "    ErrorLog \${APACHE_LOG_DIR}/error.log"
    echo "    CustomLog \${APACHE_LOG_DIR}/access.log combined"
    echo "</VirtualHost>"
} >/etc/apache2/sites-available/000-default.conf
mkdir /chevereto && mkdir -p /chevereto/{download,installer}
cd /chevereto/download
curl -S -o installer.tar.gz -L "https://github.com/chevereto/installer/archive/${CHEVERETO_INSTALLER_TAG}.tar.gz"
tar -xvzf installer.tar.gz
mv -v installer-"${CHEVERETO_INSTALLER_TAG}"/* /chevereto/installer/
cd /chevereto/installer
php installer.php -a download -s $CHEVERETO_SOFTWARE -t=$CHEVERETO_TAG -l=$CHEVERETO_LICENSE
php installer.php -a extract -s $CHEVERETO_SOFTWARE -f chevereto-pkg-*.zip -p $WORKING_DIR
chown www-data: $WORKING_DIR -R
a2enmod rewrite
systemctl restart apache2
echo "[OK] $CHEVERETO_SOFTWARE $CHEVERETO_TAG provisioned"
CHEVERETO_DB_HOST=localhost
CHEVERETO_DB_PORT=3306
CHEVERETO_DB_NAME=chevereto
CHEVERETO_DB_USER=chevereto
CHEVERETO_DB_PASS=$(openssl rand -hex 24)
mysql -u root -e "CREATE DATABASE chevereto;"
mysql -u root -e "CREATE USER 'chevereto'@'localhost' IDENTIFIED BY '$CHEVERETO_DB_PASS';"
mysql -u root -e "GRANT ALL ON *.* TO 'chevereto'@'localhost';"
set -eux
{
    echo "<?php"
    echo "\$settings = ["
    echo "    'db_host' => '$CHEVERETO_DB_HOST',"
    echo "    'db_name' => '$CHEVERETO_DB_NAME',"
    echo "    'db_user' => '$CHEVERETO_DB_USER',"
    echo "    'db_pass' => '$CHEVERETO_DB_PASS',"
    echo "    'db_port' => '$CHEVERETO_DB_PORT',"
    echo "    'db_table_prefix' => 'chv_',"
    echo "    'db_driver' => 'mysql',"
    echo "    'debug_level' => 1,"
    echo "];"
} >/var/www/html/app/settings.php
chown www-data: /var/www/html/app/settings.php
echo $(date -u) ": Created /var/www/html/app/settings.php" >>/var/log/per-instance.log
echo $(date -u) ": System provisioning script is complete." >>/var/log/per-instance.log
