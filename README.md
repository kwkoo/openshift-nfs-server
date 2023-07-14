# OpenShift NFS Server

This deploys an NFS server in a stateful set and deploys a [nfs-client-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner.git) to dynamically provision persistent volumes.

This is based on the configuration at <https://github.com/mappedinn/kubernetes-nfs-volume-on-gke>.


## Installation

To set this up, run the following script:

	./scripts/install.sh

You can test it with the client deployment in `yaml/nfs-client.yml`.

If the client doesn't work, use the deployment in `yaml/troubleshoot.yml` to troubleshoot.
