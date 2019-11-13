#!/bin/bash

USER=chenzj
FQDN=javachen.com

#安装docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum install docker-ce -y

systemctl enable docker && systemctl start docker

cat > /etc/docker/daemon.json <<EOF
{
    "oom-score-adjust": -1000,
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m",
      "max-file": "3"
    },
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 10,
    "bip": "172.17.10.1/24",
    "registry-mirrors": ["https://hub.daocloud.io/"],
    "insecure-registries":["https://harbor.${FQDN}"],
    "graph":"/data/docker",
    "exec-opts": ["native.cgroupdriver=systemd"],
    "storage-driver": "overlay2",
    "storage-opts": [
      "overlay2.override_kernel_check=true"
    ]
}
EOF
sed -i '/containerd.sock.*/ s/$/ -H tcp:\/\/0.0.0.0:2375 -H unix:\/\/var\/run\/docker.sock /' /usr/lib/systemd/system/docker.service
systemctl daemon-reload && systemctl restart docker

#安装k8s
curl -s -L -o /usr/local/bin/rke https://github.com/rancher/rke/releases/download/v0.3.2/rke_linux-amd64
chmod 777 /usr/local/bin/rke

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
  http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum install kubectl -y

useradd -G docker $USER
echo $USER|passwd $USER --stdin >/dev/null 2>&1
echo "$USER ALL=(ALL) ALL" >> /etc/sudoers
sudo -u $USER ssh-keygen -f /home/$USER/.ssh/id_rsa -t rsa -N ""
sudo -u $USER ./ssh_nopassword.expect $(hostname) $USER $USER
chown $USER:docker /var/run/docker.sock


# $USER 用户安装k8s集群
su - $USER
mkdir -p install/k8s && cd install/k8s
cat > cluster.yml <<EOF
nodes:
  - address: 192.168.56.111
    user: $USER
    role: [controlplane,etcd,worker]

services:
  etcd:
    snapshot: true
    creation: 6h
    retention: 24h
  kube-api:
    service_cluster_ip_range: 10.43.0.0/16
    service_node_port_range: 30000-32767
  kubelet:
    cluster_domain: cluster.local
    cluster_dns_server: 10.43.0.10
    fail_swap_on: false
    extra_args:
      max-pods: 100

cluster_name: k8s-test
kubernetes_version: "v1.16.2-rancher1-1"
network:
    plugin: calico
EOF

rke up --config cluster.yml

mkdir ~/.kube/
cp kube_config_cluster.yml ~/.kube/config

echo "Configure Kubectl to autocomplete"
source <(kubectl completion bash) #
echo 'source <(kubectl completion bash)' >> ~/.bashrc
