#!/bin/bash
#
# All the apache web server objectives for the RHCE exam
#

INSTALLPACKAGES="httpd firewalld openssl mod_ssl"
REMOVEPACKAGES="httpd httpd-tools"
PUBLICIP=54.187.174.5
PRIVATEIP=172.31.30.29
SERVER1="server1.myserver.com"
SERVER2="server2.myserver.com"

clear

if (( $EUID != 0 )) 
then
	echo "ERROR: need to have root privileges to run the script"
	exit 1
fi

if yum list installed httpd > /dev/null 2>&1 
then
	systemctl is-active -q httpd && { 
		systemctl stop httpd
		systemctl disable -q httpd
	}
	echo "Removing all httpd packages...."
	yum remove -y -q $REMOVEPACKAGES
	userdel -r apache &>/dev/null
	rm -rf /var/www
	rm -rf /etc/httpd
	rm -rf /usr/lib/httpd
	echo "Done"
fi

echo "Installing packages......"
yum install -y -q  $INSTALLPACKAGES

systemctl start $INSTALLPACKAGES &>/dev/null
systemctl enable $INSTALLPACKAGES &>/dev/null

# Add http service to the firewall
firewall-cmd -q --permanent --add-service http
firewall-cmd -q --reload


echo "This is the default document root" > /var/www/html/index.html

echo
echo "########################################################################################"
echo "Test for Default content location - /var/www/html"
echo -n "curl $PUBLICIP -----> "
curl -s $PUBLICIP


# Making a non default content directory
rm -rf /mycontent
mkdir /mycontent	
echo "This is a non-default document root" > /mycontent/index.html
semanage fcontext -a -t httpd_sys_content_t "/mycontent(/.*)?"
restorecon -R /mycontent

sed -i "s/DocumentRoot/# DocumentRoot/g" /etc/httpd/conf/httpd.conf
echo "DocumentRoot /mycontent" >> /etc/httpd/conf/httpd.conf
echo "<Directory /mycontent>" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted"  >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

systemctl restart httpd

echo
echo "########################################################################################"
echo "Test for Non-Default location - /mycontent"
echo -n "curl $PUBLICIP -----> "
curl -s $PUBLICIP

# Adding username/password for 1 user - Method 1
rm -rf /userdir1
mkdir /userdir1
echo "Adding one user to the config file" > /userdir1/index.html
semanage fcontext -a -t httpd_sys_content_t "/userdir1(/.*)?"
restorecon -R /userdir1
htpasswd -c -b /etc/httpd/conf/passwords webuser1 redhat1 &>/dev/null

sed -i "s/^DocumentRoot/# DocumentRoot/g" /etc/httpd/conf/httpd.conf
echo "DocumentRoot /" >> /etc/httpd/conf/httpd.conf
echo "<Directory userdir1>" >> /etc/httpd/conf/httpd.conf
echo "	AllowOverride AuthConfig" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

echo "AuthType Basic" >> /userdir1/.htaccess
echo "AuthName 'User Authentication #1'" >> /userdir1/.htaccess
echo "AuthUserFile /etc/httpd/conf/passwords" >> /userdir1/.htaccess
echo "Require user webuser1" >> /userdir1/.htaccess

systemctl restart httpd

echo
echo "########################################################################################"
echo "Test for specifying one username in the config file"
echo "Added webuser1 to the config and the password file"
echo -n "curl -u webuser1:redhat1 $PUBLICIP/userdir1/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser1:redhat1 $PUBLICIP/userdir1/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

# Adding username/password for a multiple users - Method 1
# Specifying all the valid users explicitly in the config file

rm -rf /userdir2
mkdir /userdir2
echo "Decalring all the users with the permission in the config file" > /userdir2/index.html
semanage fcontext -a -t httpd_sys_content_t "/userdir2(/.*)?"
restorecon -R /userdir2
htpasswd -b /etc/httpd/conf/passwords webuser2 redhat2 &>/dev/null
htpasswd -b /etc/httpd/conf/passwords webuser3 redhat3 &>/dev/null

echo "<Directory userdir2>" >> /etc/httpd/conf/httpd.conf
echo "	AllowOverride AuthConfig" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

echo "AuthType Basic" >> /userdir2/.htaccess
echo "AuthName 'User Authentication #2'" >> /userdir2/.htaccess
echo "AuthUserFile /etc/httpd/conf/passwords" >> /userdir2/.htaccess
echo "Require user webuser1 webuser2" >> /userdir2/.htaccess

systemctl restart httpd

echo
echo "########################################################################################"
echo "Test for declaring a list of users with permissions. Only users specified in the config file will be let in"
echo "Added webuser2 to the config and the password file"

echo -n "curl -u webuser1:redhat1 $PUBLICIP/userdir2/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser1:redhat1 $PUBLICIP/userdir2/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser2:redhat2 $PUBLICIP/userdir2/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser2:redhat2 $PUBLICIP/userdir2/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser3:redhat3 $PUBLICIP/userdir2/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser3:redhat3 $PUBLICIP/userdir2/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi


# Adding username/password for multiple users - Method 2
# Using a valid-user directive instead of specifying users in the config file
# All users in the password file are allowed in if they enter the correct password

rm -rf /userdir3
mkdir /userdir3
echo "Using the valid-user directive for multiple users" > /userdir3/index.html
semanage fcontext -a -t httpd_sys_content_t "/userdir3(/.*)?"
restorecon -R /userdir3

echo "<Directory userdir3>" >> /etc/httpd/conf/httpd.conf
echo "	AllowOverride AuthConfig" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

echo "AuthType Basic" >> /userdir3/.htaccess
echo "AuthName 'User Authentication #3'" >> /userdir3/.htaccess
echo "AuthUserFile /etc/httpd/conf/passwords" >> /userdir3/.htaccess
echo "Require valid-user" >> /userdir3/.htaccess

systemctl restart httpd

echo
echo "########################################################################################"
echo "Test for valid-user directive. All users in the password file with the correct password are let in"
echo "Added webuser3 to the password file"
echo -n "curl -u webuser1:redhat1 $PUBLICIP/userdir3/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser1:redhat1 $PUBLICIP/userdir3/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser2:redhat2 $PUBLICIP/userdir3/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser2:redhat2 $PUBLICIP/userdir3/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser3:redhat3 $PUBLICIP/userdir3/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser3:redhat3 $PUBLICIP/userdir3/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser4:redhat4 $PUBLICIP/userdir3/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser4:redhat4 $PUBLICIP/userdir3/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi


# Adding username/password for multiple users - Method 3 
# Using a group file to speficy the users belonging to that group
# Only users in that group are allowed in

rm -rf /userdir4
mkdir /userdir4
echo "Using the group directive for multiple users" > /userdir4/index.html
semanage fcontext -a -t httpd_sys_content_t "/userdir4(/.*)?"
restorecon -R /userdir4
#userdel webuser4 &>/dev/null
#useradd webuser4 &>/dev/null
htpasswd -b /etc/httpd/conf/passwords webuser4 redhat4 &>/dev/null

echo "<Directory userdir4>" >> /etc/httpd/conf/httpd.conf
echo "	AllowOverride AuthConfig" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

echo "AuthType Basic" >> /userdir4/.htaccess
echo "AuthName 'User Authentication #4'" >> /userdir4/.htaccess
echo "AuthUserFile /etc/httpd/conf/passwords" >> /userdir4/.htaccess
echo "AuthGroupFile /etc/httpd/conf/groups" >> /userdir4/.htaccess
echo "Require group team" >> /userdir4/.htaccess

echo "team: webuser1 webuser2 webuser4" > /etc/httpd/conf/groups

systemctl restart httpd

echo
echo "########################################################################################"
echo "Test for group directive. All users in the group file with the correct password are let in"
echo "Added webuser1 webuser2 and webuser4 to the group file and webuser4 to the password file"
echo -n "curl -u webuser1:redhat1 $PUBLICIP/userdir4/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser1:redhat1 $PUBLICIP/userdir4/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser2:redhat2 $PUBLICIP/userdir4/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser2:redhat2 $PUBLICIP/userdir4/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser3:redhat3 $PUBLICIP/userdir4/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser3:redhat3 $PUBLICIP/userdir4/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi

echo -n "curl -u webuser4:redhat4 $PUBLICIP/userdir4/index.html -----> "
if [ `curl -s -o /dev/null -w %{http_code} -u webuser4:redhat4 $PUBLICIP/userdir4/index.html` -eq "200" ]
then
	echo "SUCCESS"
else
	echo "ERROR"
fi



# Running a cgi-script
# To be able to run a cgi-script from /myscripts directory

rm -rf /myscripts
mkdir -p /myscripts/cgi-bin
cat > /myscripts/cgi-bin/test.sh << EOF
#!/bin/bash
echo
Content-type: text/html
echo "The current time is `date`"
echo
EOF

chmod a+x /myscripts/cgi-bin/test.sh
semanage fcontext -a -t httpd_sys_script_exec_t "/myscripts(/.*)?"
restorecon -R /myscripts
setsebool -P httpd_enable_cgi=1

sed -i 's#ScriptAlias /cgi-bin/ "/var/www/cgi-bin/"#ScriptAlias /cgi-bin/ /myscripts/cgi-bin/#g' /etc/httpd/conf/httpd.conf
echo "<Directory myscripts>" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

systemctl restart httpd
echo
echo "########################################################################################"
echo "Test to be able to run cgi-scripts"
echo -n "curl $PUBLICIP/cgi-bin/test.sh -----> "
if [ `curl -s -o /dev/null -w %{http_code} $PUBLICIP/cgi-bin/test.sh` -eq "200" ]
then
	curl -s $PUBLICIP/cgi-bin/test.sh
else
	echo "ERROR"
fi

# Setting up virtual hosts
echo "$PRIVATEIP $SERVER1" >> /etc/hosts
echo "$PRIVATEIP $SERVER2" >> /etc/hosts

rm -rf /myvhost1
mkdir /myvhost1
echo "This is the directory location for $SERVER1 virtual host" > /myvhost1/index.html
semanage fcontext -a -t httpd_sys_content_t "/myvhost1(/.*)?"
restorecon -R /myvhost1


echo "<VirtualHost *:80>" >> /etc/httpd/conf/httpd.conf
echo "	DocumentRoot /myvhost1" >> /etc/httpd/conf/httpd.conf
echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf

echo "<Directory /myvhost1>" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

systemctl restart httpd

echo
echo "########################################################################################"
echo "Setup a Virtual host to listen on port 80"
echo -n "curl $SERVER1 -----> "
if [ `curl -s -o /dev/null -w %{http_code} $SERVER1` -eq "200" ]
then
#	echo "SUCCESS"
	curl -s $SERVER1
	echo -n "curl $PUBLICIP -----> "
	curl -s $PUBLICIP
else
	echo "ERROR"
fi

# Setting up a virtual host with a self signed certificate
echo "Creating a new private key and a self signed certificate"
rm -rf /etc/pki/tls/certs/myserver*
openssl req -x509 -days 365 -newkey rsa:2048 -nodes -keyout /etc/pki/tls/certs/myserver.key -out /etc/pki/tls/certs/myserver.crt -subj "/C=US/ST=Texas/L=Houston/O=CMEI/CN=$PUBLICIP" &>/dev/null

rm -rf /myvhost2
mkdir /myvhost2

echo "Virtual Host with a self-signed certificate- Server $SERVER2" > /myvhost2/index.html
semanage fcontext -a -t httpd_sys_content_t "/myvhost2(/.*)?"
#semanage fcontext -a -t httpd_sys_content_t "/myvhost1(/.*)?"
restorecon -R /myvhost2


echo "<VirtualHost *:443>" >> /etc/httpd/conf/httpd.conf
echo "	DocumentRoot /myvhost2" >> /etc/httpd/conf/httpd.conf
echo "  SSLCertificateFile /etc/pki/tls/certs/myserver.crt" >> /etc/httpd/conf/httpd.conf
echo "  SSLCertificateKeyFile /etc/pki/tls/certs/myserver.key" >> /etc/httpd/conf/httpd.conf
echo "  ServerName $PUBLICIP:443" >> /etc/httpd/conf/httpd.conf
echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf


echo "<VirtualHost *:443>" >> /etc/httpd/conf/httpd.conf
echo "	DocumentRoot /myvhost2" >> /etc/httpd/conf/httpd.conf
echo "  SSLCertificateFile /etc/pki/tls/certs/myserver.crt" >> /etc/httpd/conf/httpd.conf
echo "  SSLCertificateKeyFile /etc/pki/tls/certs/myserver.key" >> /etc/httpd/conf/httpd.conf
echo "  ServerName server2.myserver.com:443" >> /etc/httpd/conf/httpd.conf
echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf

echo "<Directory /myvhost2>" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

systemctl restart httpd

