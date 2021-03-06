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

cd ${BuildDir}

systemctl start docker
systemctl start libvirtd

## increase memory for imagefactory vm to 3GB

sed -i '/memory/c\memory = 3072' /etc/oz/oz.cfg

## This part creates an install tree and install iso 

echo '---------- installer ' >> ${LogFile}
rpm-ostree-toolbox installer --overwrite --ostreerepo ${BuildDir}/repo -c  ${GitDir}/config.ini -o ${BuildDir}/installer |& tee ${LogFile}

# we likely need to push the installer content to somewhere the following kickstart
#  can pick the content from ( does it otherwise work with a file:/// url ? unlikely )
python -m SimpleHTTPServer 8000 &

echo '---------- Vagrant ' >> ${LogFile}
rpm-ostree-toolbox imagefactory --overwrite --tdl ${GitDir}/atomic-7.1.tdl -c  ${GitDir}/config.ini -i kvm -i vagrant-libvirt -i vagrant-virtualbox -k ${GitDir}/centos-atomic.ks --vkickstart ${GitDir}/centos-atomic-vagrant.ks -o ${BuildDir}/virt |& tee ${LogFile}


## Make a place to copy finished images

mkdir -p ${BuildDir}/images/
cp -r ${BuildDir}/virt/images/* ${BuildDir}/images/
cp ${BuildDir}/installer/images/images/installer.iso ${BuildDir}/images/centos-atomic-host-7.iso
rm -rf ${BuildDir}/virt

echo '---------- liveimage ' >> ${LogFile}
rpm-ostree-toolbox liveimage -c  ${GitDir}/config.ini --preserve-ks-url --tdl ${GitDir}/atomic-7.1.tdl -k ${GitDir}/pxelive.ks -o ${BuildDir}/pxelive --overwrite |& tee ${LogFile}

echo '----------' >> ${LogFile}

#/bin/rsync -PHvar ${BuildDir} pushhost::c7-atomic/x86_64/Builds/ >> ${LogFile}  2>&1

## kill the last background job, to shut off the python simpleserver
kill $!


