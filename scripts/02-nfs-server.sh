#!/bin/bash

PROJ=nfs
IS=nfs-server
APP=nfs-server
SA=nfs-server

cd $(dirname $0)
BASE=$(pwd)
cd - >> /dev/null


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

cd ${BASE}/../volume-nfs
oc project default &> /dev/null

set -e

oc new-project $PROJ &> /dev/null
oc new-build --strategy docker --binary -n $PROJ --name $IS -l app=$APP
oc start-build $IS -n $PROJ --from-dir . --follow

oc create sa $SA
oc adm policy add-scc-to-user anyuid -z $SA
oc adm policy add-scc-to-user privileged -z $SA

sed "s|DOCKERIMAGEREFERENCE|$(oc get istag/nfs-server:latest -o jsonpath='{.image.dockerImageReference}')|" ${BASE}/../yaml/nfs-server.yml | oc apply -n $PROJ -f -

# This is a hack - we can't use the .svc.cluster.local service address as the
# NFS server address in OpenShift 4.2.
NFS_SERVER=$(oc get svc/nfs-server -o jsonpath='{.spec.clusterIP}')

echo "NFS server IP address is ${NFS_SERVER}"

# Provision nfs-client-provisioner
set +e
cat ${BASE}/../yaml/nfs-subdir-external-provisioner/rbac.yaml | sed -e "s|NAMESPACE|${PROJ}|g" | oc apply -f -
oc apply -f ${BASE}/../yaml/nfs-subdir-external-provisioner/scc.yaml
oc adm policy add-scc-to-user nfs-admin -z nfs-client-provisioner -n $PROJ
cat ${BASE}/../yaml/nfs-subdir-external-provisioner/deployment.yaml | sed -e "s|NAMESPACE|${PROJ}|g" -e "s|NFSSERVERIP|${NFS_SERVER}|g" -e "s|NFSPATH|/|g" | oc apply -f -
