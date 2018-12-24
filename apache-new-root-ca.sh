#!/bin/bash

# Testing creating self-signed certificate with a new root authority
# checked on both linuxacademy and AWS and works fine

CN="garfield99994d.mylabserver.com"
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
openssl req -x509 -days 365 -out rootca.crt -subj "/OU=RootAgency/CN=RootAgency" -set_serial 101 -key ./rootca.key

openssl req -newkey rsa:2048 -out mylabserver.csr -subj "/OU=CMEI1/CN=$CN" -nodes -keyout mylabserver.key
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

# Make a backup of the default ssl.conf and create a custom file
mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.orig 

cat >/etc/httpd/conf.d/ssl.conf <<EOF
Listen 443 https
SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog
SSLSessionCache         shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout  300
SSLRandomSeed startup file:/dev/urandom  256
SSLRandomSeed connect builtin
SSLCryptoDevice builtin
SSLStrictSNIVHostCheck on

<VirtualHost *:443>
DocumentRoot /test
ServerName $CN
SSLEngine on
SSLCertificateFile /etc/pki/tls/certs/mylabserver.crt
SSLCertificateKeyFile /etc/pki/tls/certs/mylabserver.key
SSLProtocol all -SSLv2 -SSLv3
SSLCipherSuite HIGH:3DES:!aNULL:!MD5:!SEED:!IDEA
<Files ~ "\.(cgi|shtml|phtml|php3?)$">
    SSLOptions +StdEnvVars
</Files>
<Directory "/var/www/cgi-bin">
    SSLOptions +StdEnvVars
</Directory>
BrowserMatch "MSIE [2-5]" \
         nokeepalive ssl-unclean-shutdown \
         downgrade-1.0 force-response-1.0
CustomLog logs/ssl_request_log \
          "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"
</VirtualHost>

<Directory /test>
	require all granted
</Directory>

EOF

systemctl restart httpd
clear

echo "curl https://$CN"
curl https://$CN
