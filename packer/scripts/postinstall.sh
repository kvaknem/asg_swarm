sudo date > /build_time

# Apt-install various things necessary for Ruby, guest additions,
# etc., and remove optional things to trim down the machine.
sudo apt-get -y update
sudo apt-get -y install vim curl awscli jq
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -y update
sudo apt-get -y install docker-ce
sudo apt-get clean
sudo systemctl enable docker

# Setup sudo to allow no-password sudo for "devops"
sudo useradd -m devops
sudo usermod -a -G sudo devops
sudo usermod -aG docker devops
sudo cp /etc/sudoers /etc/sudoers.orig
sudo sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=sudo' /etc/sudoers
sudo sed -i -e 's/%sudo ALL=(ALL) ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers

# Installing  keys
sudo mkdir /home/devops/.ssh
sudo chmod -R a+rwx /home/devops/.ssh/
sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDcp/lDcx6rlV2wPgMbSCzPzoovzSnrjNrc6HAR2fAYZiofJKJVixFxKLgBIRuP9bVxVpyvaJ56hfYWLBYQbS1IGcyPUz+zifUr1EHosa/0iBooMsgTsFWOVxuxZeGVx1EOf5COgHIm5t848LTcCH5HtvM/l/I5bUqTT4y84M9r/+lzDoIGXrjepgDexzq6rxJjTjfEe+GCOesy4jjBZ4xbp3+UqqposItSOBxhif1w7771m4CPrIKouc3D/l2AZa21shcw8qyGQcbQgxi6cQ1IVi+UVSP9ZdKGt21MAQvPCWacKGHfYTgcFN4msMrxzLF42C0vyzcPtP9BdxfOU0qb s_kulev@ua1-ll-006" > /home/devops/.ssh/authorized_keys
sudo chmod 600 /home/devops/.ssh/authorized_keys
sudo chown -R devops:devops /home/devops/.ssh
sudo chmod -R go= /home/devops/.ssh
sudo chown -R devops:devops /home/devops/.ssh

sudo apt-get -y autoremove

exit
