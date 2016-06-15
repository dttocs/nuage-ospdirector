#!/bin/bash
#
# This script is used to patch an existing OpenStack
# image with Nuage components
#
# This script takes in following input parameters:
# RhelUserName: User name for the RHEL subscription
# RhelPassword: Password for the RHEL subscription
# RhelPool    : RHEL Pool to subscribe
# RepoName    : Name of the local repository
# RepoBaseUrl : Base URL of the local repository
# Version     : Version of OSP Director (7 or 8)
#
# The following sequence is executed by the script
# 1. Subscribe to RHEL and the pool
# 2. Uninstall OVS
# 3. Create the local repo file for Nuage packages
# 4. Install neutron-client, netlib, metadata agent
# 5. Install VRS
# 6. Unsubscribe from RHEL
# 7. Add the files post-patching
#
#

### List of Nuage packages
NUAGE_PACKAGES="nuage-openstack-neutron nuagenetlib nuage-openstack-neutronclient nuage-metadata-agent nuage-puppet-modules nuage-openstack-heat nuage-openstack-horizon"
NUAGE_DEPENDENCIES="libvirt python-twisted-core perl-JSON qemu-kvm vconfig python-novaclient"
NUAGE_VRS_PACKAGE="nuage-openvswitch"
VIRT_CUSTOMIZE_MEMSIZE="2048"


###
CONTINUE_SCRIPT=true

#####
# Function to print help message
#####

function show_help {

echo "Options are"
echo " --ImageName= Name of the qcow2 image (overcloud-full.qcow2 for example)"
echo " --RhelUserName=User name for RHELSubscription"
echo " --RhelPassword=Password for the RHEL Subscription"
echo " --RhelPool=Pool to subscribe to for base packages"
echo " --RepoName=Name for the local repo hosting the Nuage RPMs"
echo " --RepoBaseUrl=Base URL for the repo hosting the Nuage RPMs"
echo " --Version=OSP-Director version (7 or 8)?"
echo " -h or --help: Show this message"
}

#####
# Function to add RHEL subscription using guestfish
#####

function rhel_subscription {

cat <<EOT >> rhel_subscription
subscription-manager register --username=$1 --password='$2'
subscription-manager subscribe --pool=$3
subscription-manager repos --enable=rhel-7-server-optional-rpms
subscription-manager repos --enable=rhel-7-server-rpms
EOT
virt-customize --run rhel_subscription -a $4 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

rm -f rhel_subscription

}

#####
# Function to add files based on the version
#####

function add_files {

if [ $2 -eq 7 ]; then

  virt-customize --run-command 'mkdir -p /etc/puppet/modules/nuage/manifests/7_files' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

  virt-copy-in -a $1 7_files/neutron_plugin_nuage.rb /etc/puppet/modules/nuage/manifests/7_files
  virt-copy-in -a $1 7_files/impl_ifcfg.py /etc/puppet/modules/nuage/manifests/7_files
  virt-copy-in -a $1 7_files/ini_setting.rb /etc/puppet/modules/nuage/manifests/7_files
  
  virt-customize --run-command 'cp /etc/puppet/modules/nuage/manifests/7_files/neutron_plugin_nuage.rb /etc/puppet/modules/neutron/lib/puppet/type/neutron_plugin_nuage.rb' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'
  virt-customize --run-command 'cp /etc/puppet/modules/nuage/manifests/7_files/ini_setting.rb /etc/puppet/modules/neutron/lib/puppet/provider/neutron_plugin_nuage/ini_setting.rb' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'
  virt-customize --run-command 'cp /etc/puppet/modules/nuage/manifests/7_files/impl_ifcfg.py /usr/lib/python2.7/site-packages/os_net_config/impl_ifcfg.py' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

fi

if [ $2 -eq 8 ]; then

  virt-customize --run-command 'mkdir -p /etc/puppet/modules/nuage/manifests/8_files' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

  virt-copy-in -a $1 8_files/neutron_plugin_nuage.rb /etc/puppet/modules/nuage/manifests/8_files
  virt-copy-in -a $1 8_files/nuage.pp /etc/puppet/modules/nuage/manifests/8_files
  virt-copy-in -a $1 8_files/vrs.pp /etc/puppet/modules/nuage/manifests/8_files

  virt-customize --run-command 'cp /etc/puppet/modules/nuage/manifests/8_files/neutron_plugin_nuage.rb /etc/puppet/modules/neutron/lib/puppet/type/neutron_plugin_nuage.rb' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'
  virt-customize --run-command 'cp /etc/puppet/modules/nuage/manifests/8_files/nuage.pp /etc/puppet/modules/neutron/manifests/plugins/nuage.pp' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'
  virt-customize --run-command 'cp /etc/puppet/modules/nuage/manifests/8_files/vrs.pp /etc/puppet/modules/nuage/manifests/vrs.pp' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

fi

}


#####
# Function to remove the RHEL subscription
#####

function rhel_remove_subscription {

cat <<EOT >> rhel_unsubscribe
subscription-manager unregister
EOT

virt-customize --run rhel_unsubscribe -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

rm -f rhel_unsubscribe
}


#####
# Function to remove packages that are not needed
#####

function uninstall_packages {
virt-customize --run-command 'yum remove python-openvswitch -y' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'
virt-customize --run-command 'yum remove openvswitch -y' -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

}


#####
# Function to install Nuage packages that are required
#####

function install_packages {

cat <<EOT >> nuage_packages
yum install $NUAGE_DEPENDENCIES -y
yum install $NUAGE_PACKAGES -y
EOT

virt-customize --run nuage_packages -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

rm -f nuage_packages
}

#####
# Installing VRS and the dependencies for VRS
#####

function install_vrs {

cat <<EOT >> vrs_packages
yum install $NUAGE_VRS_PACKAGE -y
EOT

virt-customize --run vrs_packages -a $1 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

rm -f vrs_packages

}




#####
# Function to create the repo file
#####

function create_repo_file {

cat <<EOT >> create_repo
touch /etc/yum.repos.d/nuage.repo
echo "[Nuage]" >> /etc/yum.repos.d/nuage.repo
echo "name=$1" >> /etc/yum.repos.d/nuage.repo
echo "baseurl=$2" >> /etc/yum.repos.d/nuage.repo
echo "enabled = 1" >> /etc/yum.repos.d/nuage.repo
echo "gpgcheck = 0" >> /etc/yum.repos.d/nuage.repo

EOT

virt-customize --run create_repo -a $3 --memsize $VIRT_CUSTOMIZE_MEMSIZE --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'

}


#####
# Function to clean up the repo file
#####
function delete_repo_file {

virt-customize --run-command "rm -f /etc/yum.repos.d/nuage.repo" -a $1 --selinux-relabel --edit '/usr/lib/systemd/system/rhel-autorelabel.service: $_ = "" if /StandardInput=tty/'
rm -f create_repo 
}

if [ $# -lt 7 ]; then
  CONTINUE_SCRIPT=false
  show_help
fi

for i in "$@"
do
case $i in
    --ImageName=*)
    ImageName="${i#*=}"
    ;;
    --RhelUserName=*)
    RhelUserName="${i#*=}"
    ;;
    --RhelPassword=*)
    RhelPassword="${i#*=}"
    ;;
    --RhelPool=*)
    RhelPool="${i#*=}"
    ;;
    --RepoName=*)
    RepoName="${i#*=}"
    ;;
    --RepoBaseUrl=*)
    RepoBaseUrl="${i#*=}"
    ;;
    --Version=*)
    Version="${i#*=}"
    ;;
    -h|--help)
    show_help
    CONTINUE_SCRIPT=false
    return
    ;;
    *)
    echo "unknown option"
    show_help        # unknown option
    CONTINUE_SCRIPT=false
    return
    ;;
esac
done


if [ "$CONTINUE_SCRIPT" = true ]; then
    echo "Creating the RHEL subscription"

    rhel_subscription $RhelUserName $RhelPassword $RhelPool $ImageName

    echo "Uninstalling packages"

    uninstall_packages $ImageName

    echo "Creating Repo File"

    create_repo_file $RepoName $RepoBaseUrl $ImageName

    echo "Installing Nuage Packages"

    install_packages $ImageName

    echo "Installing VRS"

    install_vrs $ImageName

    echo "Cleaning up"

    delete_repo_file $ImageName

    rhel_remove_subscription $ImageName

    echo "Adding files post-patching"

    add_files $ImageName $Version

    echo "Done"

fi


