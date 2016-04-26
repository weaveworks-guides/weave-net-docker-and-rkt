#!/bin/bash -x
weave reset

grep -q native ~/Library/Containers/com.docker.docker/Data/database/com.docker.driver.amd64-linux/network \
  || (echo "Please disable VPC mode" ; exit)

list_weave_peers_in_group() {
  ## There doesn't seem to be a native way to obtain instances with certain tags, so we use awk
  gcloud compute instance-groups list-instances $1 --uri --quiet \
    | xargs -n1 gcloud compute instances describe \
        --format='value(tags.items[], name, networkInterfaces[0].accessConfigs[0].natIP)' \
    | awk '$1 ~ /(^|\;)demo-weave($|\;).*/ && $2 ~ /^demo-.*$/ { print $3 }'
}

export WEAVE_PASSWORD=ee456fce79405ce095bb0f118f11c6473384a1a6 WEAVE_DEBUG=1

weave launch --ipalloc-init observer $(list_weave_peers_in_group demo-node-group)
