#!/bin/bash

PROJ=nfs
IS=nfs-server
APP=nfs-server
SA=nfs-server

cd $(dirname $0)
BASE=$(pwd)
cd - >> /dev/null

function create_pv() {
    echo "Deleting pv/nfs-$i..."
    oc delete pv/nfs-$i &> /dev/null
    if [ $? -eq 0 ]; then
        sleep 0.5
    fi
    echo "Creating pv/nfs-$i..."
    cat ${BASE}/../yaml/pv.yml \
    | \
    sed \
      -e "s/name: .*/name: $1/" \
      -e "s/storage: .*/storage: $2/" \
      -e "s/server: .*/server: $3/" \
      -e "s|path: .*|path: $4|" \
    | \
    oc apply -f -
}


which oc 2>&1 >> /dev/null
if [ $? -ne 0 ]; then
    echo "oc binary not in path"
    exit 1
fi

oc get project/${PROJ} &> /dev/null
if [ $? -eq 0 ]; then
    echo "${PROJ} project exists - remove it before re-executing $0"
    exit 1
fi

cd ../volume-nfs
oc project default &> /dev/null

set -e

oc new-project $PROJ &> /dev/null
oc new-build --strategy docker --binary --name $IS -l app=$APP
oc start-build $IS --from-dir . --follow

oc create sa $SA
oc adm policy add-scc-to-user anyuid -z $SA
oc adm policy add-scc-to-user privileged -z $SA

oc create -f ../yaml/nfs-server.yml

# Point the image to the imagestream.
oc set triggers statefulset/nfs-server --from-image nfs-server:latest -c nfs-server

# This is a hack - we can't use the .svc.cluster.local service address as the
# NFS server address in OpenShift 4.2.
NFS_SERVER=$(oc get svc/nfs-server -o jsonpath='{.spec.clusterIP}')

echo "NFS server IP address is ${NFS_SERVER}"

set +e

echo "Creating 1Gi persistent volumes"
for i in {0..3}; do
    create_pv nfs-$i 1Gi $NFS_SERVER /$i
done

echo "Creating 2Gi persistent volumes"
for i in 4 5; do
    create_pv nfs-$i 2Gi $NFS_SERVER /$i
done

echo "Creating 4Gi persistent volumes"
for i in 6 7; do
    create_pv nfs-$i 4Gi $NFS_SERVER /$i
done
