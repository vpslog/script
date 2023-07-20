#!/bin/bash
# Set inotify max_user_instances and max_user_watches values in sysctl.conf
echo "fs.inotify.max_user_instances=16384" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=262144" | sudo tee -a /etc/sysctl.conf

# Reload the sysctl.conf file
sudo sysctl -p

# Restart the lxc.service
sudo systemctl restart lxc.service

# End of script
