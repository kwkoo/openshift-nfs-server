#!/bin/bash

cd $(dirname $0)
BASE=$(pwd)
cd - >> /dev/null

which oc 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
    echo "oc binary not in path"
    exit 1
fi

oc get storageclass/manual &> /dev/null
if [ $? -eq 0 ]; then
    echo "manual storageclass exists - removing it"
    oc delete storageclass/manual
fi

echo "setting remaining storage classes to non-default"
for  sc in $(oc get storageclass -o name); do
    oc patch $sc -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
done

echo "importing new manual storageclass"
oc create -f ${BASE}/../yaml/storage-class.yml