#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
set -x

yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
chmod 644 /var/www/html/index.html

systemctl status httpd
