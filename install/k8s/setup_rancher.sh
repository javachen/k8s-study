#!/bin/bash

FQDN=javachen.com

#安装helm
curl -s https://get.helm.sh/helm-v3.0.0-rc.1-linux-amd64.tar.gz|tar zxvf -
mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64

helm version

# 创建证书
sudo curl -s -L -o /usr/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
sudo curl -s -L -o /usr/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
sudo curl -s -L -o /usr/bin/cfssl-certinfo https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
sudo chmod +x /usr/bin/cfssl*

mkdir cert && cd cert
cat << EOF > ca-config.json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "javachen-com": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
cat << EOF > ca-csr.json
{
  "CN": "ca-com",
  "key": {
      "algo": "rsa",
      "size": 2048
  },
  "names": [
  {
          "C": "CN",
          "ST": "HuBei",
          "L": "WuHan",
          "O": "${FQDN}",
          "OU": "devops"
    }]
}
EOF

cat << EOF > server-csr.json
{
    "CN": "${FQDN}",
    "hosts": [
        "127.0.0.1",
        "*.${FQDN}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "HuBei",
            "L": "WuHan",
            "O": "${FQDN}",
            "OU": "devops"
        }
    ]
}
EOF
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem --config=ca-config.json -profile=javachen-com server-csr.json | cfssljson -bare server


#安装rancher
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# 创建命名空间
kubectl create namespace cattle-system
cp server.pem tls.crt
cp server-key.pem tls.key
cp ca.pem cacerts.pem
# 服务证书和私钥密文
kubectl -n cattle-system create  secret tls tls-rancher-ingress --cert=./tls.crt --key=./tls.key
# ca证书密文
kubectl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem

helm install rancher rancher-latest/rancher \
  --version v2.3.2  \
  --namespace cattle-system \
  --set hostname=rancher.javachen.com\
  --set ingress.tls.source=secret \
  --set privateCA=true

kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher

kubectl -n cattle-system patch deployments cattle-cluster-agent --patch '{
 "spec": {
  "template": {
  "spec": {
       "hostAliases": [
          {
            "hostnames":[ "rancher.javachen.com"],
            "ip": "192.168.56.111"
          }
       ]
    }
   }
   }
}'

kubectl -n cattle-system patch daemonsets cattle-node-agent --patch '{
 "spec": {
  "template": {
  "spec": {
       "hostAliases": [
          {
            "hostnames":[ "rancher.javachen.com"],
            "ip": "192.168.56.111"
          }
      ]
    }
   }
   }
}'