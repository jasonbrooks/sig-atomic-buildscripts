#!/bin/bash
if [ -e Vagrantfile ]; then rm Vagrantfile ; fi
vagrant box add --name centos/7  /srv/images/centos-atomic-host-7-vagrant-libvirt.box
cd ..
git clone https://github.com/jasonbrooks/contrib.git
cd contrib/ansible/vagrant
vagrant up --no-provision --provider=libvirt
vagrant provision kube-master
vagrant ssh kube-master -c "sudo docker pull projectatomic/redis-centos7-atomicapp"
sleep 2m
vagrant ssh kube-master -c "sudo -E atomic run projectatomic/guestbookgo-atomicapp"
sleep 15m
SVC_IP=$(vagrant ssh kube-master -c "kubectl get svc guestbook --no-headers | cut -d' ' -f4" | sed 's/\r$//'); vagrant ssh kube-node-1 -c "curl http://$SVC_IP:3000/info" | grep "connected_clients"
if [ $? -ne 0 ]; then
  echo 'XX: FAIL: guestbook app not running'
  exit 1
fi
exit 0

