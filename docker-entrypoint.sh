#!/bin/bash
set -e

sudo /etc/init.d/postgresql start
sudo /etc/init.d/apache2 start

#sudo mkdir /var/run/renderd
sudo chown root /var/run/renderd
sudo -u root renderd -c /usr/local/etc/renderd.conf
sudo service apache2 reload


#sed -i 's#DAEMON=/usr/bin/$NAME#$DAEMON#' /etc/init.d/renderd
#sed -i 's#DAEMON_ARGS=""#$DAEMON_ARGS' /etc/init.d/renderd

/bin/bash