# Bug in docker/packer needs to append slash in salt paths:
# https://github.com/mitchellh/packer/issues/1040
Vagrant.configure("2") do |config|
  config.ssh.forward_x11 = true
  config.ssh.forward_agent = true

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "1024"]
  end

  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "ls-ext"

  config.vm.provision :shell, inline: <<SCRIPT
  apt-get install -y firefox
SCRIPT

  config.vm.provision :docker do |d|
    d.pull_images "ubuntu"
  end

end