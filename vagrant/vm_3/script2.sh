#!/bin/bash
#mdugoua
#30/09/2020

# Creat a user admin
adduser "admin"
echo "admin" | passwd "admin" --stdin

echo "192.168.2.21  node1.tp2.b2" >> /etc/hosts
echo "192.168.2.22  node2.tp2.b2" >> /etc/hosts

# 
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --add-port=443/tcp --permanent
firewall-cmd --reload