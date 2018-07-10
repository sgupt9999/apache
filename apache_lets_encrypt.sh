#!/bin/bash
#################################################################################
# This script will setup an apache server on this machine and also install an SSL
# certificate from Let's encrypt for https access
#################################################################################
# Start of user inputs
DOMAIN="garfield99991.mylabserver.com"
FIREWALL="yes"
#FIREWALL="NO"
ADMIN_EMAIL="sgupt9999@gmail.com"
# End of user inputs

INSTALLPACKAGES="httpd"
INSTALLPACKAGES2="openssl mod-ssl certbot python2-certbot-apache"

if [[ $EUID != 0 ]]
then
	echo
	echo "###########################################################"
	echo "ERROR. You need to have root privileges to run this script"
	echo "###########################################################"
	exit 1
else
	echo
	echo "############################################################################"
	echo "This script will install an Apache Server on this machine"
	echo "It will also install a free SSL certificate from Let's Encrypt"
	echo "The script can also create a cron job to automatically renew the certficate"
	echo "############################################################################"
fi

if yum list installed $INSTALLPACKAGES > /dev/null 2>&1
then
	systemctl -q is-active httpd && {
	systemctl stop httpd
	systemctl -q disable httpd
	}
	echo
	echo "########################################################"
	echo "Removing old packages ................................."
	yum remove $INSTALLPACKAGES -y -q > /dev/null 2>&1
	rm -rf /var/www
        rm -rf /etc/httpd
        rm -rf /usr/lib/httpd
        echo "Done"
	echo "########################################################"
fi

echo
echo "########################################################"
echo "Installing packages ...................................."
yum install $INSTALLPACKAGES -y -q > /dev/null 2>&1
echo "Done"
echo "########################################################"

echo "This is the website for $DOMAIN" > /var/www/html/index.html
systemctl start httpd
systemctl -q enable httpd

if [[ $FIREWALL == "yes" ]]
then
	if systemctl -q is-active firewalld
	then
		echo
		firewall-cmd -q --permanent --add-service http
		firewall-cmd -q --permanent --add-service https
		firewall-cmd -q --reload
		echo "############################################"
		echo "Http and https added to firewall protection"
		echo "############################################"
	else
		echo
		echo "#####################################################"
		echo "Firewalld not active. No change made to the firewall"
		echo "#####################################################"
	fi
fi


echo
echo "#############################################################################################################"
echo "Testing http connection.."
echo -n "curl http://$DOMAIN ----------->  "
curl -s http://$DOMAIN
echo "#############################################################################################################"

echo
echo "#############################################################################################################"
echo "Testing https connection.."
echo -n "curl https://$DOMAIN ----------->  "
curl https://$DOMAIN
echo "#############################################################################################################"
sleep 5

echo
echo "######################################################"
echo "Installing packages for Let's Encrypt SSL certificate"
yum install -y $INSTALLPACKAGES2
echo "Done"
echo "######################################################"

systemctl restart httpd
