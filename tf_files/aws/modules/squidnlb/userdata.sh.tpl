#!/bin/bash
cd /home/ubuntu
sudo git clone https://github.com/uc-cdis/cloud-automation.git
sudo chown -R ubuntu. /home/ubuntu/cloud-automation
cd /home/ubuntu/cloud-automation
git pull
sudo chown -R ubuntu. /home/ubuntu/cloud-automation

echo "127.0.1.1 ${hostname}" | sudo tee --append /etc/hosts
sudo hostnamectl set-hostname ${hostname}

sudo apt -y update
sudo DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade | sudo tee --append /var/log/bootstrapping_script.log

sudo apt-get autoremove -y
sudo apt-get clean
sudo apt-get autoclean

cd /home/ubuntu
# git 2.35.2+ rejects operations in directories owned by a different user.
# The root crontab runs updatewhitelist.sh which calls git pull in these
# directories after ownership has been transferred to ubuntu/sftpuser.
sudo git config --global --add safe.directory /home/ubuntu/cloud-automation
sudo git config --global --add safe.directory /home/ec2-user/cloud-automation
sudo git config --global --add safe.directory /home/sftpuser/cloud-automation
sudo bash "${bootstrap_path}${bootstrap_script}" 2>&1 | sudo tee --append /var/log/bootstrapping_script.log
# squidvm.sh installs /etc/iptables.conf and the if-up.d hook but does not
# apply the rules; eth0 is already up when user_data runs so the hook never
# fires on first boot. Apply immediately so squid intercepts traffic without
# requiring a reboot.
sudo iptables-restore < /etc/iptables.conf
