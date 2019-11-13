#!/bin/bash

FQDN=javachen.com

ceph osd pool create k8s 256

cat << EOF >> ceph-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ceph-admin-secret
type: "kubernetes.io/rbd"
data:
  key: $(grep key /etc/ceph/ceph.client.admin.keyring |awk '{printf "%s", $NF}'|base64)
EOF

kubectl create -f ceph-secret.yaml

cat << EOF >> ceph-rbd-sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: kubernetes.io/rbd
parameters:
   monitors: 192.168.56.111:6789
   adminId: admin
   adminSecretName: ceph-admin-secret
   adminSecretNamespace: default
   pool: k8s
   userId: admin
   userSecretName: ceph-admin-secret
   userSecretNamespace: default
EOF

kubectl create -f ceph-rbd-sc.yaml
kubectl patch storageclass ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

#helm安装Harbor
helm repo add harbor https://helm.goharbor.io
kubectl create namespace devops
kubectl create secret tls harbor-secret-tls -n devops --cert=tls.crt  --key=tls.key

helm install harbor harbor/harbor --namespace devops --debug\
  --set externalURL=https://harbor.${FQDN}  \
  --set expose.tls.secretName="harbor-secret-tls" \
  --set expose.ingress.hosts.core=harbor.${FQDN} \
  --set expose.ingress.hosts.notary=harbor.${FQDN} \
  --set persistence.persistentVolumeClaim.registry.storageClass=ceph-rbd \
  --set persistence.persistentVolumeClaim.registry.size=50Gi \
  --set persistence.persistentVolumeClaim.chartmuseum.storageClass=ceph-rbd \
  --set persistence.persistentVolumeClaim.jobservice.storageClass=ceph-rbd \
  --set persistence.persistentVolumeClaim.database.storageClass=ceph-rbd \
  --set persistence.persistentVolumeClaim.database.size=5Gi \
  --set persistence.persistentVolumeClaim.redis.storageClass=ceph-rbd \
  --set harborAdminPassword=admin123

mkdir -p /etc/docker/certs.d/harbor.${FQDN}
kubectl get secret -n devops harbor-secret-tls \
    -o jsonpath="{.data.ca\.crt}" | base64 --decode | \
    sudo tee /etc/docker/certs.d/harbor.${FQDN}/ca.crt
