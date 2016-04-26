#!/bin/bash -ex

gcloud compute networks create 'demo-net' \
  --mode 'auto'

gcloud compute firewall-rules create 'demo-extfw' \
  --network 'demo-net' \
  --allow 'tcp:22,tcp:4040,tcp:6783,udp:6783,tcp:80' \
  --target-tags 'demo-ext' \
  --description 'External access for SSH and Weave Scope user interface'

gcloud compute firewall-rules create 'demo-intfw' \
  --network 'demo-net' \
  --allow 'tcp:6783,udp:6783-6784' \
  --source-tag 'demo-weave' \
  --target-tags 'demo-weave' \
  --description 'Internal access for Weave Net ports'

gcloud compute firewall-rules create 'demo-nodefw' \
  --network 'demo-net' \
  --allow 'tcp,udp,icmp,esp,ah,sctp' \
  --source-tag 'demo-node' \
  --target-tags 'demo-node' \
  --description 'Internal access to all ports on the nodes'

common_instace_flags=(
  --network demo-net
  --image centos-7
  --metadata-from-file startup-script=provision.sh
  --boot-disk-type pd-standard
)

gcloud compute instance-templates create 'demo-node-template' \
  "${common_instace_flags[@]}" \
  --tags 'demo-weave,demo-ext,demo-node' \
  --boot-disk-size '30GB' \
  --can-ip-forward \
  --scopes 'storage-ro,compute-rw,monitoring,logging-write'

gcloud compute instance-groups managed create 'demo-node-group' \
  --template 'demo-node-template' \
  --base-instance-name 'demo-node' \
  --size 3
