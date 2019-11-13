#!/bin/bash


kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

