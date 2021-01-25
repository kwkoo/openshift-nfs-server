#!/bin/bash

cd $(dirname $0)
BASE=$(pwd)
cd - >> /dev/null

which oc 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
    echo "oc binary not in path"
    exit 1
fi

oc get storageclass/managed-nfs-storage &> /dev/null
if [ $? -eq 0 ]; then
    echo "managed-nfs-storage storageclass exists - removing it"
    oc delete storageclass/managed-nfs-storage
fi

echo "setting remaining storage classes to non-default"
for  sc in $(oc get storageclass -o name); do
    oc patch $sc -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
done

echo "importing new managed-nfs-storage storageclass"
oc create -f ${BASE}/../yaml/nfs-subdir-external-provisioner/class.yaml
