#!/bin/bash

oc delete -n nfs statefulset/nfs-server
oc delete -n nfs pvc/nfs-server
oc get pv -o name | grep nfs- | xargs oc delete
oc project default
oc delete project nfs