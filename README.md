# OpenShift NFS Server

This deploys an NFS server in a stateful set and creates a few persistent volumes that connect to the NFS server.

**Note**: The pod uses a gp2 pvc as storage. If your cluster uses a different storage class, you will need to modify the pvc in `yaml/nfs-server.yml`.

This is based on the configuration at <https://github.com/mappedinn/kubernetes-nfs-volume-on-gke>.

## Installation

To set this up, run the following scripts:

* `scripts/01-storage-class.sh`
* `scripts/02-nfs-server.sh`

You can test it with the client deployment in `yaml/nfs-client.yml`.

If the client doesn't work, use the deployment in `yaml/troubleshoot.yml` to troubleshoot.