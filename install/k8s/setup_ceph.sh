#!/bin/bash

cat << EOF >> ~/.ssh/config
Host      k8s-rke-node001
Hostname  k8s-rke-node001
User      chenzj
EOF

chmod 644 ~/.ssh/config

sudo cat << EOF >> /etc/yum.repos.d/ceph.repo
[Ceph]
name=Ceph packages for x86_64
baseurl=http://mirrors.163.com/ceph/rpm-nautilus/el7/x86_64
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://mirrors.163.com/ceph/keys/release.asc
priority=1

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://mirrors.163.com/ceph/rpm-nautilus/el7/noarch
enabled=1
gpgcheck=0
type=rpm-md
gpgkey=https://mirrors.163.com/ceph/keys/release.asc
priority=1
EOF

export CEPH_DEPLOY_REPO_URL=https://mirrors.163.com/ceph/rpm-nautilus/el7
export CEPH_DEPLOY_GPG_URL=http://mirrors.163.com/ceph/keys/release.asc

sudo modprobe rbd

sudo yum install ceph-deploy python-pip python-pkg-resources python-setuptools -y

# 创建集群配置目录
mkdir ceph-cluster && cd ceph-cluster

# 创建 monitor-node
ceph-deploy new k8s-rke-node001\
  --public-network 192.168.56.0/24 \
  --cluster-network 192.168.56.0/24

echo "
osd_pool_default_size = 3

[mon]
mon_allow_pool_delete = true
mon_max_pg_per_osd = 1024
" >> ceph.conf

# 安装 ceph
sudo rpm --import http://mirrors.163.com/ceph/keys/release.asc
ceph-deploy install --repo-url http://mirrors.163.com/ceph/rpm-nautilus/el7 \
  k8s-rke-node001

