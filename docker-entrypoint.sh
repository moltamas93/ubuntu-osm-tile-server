#!/bin/bash
set -e

sudo /etc/init.d/postgresql start
sudo /etc/init.d/apache2 start

sudo chown root /var/run/renderd

/bin/bash
