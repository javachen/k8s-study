#!/bin/bash


# 升级内核到4.44
sudo rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
sudo yum --enablerepo=elrepo-kernel install -y kernel-lt
sudo awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
sudo grub2-set-default 0
sudo sed -i 's/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/g' /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg


cd ceph-cluster
#初始化mon
ceph-deploy mon create-initial

reboot


#创建osd
sudo mkfs.xfs -f -i size=2048 /dev/sdb
ceph-deploy disk zap k8s-rke-node001 /dev/sdb
ceph-deploy osd create --data /dev/sdb k8s-rke-node001

#部署mgr
ceph-deploy mgr create k8s-rke-node001

#创建ceph cli
ceph-deploy admin k8s-rke-node001
sudo chmod +r /etc/ceph/ceph.client.admin.keyring

#安装mgr-dashboard
yum install -y ceph-mgr-dashboard
ceph mgr module enable dashboard --force
ceph dashboard create-self-signed-cert
ceph dashboard ac-user-create admin admin administrator
ceph mgr services
curl -k https://0.0.0.0:8443

#查看状态
ceph health
ceph -s
ceph osd tree
