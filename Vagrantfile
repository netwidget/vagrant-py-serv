# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define :centos do |centos_config|
    centos_config.vm.box = "centos64_x86_vbg432"
    # If the box has not been added to the local .vagrant.d/boxes folder than comment out line above
    # and uncomment line below.
    #centos_config.vm.box_url = "http://box.puphpet.com/centos64-x64-vbox43.box"

  end
  config.vm.provider "virtualbox" do |v|
    v.name = "kidserv" # Change to VM name.
    v.memory = 2048 
  end
  #config.vm.network :private_network, ip: "192.168.33.10"

  # Configure VM to run under VM as NAT with forwarded ports.
  config.vm.network "forwarded_port", guest: 80, host: 8088
  #config.ssh.foward_agent = true

  #config.vm.provision :shell, :path => "shell/install_vagrant_sudoers.sh"

  # Configure shared folder source and target for host and virtual machine files shares.
  # Replace <project> with the name of the project folder name. Should match $project_folder
  # centos64-webserv.sh.
  # Mac version
  config.vm.synced_folder "/Users/james/sitedev/kidwork", "/var/www/kidwork"

  # Linux version
  #config.vm.synced_folder "/home/<username>/sitedev/kidwork", "/var/www/kidwork"

  # Windows version
  # config.vm.synced_folder "/Users/James/Documents/sitedev/kidwork", "/var/www/kidwork"

  # Provision with BASH
  config.vm.provision :shell, privileged: true, :path => "centos64-flask.sh"
end