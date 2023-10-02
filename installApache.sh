#!/bin/bash
apt update -y
apt install apache2 -y
systemctl start apache2
echo "terraform is online" >> /var/www/html/index.html"