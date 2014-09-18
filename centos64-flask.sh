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

####################################################################
# Execution of provisioner                                          #
#####################################################################

# Update CentOS with latest paths in repositories
#
yum update -y
yum groupinstall -y development
yum install -y vim zlib-devel openssl-devel sqlite-devel bzip2-devel
yum install xz-libs

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
if [ ! -f /Python-$py_ver_maj.$py_ver_min.$py_ver_inc ]; then

    wget http://www.python.org/ftp/python/$py_ver_maj.$py_ver_min.$py_ver_inc/Python-$py_ver_maj.$py_ver_min.$py_ver_inc.tar.xz
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

    echo "Project files, evironment and WSGI setup."
else
    echo "Project files, environment and WSGI already setup."

fi

# Installing nginx.
nginx_install=$(rpm -qa | nginx)
if [ -z $nginx_install ]; then

    rpm -Uvh http://dl.fedoraproject.org/pub/epel/$sys_ver_maj/x86_64/epel-release-$sys_ver_maj-$sys_ver_min.noarch.rpm

    yum install -y nginx

    # Move default nginx.conf to .bak
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.bak

    # Configure nginx
echo 'worker_processes 1;

events {

    worker_connections 1024;

}

http {

    sendfile on;

    gzip                on;
    gzip_http_version   1.0;
    gzip_proxied        any;
    gzip_min_length     500;
    gzip_disable        "MSIE [1-6]\.";
    gzip_types          text/plain text/xml text/css
                        text/comma-separated-values
                        text/javascript
                        application/x-javascript
                        application/atom+xml;

    # Configuration containing list of application servers
    upstream uwsgicluster {

        server 127.0.0.1:8088;
        # server 127.0.0.1:8089;
        # ..
        # .

    }

    # Configuration for Nginx
    server {

        # Running port
        listen 80;
        
        # Settings to by-pass for static files
        location ^~ /static/ {
        
            # Example:
            # root /full/path/to/appliaction/static/file/dir;
            root /app/static/;
            
        }
       
        # Serve a static file (ex. favico) outside static dir.
        location = /favico.ico {

            root /app/favico.ico;

        }
 
        # Proxying connections to application servers
        location / {
        
            include         uwsgi_params;
            uwsgi_pass      uwsgicluster;
        
            proxy_redirect      off;
            proxy_set_header    Host $host;
            proxy_set_header    X-Real-IP $remote_addr;
            proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Host $server_name;
        
        }
    }
}' > /etc/nginx/nginx.conf

    service nginx restart
    echo "Nginx installed."
else
    echo " Nginx already installed and configured."

fi

echo "SYSTEM COMPLETE!"
