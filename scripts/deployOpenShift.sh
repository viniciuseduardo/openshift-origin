#!/bin/bash

echo $(date) " - Starting Script"

set -e

export SUDOUSER=$1
export PASSWORD="$2"
export PRIVATEKEY=$3
export MASTER=$4
export MASTERPUBLICIPHOSTNAME=$5
export MASTERPUBLICIPADDRESS=$6
export INFRA=$7
export NODE=$8
export NODECOUNT=$9
export INFRACOUNT=${10}
export MASTERCOUNT=${11}
export ROUTING=${12}
export REGISTRYSA=${13}
export ACCOUNTKEY="${14}"
export TENANTID=${15}
export SUBSCRIPTIONID=${16}
export AADCLIENTID=${17}
export AADCLIENTSECRET="${18}"
export RESOURCEGROUP=${19}
export LOCATION=${20}
export METRICS=${21}
export LOGGING=${22}
export AZURE=${23}
export STORAGEKIND=${24}
export ENABLECNS=${25}
export CNS=${26}
export CNSCOUNT=${27}

export MASTERLOOP=$((MASTERCOUNT - 1))
export INFRALOOP=$((INFRACOUNT - 1))
export NODELOOP=$((NODECOUNT - 1))

# Generate private keys for use by Ansible
echo $(date) " - Generating Private keys for use by Ansible for OpenShift Installation"

runuser -l $SUDOUSER -c "echo \"$PRIVATEKEY\" > ~/.ssh/id_rsa"
runuser -l $SUDOUSER -c "chmod 600 ~/.ssh/id_rsa*"

echo $(date) "- Configuring SSH ControlPath to use shorter path name"

sed -i -e "s/^# control_path = %(directory)s\/%%h-%%r/control_path = %(directory)s\/%%h-%%r/" /etc/ansible/ansible.cfg
sed -i -e "s/^#host_key_checking = False/host_key_checking = False/" /etc/ansible/ansible.cfg
sed -i -e "s/^#pty=False/pty=False/" /etc/ansible/ansible.cfg


# Cloning Ansible playbook repository
echo $(date) "- Cloning Openshift Ansible Playbook"
(cd /home/$SUDOUSER && rm -Rf openshift-container-platform-playbooks && git clone https://github.com/Microsoft/openshift-container-platform-playbooks.git)
if [ -d /home/${SUDOUSER}/openshift-container-platform-playbooks ]
then
  chmod -R 777 /home/$SUDOUSER/openshift-container-platform-playbooks
  echo " - Retrieved playbooks successfully"
else
  echo " - Retrieval of playbooks failed"
  exit 99
fi

# Create glusterfs configuration if CNS is enabled
if [ $ENABLECNS == "true" ]
then
echo $(date) " - Creating glusterfs configuration"
registrygluster="openshift_hosted_registry_storage_kind=glusterfs"

for (( c=0; c<$CNSCOUNT; c++ ))
do
  runuser $SUDOUSER -c "ssh-keyscan -H $CNS-$c >> ~/.ssh/known_hosts"
  drive=$(runuser $SUDOUSER -c "ssh $CNS-$c 'sudo /usr/sbin/fdisk -l'" | awk '$1 == "Disk" && $2 ~ /^\// && ! /mapper/ {if (drive) print drive; drive = $2; sub(":", "", drive);} drive && /^\// {drive = ""} END {if (drive) print drive;}')
  drive1=$(echo $drive | cut -d ' ' -f 1)
  drive2=$(echo $drive | cut -d ' ' -f 2)
  drive3=$(echo $drive | cut -d ' ' -f 3)
  cnsglusterinfo="$cnsglusterinfo
$CNS-$c glusterfs_devices='[ \"${drive1}\", \"${drive2}\", \"${drive3}\" ]'"
done
fi

# Create Master nodes grouping
echo $(date) " - Creating Master nodes grouping"

for (( c=0; c<$MASTERCOUNT; c++ ))
do
  mastergroup="$mastergroup
$MASTER-$c openshift_node_labels=\"{'region': 'master', 'zone': 'default'}\" openshift_hostname=$MASTER-$c"
done

# Create Infra nodes grouping 
echo $(date) " - Creating Infra nodes grouping"

for (( c=0; c<$INFRACOUNT; c++ ))
do
  infragroup="$infragroup
$INFRA-$c openshift_node_labels=\"{'region': 'infra', 'zone': 'default'}\" openshift_hostname=$INFRA-$c"
done

# Create Nodes grouping
echo $(date) " - Creating Nodes grouping"

for (( c=0; c<$NODECOUNT; c++ ))
do
  nodegroup="$nodegroup
$NODE-$c openshift_node_labels=\"{'region': 'app', 'zone': 'default'}\" openshift_hostname=$NODE-$c"
done

# Create CNS nodes grouping if CNS is enabled
if [ $ENABLECNS == "true" ]
then
echo $(date) " - Creating CNS nodes grouping"

for (( c=0; c<$CNSCOUNT; c++ ))
do
  cnsgroup="$cnsgroup
$CNS-$c openshift_node_labels=\"{'region': 'app', 'zone': 'default'}\" openshift_hostname=$CNS-$c"
done
fi

# Create playbook to update ansible.cfg file

cat > updateansiblecfg.yaml <<EOF
#!/usr/bin/ansible-playbook

- hosts: localhost
  become: yes
  gather_facts: no
  tasks:
  - lineinfile:
      dest: /etc/ansible/ansible.cfg
      regexp: '^library '
      insertafter: '#library        = /usr/share/my_modules/'
      line: 'library = /home/${SUDOUSER}/openshift-ansible/library/'
EOF

# Run Ansible Playbook to update ansible.cfg file

echo $(date) " - Updating ansible.cfg file"

ansible-playbook ./updateansiblecfg.yaml

# Create Ansible Playbooks for Post Installation tasks
echo $(date) " - Create Ansible Playbooks for Post Installation tasks"

# Create Ansible Hosts File
echo $(date) " - Create Ansible Hosts file"

cat > /etc/ansible/hosts <<EOF
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes
etcd
master0
glusterfs
new_nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=$SUDOUSER
ansible_become=yes
openshift_install_examples=true
openshift_deployment_type=origin
openshift_release=v3.9
docker_udev_workaround=True
openshift_use_dnsmasq=True
openshift_master_default_subdomain=$ROUTING
openshift_override_hostname_check=true
osm_use_cockpit=false
os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'
openshift_master_api_port=443
openshift_master_console_port=443
#openshift_cloudprovider_kind=azure
osm_default_node_selector='region=app'
openshift_disable_check=disk_availability,memory_availability,docker_image_availability

# default selectors for router and registry services
$registrygluster
openshift_router_selector='region=infra'
openshift_registry_selector='region=infra'

# Deploy Service Catalog
openshift_enable_service_catalog=false

openshift_master_cluster_method=native
openshift_master_cluster_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_vip=$MASTERPUBLICIPADDRESS

# Enable HTPasswdPasswordIdentityProvider
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

# Disable the OpenShift SDN plugin
openshift_use_openshift_sdn=true

# Setup metrics
openshift_metrics_install_metrics=false
#openshift_metrics_cassandra_storage_type=dynamic
openshift_metrics_start_cluster=true
openshift_metrics_startup_timeout=120
openshift_metrics_hawkular_nodeselector={"region":"infra"}
openshift_metrics_cassandra_nodeselector={"region":"infra"}
openshift_metrics_heapster_nodeselector={"region":"infra"}
openshift_hosted_metrics_public_url=https://metrics.$ROUTING/hawkular/metrics

# Setup logging
openshift_logging_install_logging=false
#openshift_logging_es_pvc_dynamic=true
openshift_logging_es_pvc_storage_class_name=generic
openshift_logging_fluentd_nodeselector={"logging":"true"}
openshift_logging_es_nodeselector={"region":"infra"}
openshift_logging_kibana_nodeselector={"region":"infra"}
openshift_logging_curator_nodeselector={"region":"infra"}
openshift_master_logging_public_url=https://kibana.$ROUTING
openshift_logging_master_public_url=https://$MASTERPUBLICIPHOSTNAME:443

# host group for masters
[masters]
$MASTER-[0:${MASTERLOOP}]

# host group for etcd
[etcd]
$MASTER-[0:${MASTERLOOP}]

[master0]
$MASTER-0

[glusterfs]
$cnsglusterinfo

# host group for nodes
[nodes]
$mastergroup
$infragroup
$nodegroup
$cnsgroup

[new_nodes]
EOF

echo $(date) " - Cloning openshift-ansible repo for use in installation"

runuser -l $SUDOUSER -c "git clone -b release-3.9 https://github.com/openshift/openshift-ansible /home/$SUDOUSER/openshift-ansible"

echo $(date) " - Running network_manager.yml playbook"
DOMAIN=`domainname -d`

# Setup NetworkManager to manage eth0
runuser -l $SUDOUSER -c "ansible-playbook /home/$SUDOUSER/openshift-ansible/playbooks/openshift-node/network_manager.yml"

echo $(date) " - Setting up NetworkManager on eth0"
# Configure resolv.conf on all hosts through NetworkManager

runuser -l $SUDOUSER -c "ansible all -b -m service -a \"name=NetworkManager state=restarted\""

# Initiating installation of OpenShift Container Platform prerequisites using Ansible Playbook
echo $(date) " - Running Prerequisites via Ansible Playbook"
runuser -l $SUDOUSER -c "ansible-playbook -f 10 /home/$SUDOUSER/openshift-ansible/playbooks/prerequisites.yml"

# Initiating installation of OpenShift Container Platform using Ansible Playbook
echo $(date) " - Installing OpenShift Container Platform via Ansible Playbook"

runuser -l $SUDOUSER -c "ansible-playbook -f 10 /home/$SUDOUSER/openshift-ansible/playbooks/deploy_cluster.yml"

echo $(date) " - Modifying sudoers"

sed -i -e "s/Defaults    requiretty/# Defaults    requiretty/" /etc/sudoers
sed -i -e '/Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"/aDefaults    env_keep += "PATH"' /etc/sudoers

echo $(date) "- Re-enabling requiretty"

sed -i -e "s/# Defaults    requiretty/Defaults    requiretty/" /etc/sudoers

# Adding user to OpenShift authentication file
echo $(date) "- Adding OpenShift user"

runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/addocpuser.yaml"

# Assigning cluster admin rights to OpenShift user
echo $(date) "- Assigning cluster admin rights to user"

runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/assignclusteradminrights.yaml"

# Configure Docker Registry to use Azure Storage Account
# echo $(date) "- Configuring Docker Registry to use Azure Storage Account"

# runuser $SUDOUSER -c "ansible-playbook ~/dockerregistry.yml"

if [[ $AZURE == "true" ]]
then

	# Create Storage Classes
	echo $(date) "- Creating Storage Classes"

	runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/configurestorageclass.yaml"

	echo $(date) "- Sleep for 120"

	sleep 120

	# Execute setup-azure-master and setup-azure-node playbooks to configure Azure Cloud Provider
	echo $(date) "- Configuring OpenShift Cloud Provider to be Azure"

	runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/setup-azure-master-origin.yaml"

	if [ $? -eq 0 ]
	then
	   echo $(date) " - Cloud Provider setup of master config on Master Nodes completed successfully"
	else
	   echo $(date) "- Cloud Provider setup of master config on Master Nodes failed to completed"
	   exit 7
	fi
	
	echo $(date) "- Sleep for 60"
	
	sleep 60
	runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/setup-azure-node-master-origin.yaml"

	if [ $? -eq 0 ]
	then
	   echo $(date) " - Cloud Provider setup of node config on Master Nodes completed successfully"
	else
	   echo $(date) "- Cloud Provider setup of node config on Master Nodes failed to completed"
	   exit 8
	fi
	
	echo $(date) "- Sleep for 60"
	
	sleep 60
	runuser $SUDOUSER -c "ansible-playbook -f 10 ~/openshift-container-platform-playbooks/setup-azure-node-origin.yaml"

	if [ $? -eq 0 ]
	then
	   echo $(date) " - Cloud Provider setup of node config on App Nodes completed successfully"
	else
	   echo $(date) "- Cloud Provider setup of node config on App Nodes failed to completed"
	   exit 9
	fi
	
	echo $(date) "- Sleep for 120"
	
	sleep 120
	runuser $SUDOUSER -c "ansible-playbook ~/masternonschedulable.yml"

	if [ $? -eq 0 ]
	then
	   echo $(date) " - Cloud Provider setup of OpenShift Cluster completed successfully"
	else
	   echo $(date) "- Cloud Provider setup failed to delete stuck Master nodes or was not able to set them as unschedulable"
	   exit 10
	fi

	echo $(date) "- Restarting OVS to complete installation"
	
	echo $(date) "- Sleep for 20"
	
	sleep 20

	runuser -l $SUDOUSER -c  "oc label nodes $MASTER-0 openshift-infra=apiserver --overwrite=true"	
	runuser -l $SUDOUSER -c  "oc label nodes --all logging-infra-fluentd=true logging=true"

	runuser -l $SUDOUSER -c  "ansible all -b  -m service -a 'name=openvswitch state=restarted' "

	echo $(date) "- Restarting origin nodes after 20 seconds"
	sleep 20

	runuser -l $SUDOUSER -c  "ansible nodes -b  -m service -a 'name=origin-node state=restarted' "
	sleep 10
	runuser -l $SUDOUSER -c "oc rollout latest dc/asb -n openshift-ansible-service-broker"
	runuser -l $SUDOUSER -c "oc rollout latest dc/asb-etcd -n openshift-ansible-service-broker"

fi


# Reconfigure glusterfs storage class

if [ $ENABLECNS == "true" ]
then
	echo $(date) "- Create default glusterfs storage class"
	cat > /home/$SUDOUSER/default-glusterfs-storage.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: default-glusterfs-storage
parameters:
  resturl: http://heketi-storage-glusterfs.${ROUTING}
  restuser: admin
  secretName: heketi-storage-admin-secret
  secretNamespace: glusterfs
provisioner: kubernetes.io/glusterfs
reclaimPolicy: Delete
EOF

	runuser -l $SUDOUSER -c "oc create -f /home/$SUDOUSER/default-glusterfs-storage.yaml"
	sleep 10
	
	# Installing Service Catalog, Ansible Service Broker and Template Service Broker
	
	echo $(date) "- Installing Service Catalog, Ansible Service Broker and Template Service Broker"
	runuser -l $SUDOUSER -c "ansible-playbook /home/$SUDOUSER/openshift-ansible/playbooks/openshift-service-catalog/config.yml"
	
fi

# Configure Metrics

if [ $METRICS == "true" ]
then
	sleep 30	
	echo $(date) "- Determining Origin version from rpm"
	OO_VERSION="v"$(rpm -q origin | cut -d'-' -f 2 | head -c 3)	
	echo $(date) "- Deploying Metrics"
	if [ $ENABLECNS == "true" ]
	then
		runuser -l $SUDOUSER -c "ansible-playbook /home/$SUDOUSER/openshift-ansible/playbooks/openshift-metrics/config.yml -e openshift_metrics_install_metrics=True -e openshift_metrics_cassandra_storage_type=dynamic -e openshift_hosted_metrics_deployer_version=$OO_VERSION"
	else
		runuser -l $SUDOUSER -c "ansible-playbook /home/$SUDOUSER/openshift-ansible/playbooks/openshift-metrics/config.yml -e openshift_metrics_install_metrics=True -e openshift_hosted_metrics_deployer_version=$OO_VERSION"
	fi
	if [ $? -eq 0 ]
	then
	   echo $(date) " - Metrics configuration completed successfully"
	else
	   echo $(date) "- Metrics configuration failed"
	   exit 11
	fi
fi

# Configure Logging

if [ $LOGGING == "true" ] 
then
	sleep 60
	echo $(date) "- Deploying Logging"
	if [ $ENABLECNS == "true" ]
	then
		runuser -l $SUDOUSER -c "ansible-playbook /home/$SUDOUSER/openshift-ansible/playbooks/openshift-logging/config.yml -e openshift_logging_install_logging=True -e openshift_logging_es_pvc_dynamic=true -e openshift_master_dynamic_provisioning_enabled=True"
	else
		runuser -l $SUDOUSER -c "ansible-playbook /home/$SUDOUSER/openshift-ansible/playbooks/openshift-logging/config.yml -e openshift_logging_install_logging=True"
	fi
	if [ $? -eq 0 ]
	then
	   echo $(date) " - Logging configuration completed successfully"
	else
	   echo $(date) "- Logging configuration failed"
	   exit 12
	fi
fi

# Delete yaml files
echo $(date) "- Deleting unecessary files"

rm -rf /home/${SUDOUSER}/openshift-container-platform-playbooks

echo $(date) "- Sleep for 30"

sleep 30

echo $(date) " - Script complete"