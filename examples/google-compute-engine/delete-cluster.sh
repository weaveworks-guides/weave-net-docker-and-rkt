#!/bin/bash -x

gcloud compute instance-groups managed delete -q 'demo-node-group'

gcloud compute instance-templates delete -q 'demo-node-template'

gcloud compute firewall-rules delete -q 'demo-extfw' 'demo-intfw' 'demo-nodefw'

gcloud compute networks delete -q 'demo-net'
