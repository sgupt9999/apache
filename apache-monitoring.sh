#!/bin/bash
#
# Install apache server, create a virtual host and activate server monitoring using mod_status
# mod_status shows a plain HTML page containing the information about current statistics of web server including
# total number of requests, total number of bytes, CPU usage of a web server, server load, server Uptime,  total traffic
# total number of idle workers
#

# Start of user inputs
INSTALLPACKAGES="httpd openssl mod_ssl"
REMOVEPACKAGES="httpd httpd-tools"
PUBLICIP=54.187.174.5
PRIVATEIP=172.31.30.29
SERVER1="server1.myserver.com"
SERVER2="server2.myserver.com"
# End of user inputs



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
echo "Done"

rm -rf /myserver1
mkdir /myserver1
semanage fcontext -a -t httpd_sys_content_t "/myserver1(/.*)?"
restorecon -R /myserver1
echo "This is mywebserver1" > /myserver1/index.html

# mod_status is an Apache module whch helps to monitor web server load and current httpd connections with an HTML interface
# accessible fia the web-server http:<IP-address>/server-status
echo "LoadModule status_module modules/mod_status.so" >> /etc/httpd/conf/httpd.conf
# ExtendedStatus adds more information to the staistics page like CPU usage, request per second, total traffic etc.
echo "ExtendedStatus On" >> /etc/httpd/conf/httpd.conf


echo "<VirtualHost $PRIVATEIP:80>" >> /etc/httpd/conf/httpd.conf
echo "	DocumentRoot /myserver1" >> /etc/httpd/conf/httpd.conf
echo '	<Location /server-status>' >> /etc/httpd/conf/httpd.conf
echo "	SetHandler server-status" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "	</Location>" >> /etc/httpd/conf/httpd.conf
echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf

echo "<Directory /myserver1>" >> /etc/httpd/conf/httpd.conf
echo "	Require all granted" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf

systemctl start $INSTALLPACKAGES &>/dev/null
systemctl enable $INSTALLPACKAGES &>/dev/null
