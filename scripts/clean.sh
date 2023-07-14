#!/bin/bash

PROJ=nfs

cd $(dirname $0)
BASE=$(pwd)
cd - >> /dev/null

for f in ${BASE}/../yaml/nfs-subdir-external-provisioner/*.yaml; do
  PROJ=$PROJ envsubst < $f | oc delete -f -
done

oc delete -n $PROJ sts,svc,pvc,is,istag -l app=nfs-server
oc delete -n $PROJ sa nfs-server
oc get pv -o name | grep nfs- | xargs oc delete
oc project default
oc delete project $PROJ