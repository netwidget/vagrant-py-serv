#!/usr/bin/env bash

# Script to provision a CentOS 6.4 64-bit web server using Vagrant
# written by James Dugger
# Date: 5-22-14
# Updated: 6-28/14

#####################################################################
# Configuration Varisables                                          #
#####################################################################

# Global Variables.
# Project folder variable for use in make dir and virtual hosts config file.
#
project_folder="kidwork"

# CentOS version
#
sys_ver_maj="6"
sys_ver_min="8"

# DocumentRoot variable for virtual host config file.
#
doc_root="docroot"

# version of python to install.
#
py_ver_maj="2"
py_ver_min="7"
py_ver_inc="8"

# Setuptools version
#
setup_ver_maj="1"
setup_ver_min="4"
setup_ver_inc="2"

# variables for git global config, user, email, editor:
#
username="James Dugger"
email="james.dugger@gmail.com"
editor="vim"

# domain name used in the virtual host config file.
#
domain_name="kidwork.dev"

# Set for httpd.conf file to avoid apache warning for FDGN.
#
servername="kidserv"

# Default base shared folder. this should match the target folder in the Vagrantfile.
#
base_folder="var/www"

# Address for DNS resolution in /etc/hosts file.  default set to loopback.
#
address="127.0.0.1"

# MySQL vairables for Drupal based databsae
# Main database
#
db_password="kidwork"
db_user="kidwork"
db_name="kidwork_db"
db_host="localhost"
db_port=""
db_driver="mysql"
db_prefix=""
db_driver_hib="mysql"
db_charset_hib="utf8"

# nginx config file
#
nginx_conf=$'worker_processes 1;\n
\n
events {\n
\n
    \tworker_connections 1024;\n
\n
}\n
\n
http {\n
\n
    \tsendfile on;\n
\n
    \tgzip              on;\n
    \tgzip_http_version 1.0;\n
    \tgzip_proxied      any;\n
    \tgzip_min_length   500;\n
    \tgzip_disable      "MSIE [1-6]\.";\n
    \tgzip_types        text/plain text/xml text/csss\n
                      text/comma-separated-values\n
                      text/javascript\n
                      application/x-javascript\n
                      application/atom+xml;\n
\n
    \t# Configuration containing list of application servers\n
    \tupstream uwsgicluster {\n
\n
        \tserver 127.0.0.1:8080;\n
        \t# server 127.0.0.1:8081;\n
        \t# ..\n
        \t# .\n
\n
    }\n
\n
    \t# Configuration for Nginx\n
    \tserver {\n
\n
        \t\t# Running port\n
        \t\tlisten 80;\n
\n
        \t\t# Settings to by-pass for static files\n 
        \t\tlocation ^~ /static/  {\n
\n
            \t\t\t# Example:\n
            \t\t\t# root /full/path/to/application/static/file/dir;\n
            \t\t\troot /app/static/;\n
\n
        \t\t}\n
\n
        \t\t# Serve a static file (ex. favico) outside static dir.\n
        \t\tlocation = /favico.ico  {\n
\n
            \t\t\troot /app/favico.ico;\n
\n
        \t\t}\n
\n
        \t\t# Proxying connections to application servers\n
        \t\tlocation / {\n
\n
            \t\t\tinclude            uwsgi_params;\n
            \t\t\tuwsgi_pass         uwsgicluster;\n
\n
            \t\t\tproxy_redirect     off;\n
            \t\t\tproxy_set_header   Host $host;\n
            \t\t\tproxy_set_header   X-Real-IP $remote_addr;\n
            \t\t\tproxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;\n
            \t\t\tproxy_set_header   X-Forwarded-Host $server_name;\n
\n
        }\n
    }\n
}\n'

#####################################################################
# Execution of provisioner                                          #
#####################################################################

# Update CentOS with latest paths in repositories
#
yum update -y
yum groupinstall -y development
yum install -y vim git git-core lsof mysql mysql-server mysql-devel autoconf automake wget zlib-devel openssl-devel sqlite-devel bzip2-devel

# Turn on networking
# Set networking to start at boot.
#
if grep -Fxq "ONBOOT=yes" /etc/sysconfig/network-scripts/ifcfg-eth0
    then 
        echo "Network connection already configured."
    else
        sed -i 's/^\(ONBOOT\s*=\s*\).*$/\1yes/' /etc/sysconfig/network-scripts/ifcfg-eth0
        ifup eth0
        echo "Changed ONBOOT=yes"
fi
# Install Python
#
wget http://www.python.org/ftp/python/$py_ver_maj.$py_ver_min.$py_ver_inc/Python-$py_ver_maj.$py_ver_min.$py_ver_inc.tar.xz


yum install -y xz-libs

# Let's decode (-d) the XZ encoded tar archive:
xz -d Python-$py_ver_maj.$py_ver_min.$py_ver_inc.tar.xz

# Now we can perform the extraction:
tar -xvf Python-$py_ver_maj.$py_ver_min.$py_ver_inc.tar

# Enter the file directory:
cd Python-$py_ver_maj.$py_ver_min.$py_ver_inc

# Start the configuration (setting the installation directory)
# By default files are installed in /usr/local.
# You can modify the --prefix to modify it (e.g. for $HOME).
./configure --prefix=/usr/local  

# Compile the source
# This procedure can take awhile (~a few minutes)
make && make altinstall

# Example: export PATH="[/path/to/installation]:$PATH"
# Stackoverflow recommends adding the path this way.
# echo 'pahtmunge /usr/local/bin/python2.7 > /etc/profile.d/python2.7'
export PATH="/usr/local/bin:$PATH"

# Installing pip
#
# Download the installation file using wget:
wget --no-check-certificate https://pypi.python.org/packages/source/s/setuptools/setuptools-$setup_ver_maj.$setup_ver_min.$setup_ver_inc.tar.gz

# Extract the files from the archive:
tar -xvf setuptools-$setup_ver_maj.$setup_ver_min.$setup_ver_inc.tar.gz

# Enter the extracted directory:
cd setuptools-$setup_ver_maj.$setup_ver_min.$setup_ver_inc

# Install setuptools using the Python we've installed (2.7)
python$python_ver setup.py install

wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py

#Install pip for python version
#
python$py_ver_maj.$py_ver_min get-pip.py
cd /usr/local/bin
# Installing virtualenv
#
pip install virtualenv

# Folders / Directories

mkdir -p /$base_folder/$project_folder/app # Application (module) directory
touch /$base_folder/$project_folder/WSGI.py
touch /$base_folder/$project_folder/app/__init__.python_ver
cd /$base_folder/$project_folder/

# Setup vritualenv for project.
virtualenv env
/$base_folder/$project_folder/env/bin/pip install uwsgi
/$base_folder/$project_folder/env/bin/pip install flask

# Create a sample app.
app=$'from flask import Flask\n
app = Flask(__name__)\n
\n
@app.route("/")\n
def hello():\n
\treturn "Hello!"\n
\n
if __name__ == "__main__":\n
\tapp.run()\n'

echo $app > /$base_folder/$project_folder/app/__init__.py

# Create a WSGI file.
wsgi_file=$'from app import app\n
if __name__ == "__main__":\n
\tapp.run()'
    
echo $wsgi_file > /$base_folder/$project_folder/WSGI.py
echo "---------------------------------------------"
echo "Project files, environement and WSGI setup."
echo "---------------------------------------------"

# Installing nginx.
rpm -Uvh http://dl.fedoraproject.org/pub/epel/$sys_ver_maj/x86_64/epel-release-$sys_ver_maj-$sys_ver_min.noarch.rpm

yum install -y nginx

# Configure nginx
if [ -f /etc/nginx/nginx.conf ]
    then 
        mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak



service nginx restart
echo "---------------------------------------------"
echo "Nginx installed."
echo "---------------------------------------------"

# Start MySQL
# TODO - set non root user and password for MySQL
#
service mysqld start
chkconfig mysqld on
echo "---------------------------------------------"
echo "MySQL installed and started."
echo "---------------------------------------------"

# Create MySQL user and grant privileges.
# Add database for Drupal site
#
mysql -u 'root' -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password'"
mysql -u 'root' -e "GRANT ALL PRIVILEGES ON *.* TO '$db_user'@'localhost' WITH GRANT OPTION"
mysql -u 'root' -e "FLUSH PRIVILEGES"
mysql -u 'root' -e "CREATE DATABASE $db_name"

# Import site-data content into MySQL databases.
#
if [ -f "/$base_folder/$project_folder/$db_sql_prod" ]; then
  # add content into Drupal site databases
  mysql -u 'root' $db_name < /$base_folder/$project_folder/$db_sql_prod
else
  echo -e "Cannot find $db_name and/or $db_name_hib in the following path:\n  /$base_folder/$project_folder"
fi

# Configure hosts file.
# Check for domain name resolution in hosts file
# If not already set add address/name for resolution.
#
if grep -Fxq "$address $domain_name" /etc/hosts
  then
    echo "$domain_name is already added to the loopback address."
  else
    cp /etc/hosts /etc/hosts.back
    echo "$address $domain_name" >> /etc/hosts
fi

# Configure Git
#
git config --global user.name "$username"
git config --global user.email "$email"
git config --global  core.editor "$editor"
git config --list
echo "---------------------------------------------"
echo "Git global settings configured."
echo "---------------------------------------------"

# # IP tables configuration
# #
# /etc/init.d/iptables stop
# iptables -F
# iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
# iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
# iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
# iptables -A INPUT -i lo -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 25 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 465 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 110 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 995 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 143 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 993 -j ACCEPT
# iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
# iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# iptables -P OUTPUT ACCEPT
# iptables -P INPUT DROP
# iptables-save | sudo tee /etc/sysconfig/iptables
# service iptables restart
# echo "iptables configured"

env/bin/uwsgi --socket 127.0.0.1:8088 -w WSGI:app &
 
echo "---------------------------------------------"
echo "               SYSTEM COMPLETE!              "
echo "---------------------------------------------"
