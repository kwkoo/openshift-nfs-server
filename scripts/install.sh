#!/bin/bash

PROJ=nfs
IS=nfs-server
APP=nfs-server
SA=nfs-server
STORAGECLASS=""

cd $(dirname $0)
BASE=$(pwd)
cd - >> /dev/null

function ensure_present {
  which $1 2>&1 >> /dev/null
  if [ $? -ne 0 ]; then
    echo "$1 not in path"
    exit 1
  fi
}

ensure_present oc
ensure_present envsubst
ensure_present cut

oc whoami
if [ $? -ne 0 ]; then
  echo "you are not logged in using oc login"
  exit 1
fi

oc get storageclass/managed-nfs-storage &> /dev/null
if [ $? -eq 0 ]; then
  echo "managed-nfs-storage storageclass exists - removing it"
  oc delete storageclass/managed-nfs-storage
fi

echo "iterating through storage classes"

for sc in $(oc get storageclass -o name); do
  isdefault="$(oc get $sc -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')"
  if [ "$isdefault" == "true" ]; then
    STORAGECLASS="$(echo $sc | cut -d / -f 2)"
    echo "found current default storage class $STORAGECLASS"
  fi
  oc patch $sc -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
done

if [ -n "$1" ]; then
  STORAGECLASS="$1"
  echo "$1 was provided on the command line - using that for the NFS PVC"
fi

if [ -z "$STORAGECLASS" ]; then
  echo "could not determine the storage class to use for the NFS PVC - provide this as the argument to $0"
  echo "usage: $0 storageclass"
  exit 1
fi

oc get storageclass $STORAGECLASS &> /dev/null
if [ $? -ne 0 ]; then
  echo "storage class $STORAGECLASS does not exist"
  exit 1
fi

oc get project/${PROJ} &> /dev/null
if [ $? -eq 0 ]; then
    echo "${PROJ} project exists - remove it before re-executing $0"
    exit 1
fi

set -e

oc new-project $PROJ
oc new-build --strategy docker --binary -n $PROJ --name $IS -l app=$APP
oc start-build $IS -n $PROJ --from-dir ${BASE}/../volume-nfs --follow

oc create -n $PROJ sa $SA
oc adm policy add-scc-to-user anyuid -z $SA
oc adm policy add-scc-to-user privileged -z $SA

set +e
echo -n "waiting for istag/nfs-server:latest to appear..."
until oc get -n $PROJ istag/nfs-server:latest &> /dev/null; do
  echo -n "."
  sleep 5
done
echo "done"
set -e

DOCKERIMAGEREFERENCE="$(oc get -n $PROJ istag/nfs-server:latest -o jsonpath='{.image.dockerImageReference}')"
echo "nfs-server image reference is $DOCKERIMAGEREFERENCE"
echo "using $STORAGECLASS as the storage class for the nfs-server PVC"

DOCKERIMAGEREFERENCE=$DOCKERIMAGEREFERENCE STORAGECLASS=$STORAGECLASS envsubst < ${BASE}/../yaml/nfs-server.yml | oc apply -n $PROJ -f -

echo -n "waiting for svc/nfs-server to appear..."
until oc get -n $PROJ svc/nfs-server &> /dev/null; do
  echo -n "."
  sleep 5
done
echo "done"

# This is a hack - we can't use the .svc.cluster.local service address as the
# NFS server address in OpenShift 4.2.
NFSSERVERIP=$(oc get svc/nfs-server -n $PROJ -o jsonpath='{.spec.clusterIP}')

echo "NFS server IP address is ${NFSSERVERIP}"

# Provision nfs-client-provisioner
set +e
PROJ=$PROJ envsubst < ${BASE}/../yaml/nfs-subdir-external-provisioner/rbac.yaml | oc apply -f -
oc apply -f ${BASE}/../yaml/nfs-subdir-external-provisioner/scc.yaml
oc adm policy add-scc-to-user nfs-admin -z nfs-client-provisioner -n $PROJ
PROJ=$PROJ NFSSERVERIP=$NFSSERVERIP NFSPATH=/ envsubst < ${BASE}/../yaml/nfs-subdir-external-provisioner/deployment.yaml | oc apply -f -
oc apply -f ${BASE}/../yaml/nfs-subdir-external-provisioner/class.yaml
