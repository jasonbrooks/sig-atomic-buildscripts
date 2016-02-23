#!/bin/bash

VERSION=7.$( date  +%Y%m%d )

DateStamp=$( date  +%Y%m%d_%H%M%S )
BuildDir=$1
LogFile=${BuildDir}/log
mkdir -p ${BuildDir}
# Make it absolute
BuildDir=$(cd $BuildDir && pwd)
GitDir=${BuildDir}/sig-atomic-buildscripts
OstreeRepoDir=/srv/repo && mkdir -p $OstreeRepoDir
ln -s ${OstreeRepoDir} ${BuildDir}/repo

set -x
set -e
set -o pipefail

pwd
cd ${BuildDir}

# Init, make sure we have the bits we need installed. 
cp -f /root/sig-atomic/buildscripts/rhel-atomic-rebuild.repo /etc/yum.repos.d/
yum -y install ostree rpm-ostree docker libvirt epel-release

cp -f /root/sig-atomic-buildscripts/atomic7-testing.repo /etc/yum.repos.d/
echo 'enabled=0' >> /etc/yum.repos.d/atomic7-testing.repo
yum --enablerepo=atomic7-testing -y install rpm-ostree-toolbox


## create repo in BuildDir, this will fail w/o issue if already exists

if ! test -d ${BuildDir}/repo/objects; then
    ostree --repo=${BuildDir}/repo init --mode=archive-z2
fi

# sync repo from ds location

ostree remote add --repo=/srv/repo centos-atomic-host --set=gpg-verify=false https://ci.centos.org/artifacts/sig-atomic/downstream/repo && ostree pull --repo=/srv/repo --mirror centos-atomic-host centos-atomic-host/7/x86_64/standard


systemctl start docker
systemctl start libvirtd




## This part creates an install tree and install iso 

#echo '---------- installer ' >> ${LogFile}
#rpm-ostree-toolbox installer --overwrite --ostreerepo ${BuildDir}/repo -c  ${GitDir}/config.ini -o ${BuildDir}/installer |& tee ${LogFile}

# we likely need to push the installer content to somewhere the following kickstart
#  can pick the content from ( does it otherwise work with a file:/// url ? unlikely )
#python -m SimpleHTTPServer 8000 &

echo '---------- Vagrant ' >> ${LogFile}
rpm-ostree-toolbox imagefactory --overwrite --tdl ${GitDir}/atomic-7.1.tdl -c  ${GitDir}/config.ini -i kvm -i vagrant-libvirt -i vagrant-virtualbox -k ${GitDir}/atomic-7.1-cloud.ks --vkickstart ${GitDir}/atomic-7.1-vagrant.ks -o ${BuildDir}/virt |& tee ${LogFile}


## Make a place to copy finished images

mkdir -p ${BuildDir}/images/
cp -r ${BuildDir}/virt/images/* ${BuildDir}/images/
cp ${BuildDir}/installer/images/images/installer.iso ${BuildDir}/images/centos-atomic-host-7.iso
rm -rf ${BuildDir}/virt

# TODO we need a liveimage ks for this part

#echo '---------- liveimage ' >> ${LogFile}
#rpm-ostree-toolbox liveimage -c  ${GitDir}/config.ini -o pxe-to-live >> ${LogFile} 2>&1
#echo '----------' >> ${LogFile}

#/bin/rsync -PHvar ${BuildDir} pushhost::c7-atomic/x86_64/Builds/ >> ${LogFile}  2>&1

## kill the last background job, to shut off the python simpleserver
kill $!


