#!/bin/bash -e
# script for running ansible internally on the instance instead of from the local machine

PLAYBOOK=""
GROUP=""
EXTRA_VARS=""
INVENTORY="/etc/ansible/hosts"
APPLICATION_ENVIRONMENT=""

# parse options
while : 
do
    if [[ "$1" == --* ]]; then
    	case $1 in
			"--playbook" ) PLAYBOOK=$2; shift; shift;;
			"-i" ) INVENTORY=$2; shift; shift;;
            "--group" ) GROUP=$2; shift; shift;;
            "--environment" ) APPLICATION_ENVIRONMENT=$2; shift; shift;;
            "--inventory" ) INVENTORY=$2; shift; shift;;
			"--extra-vars" ) EXTRA_VARS=$2; shift; shift;;
    	    * ) echo "Error: unknown option $1"; echo;;
    	esac
    else
	   break
    fi
done

date

if [[ -z $(grep "8.8.8.8" /etc/network/interfaces) ]]; then
	echo "USING GOOGLE NAMESERVERS"
	sed -i 's/.*iface eth0 inet dhcp.*/&\n  dns-nameservers 8.8.8.8 8.8.4.4/' /etc/network/interfaces
	ifdown eth0 && ifup eth0
fi

apt-get install -y dpkg
dpkg -s ansible && ANSIBLE_INSTALLED='YES' || ANSIBLE_INSTALLED=''

if [[ -z $ANSIBLE_INSTALLED ]]; then
	echo "INSTALLING ANSIBLE"
	apt-get update
	apt-get install -y -q python-software-properties 
	add-apt-repository -y ppa:rquillo/ansible
	apt-get update
	apt-get install -y -q ansible
	echo "127.0.0.1" > /etc/ansible/hosts
fi

if [[ -n "${GROUP}" ]]; then
	echo "CREATING CUSTOM INVENTORY"
	echo -e "[${APPLICATION_ENVIRONMENT}]\n127.0.0.1\n\n[${GROUP}:children]\n${APPLICATION_ENVIRONMENT}" > ${INVENTORY}
fi

echo "CREATING LOCAL COPY OF INVENTORY"
if [[ -d "/tmp/inventory" ]]; then
	rm -rf /tmp/inventory
fi
mkdir /tmp/inventory
cp ${INVENTORY} /tmp/inventory/hosts
chmod -x /tmp/inventory/hosts
SOURCE_DIR=$(dirname ${INVENTORY})
if [[ -d "${SOURCE_DIR}/group_vars" ]]; then
	cp -R ${SOURCE_DIR}/group_vars /tmp/inventory/
fi
if [[ -d "${SOURCE_DIR}/host_vars" ]]; then
	cp -R ${SOURCE_DIR}/host_vars /tmp/inventory/
fi

if [[ -n "${EXTRA_VARS}" ]]; then
	echo "BUILDING WITH EXTRA VARS: ${EXTRA_VARS}"
fi

echo "RUNNING PLAYBOOK"
ANSIBLE_FORCE_COLOR=True ansible-playbook -v -c local "${PLAYBOOK}" -i /tmp/inventory/hosts --extra-vars "${EXTRA_VARS}"

echo "REMOVING LOCAL COPY OF INVENTORY"
rm -rf /tmp/inventory