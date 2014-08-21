#!/usr/bin/env bash

# Script to provision a CentOS 6.4 64-bit web server using Vagrant
# written by James Dugger
# Date: 5-22-14
# Updated: 6-28/14

# Global Variables.
# Project folder variable for use in make dir and virtual hosts config file.
#
project_folder="kidwork_py"

# DocumentRoot variable for virtual host config file.
#
doc_root="docroot"

# version of PHP to install. Choice of 5.4 or 5.5.
#
php_version="5.4"

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
servername="kidserv_py"

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

# Update CentOS with latest paths in repositories
#
yum update -y
yum install -y vim git git-core lsof mysql mysql-server mysql-devel autoconf automake wget
yum groupinstall -y development
yum install -y zlib-devel openssl-devel sqlite-devel bzip2-devel

# Turn on networking
# Set networking to start at boot.
#
sed -i 's/^\(ONBOOT\s*=\s*\).*$/\1yes/' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "Changed ONBOOT=yes"
ifup eth0

# Install Python
#
wget http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tar.xz


yum install xz-libs

# Let's decode (-d) the XZ encoded tar archive:
xz -d Python-2.7.6.tar.xz

# Now we can perform the extraction:
tar -xvf Python-2.7.6.tar

# Enter the file directory:
cd Python-2.7.6

# Start the configuration (setting the installation directory)
# By default files are installed in /usr/local.
# You can modify the --prefix to modify it (e.g. for $HOME).
./configure --prefix=/usr/local  

# Let's build (compile) the source
# This procedure can take awhile (~a few minutes)
make && make altinstall

# Example: export PATH="[/path/to/installation]:$PATH"
export PATH="/usr/local/bin:$PATH"

# Installing pip
#
# Let's download the installation file using wget:
wget --no-check-certificate https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.2.tar.gz

# Extract the files from the archive:
tar -xvf setuptools-1.4.2.tar.gz

# Enter the extracted directory:
cd setuptools-1.4.2

# Install setuptools using the Python we've installed (2.7.6)
python2.7 setup.py install

curl https://raw.github.com/pypa/pip/master/contrib/get-pip.py | python2.7 -


# Installing virtualenv
#
pip install virtualenv

# Folders / Directories

mkdir -p /$base_folder/$project_folder/app # Application (module) directory
mkdir -p /$base_folder/$project_folder/env/bin/ # Environment directory
# Create virtual environment
#
cd /$base_folder/$project_folder
virtualenv env

# Download and install uwsgi
/$base_folder/$project_folder/env/bin/pip install uwsgi

# Download and install Flask library.
/$base_folder/$project_folder/env/bin/pip install flask

# Create a sample app.
app='from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello!"

if __name__ == "__main__":
    app.run()'

echo $app > /$base_folder/$project_folder/app/__init__.py

# Create a WSGI file.
wsgi_file='from app import app

if __name__ == "__main__":
    app.run()'
    
echo $wsgi_file > /$base_folder/$project_folder/WSGI.py


# Installing nginx.
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

yum install -y nginx

# Start nginx
sudo service nginx start

# Configure nginx
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
nginx_conf='worker_processes 1;

events {

    worker_connections 1024;

}

http {

    sendfile on;

    gzip              on;
    gzip_http_version 1.0;
    gzip_proxied      any;
    gzip_min_length   500;
    gzip_disable      "MSIE [1-6]\.";
    gzip_types        text/plain text/xml text/css
                      text/comma-separated-values
                      text/javascript
                      application/x-javascript
                      application/atom+xml;

    # Configuration containing list of application servers
    upstream uwsgicluster {

        server 127.0.0.1:8080;
        # server 127.0.0.1:8081;
        # ..
        # .

    }

    # Configuration for Nginx
    server {

        # Running port
        listen 80;

        # Settings to by-pass for static files 
        location ^~ /static/  {

            # Example:
            # root /full/path/to/application/static/file/dir;
            root /app/static/;

        }

        # Serve a static file (ex. favico) outside static dir.
        location = /favico.ico  {

            root /app/favico.ico;

        }

        # Proxying connections to application servers
        location / {

            include            uwsgi_params;
            uwsgi_pass         uwsgicluster;

            proxy_redirect     off;
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Host $server_name;

        }
    }
}'

echo $nginx_conf > /etc/nginx/nginx.conf

sudo service nginx restart

# Start MySQL
# TODO - set non root user and password for MySQL
#
service mysqld start
chkconfig mysqld on
echo "MySQL installed and started"

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
echo "Git global settings configured."vagran

# IP tables configuration
#
/etc/init.d/iptables stop
iptables -F
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 25 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 465 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 110 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 995 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 143 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 993 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP
iptables-save | sudo tee /etc/sysconfig/iptables
service iptables restart
echo "iptables configured"

env/bin/uwsgi --socket 127.0.0.1:8088 -w WSGI:app &
 
echo "---------------------------------------------"
echo "               SYSTEM COMPLETE!              "
echo "---------------------------------------------"
