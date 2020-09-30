#!/bin/bash
#mdugoua
#30/09/202

# Creat a user
useradd web -M -s /sbin/nologin

# mv the key cert to standar pathway
mv /tmp/server.key /etc/pki/tls/private/node1.tp2.b2.key
chmod 400 /etc/pki/tls/private/node1.tp2.b2.key
chown web:web /etc/pki/tls/private/node1.tp2.b2.key

mv /tmp/server.crt /etc/pki/tls/certs/node1.tp2.b2.crt
chmod 444 /etc/pki/tls/certs/node1.tp2.b2.crt
chown web:web /etc/pki/tls/certs/node1.tp2.b2.crt

cp /etc/pki/tls/certs/node1.tp2.b2.crt /usr/share/pki/ca-trust-source/anchors/
update-ca-trust

mkdir /srv/site{1,2}
# 
echo '<h1>Hello from site 1</h1>' | tee /srv/site1/index.html
echo '<h1>Hello from site 2</h1>' | tee /srv/site2/index.html
chown web:web /srv/site1 -R
chmod 700 /srv/site1 /srv/site2
chmod 400 /srv/site1/index.html /srv/site2/index.html

mv /tmp/nginx.conf /etc/nginx/nginx.conf

systemctl start nginx