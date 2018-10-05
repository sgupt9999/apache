#!/bin/bash

# Testing why is the beavior incosistent with self signed CA
# Tested on AWS and Linux Academy and works on public ip, private ip and the hostname. The hostname doesnt have to be the same as FQDN


#CN="garfield99996.mylabserver.com"
CN=18.223.152.146
IPSERVER=172.31.31.177
FILE="/etc/httpd/conf/httpd.conf"


systemctl stop httpd
yum remove httpd -y
rm -rf /var/www
rm -rf /etc/httpd

yum install httpd -y
yum install mod_ssl -y
systemctl enable --now httpd


rm -rf /etc/pki/tls/certs/rootca.*
rm -rf /etc/pki/tls/certs/mylabserver.*
cd /etc/pki/tls/certs
openssl genpkey -out rootca.key -algorithm RSA -pkeyopt rsa_keygen_bits:4096
#openssl req -x509 -days 365 -out rootca.crt -subj "/OU=RootAgency/CN=RootAgency/emailAddress=admin@rootagency.com" -set_serial 100 -key ./rootca.key
openssl req -x509 -days 365 -out rootca.crt -subj "/OU=RootAgency/CN=RootAgency20dgdgdg00" -set_serial 101 -key ./rootca.key
#openssl req -newkey rsa:2048 -out mylabserver.csr -subj "/OU=CMEI1/CN=$CN" -nodes -keyout mylabserver.key


# Need to specify the CN value here. If coming from a variable keeps giving an error
openssl req -newkey rsa:2048 -out mylabserver.csr -subj "/OU=CMEI1/CN=18.223.152.146" -nodes -keyout mylabserver.key 
openssl x509 -req -days 365 -CA ./rootca.crt -CAkey ./rootca.key -out mylabserver.crt -set_serial 501 -in mylabserver.csr
chmod 0600 *.key


# Add the new root CA to the trusted sources
cd /etc/pki/ca-trust/source/anchors/
rm -rf *
cp /etc/pki/tls/certs/rootca.crt .
update-ca-trust extract

# Create a directory for the virtualhost
rm -rf /test
mkdir /test
echo "This is the test directory" > /test/index.html
semanage fcontext -a -t httpd_sys_content_t "/test(/.*)?"
restorecon -r /test


echo "<VirtualHost $IPSERVER:443>" >> $FILE
echo "        DocumentRoot /test" >> $FILE
echo    "SSLEngine on" >> $FILE
echo    "SSLCertificateFile /etc/pki/tls/certs/mylabserver.crt" >> $FILE
echo    "SSLCertificateKeyFile /etc/pki/tls/certs/mylabserver.key" >> $FILE
echo    "</VirtualHost>" >> $FILE
echo    "<Directory /test>" >> $FILE
echo    "require all granted" >> $FILE
echo    "</Directory>" >> $FILE


systemctl restart httpd
clear


echo "curl https://$CN"
curl https://$CN
