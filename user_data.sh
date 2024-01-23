#!/bin/bash

apt update
apt install apache2 -y
#apt install net-tools -y
sed -i 's/80/8080/g' /etc/apache2/sites-available/000-default.conf
sed -i 's/80/8080/g' /etc/apache2/ports.conf
systemctl stop apache2
systemctl start apache2

  
