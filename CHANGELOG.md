This CHANGELOG.md file will contain the update log for the latest set of updates to the templates

# UPDATES for Origin 3.9 - May 18, 2018

1.  Adjust prep scripts and deployOpenShift script to correct NetworkManager configuration.


# UPDATES for Origin 3.9 - May 5, 2018

1.  Support configuration for 1 Master as well as 1 Infra
2.  Include playbook to test for DNS name resolution - accomodate for Azure network latency during deployment


# UPDATES for Origin 3.9 - April 28, 2018

1.  Update to deploy Origin 3.9.
2.  Deploy ASB after cluster standup.
3.  Extract playbook creation out of deployOpenShift.sh.
4.  Tighten up creation of hosts file.


# UPDATES for Origin 3.7 - February 19, 2018

1.  Add additional label to infra nodes to address TSB install.
2.  Include commands to address ASB issue after Azure Cloud Provider setup.
3.  Remove reference to Cockpit.


# UPDATES for Origin 3.7 - January 16, 2018

1.  Add support for managed and unmanaged disks.
2.  Update Azure Cloud Provider setup playbooks and configuration.
3.  Provide option to enable metrics, logging, Cockpit and Azure Cloud Provider.
4.  Include additional data disk sizes.
5.  Implement diagnostics logs for VMs.
6.  General cleanup.


# UPDATE - December 21, 2017

1.  Created branch for release-3.6.
2.  Updated git clone to branch release-3.6.


# UPDATES for Release 3.6 - September 15, 2017

1.  Removed option to select between CentOS and RHEL.  This template uses CentOS.  This can be changed by forking the repo and changing the variable named osImage in azuredeploy.json
# UPDATES for Azure Stack Release 3.9 - April 18, 2018

1.  Create Azure Stack Release 3.9 Branch
2.  Option to enable Cloud Native Storage (CNS)
3.  With CNS, 3 additional nodes will deploy with 3 128 GB data disks
4.  Deploy Service Catalog, Ansible Service Broker and Template Service Broker if CNS is enabled
5.  Registry will use Gluster if CNS is enabled; otherwise, it will use ephemeral storage

