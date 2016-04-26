#!/bin/bash -x

curl="curl --silent --location"

cat > /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

yum --assumeyes --quiet install docker-engine
service docker start

if ! [ -x /usr/bin/weave ] ; then
  echo "Installing current version of Weave Net"
  $curl http://git.io/weave --output /usr/bin/weave
  chmod +x /usr/bin/weave
  mkdir -p /opt/cni/bin /etc/cni/net.d
  /usr/bin/weave setup
fi

export WEAVE_PASSWORD=ee456fce79405ce095bb0f118f11c6473384a1a6

/usr/bin/weave version

/usr/bin/weave launch \
  --ipalloc-init consensus=3 \
  --trusted-subnets 10.128.0.0/20,10.132.0.0/20,10.140.0.0/20,10.142.0.0/20

## Find nodes with `demo-weave` tag in an instance group

list_weave_peers_in_group() {
  ## There doesn't seem to be a native way to obtain instances with certain tags, so we use awk
  gcloud compute instance-groups list-instances $1 --uri --quiet \
    | xargs -n1 gcloud compute instances describe \
        --format='value(tags.items[], name, networkInterfaces[0].accessConfigs[0].natIP)' \
    | awk '$1 ~ /(^|\;)demo-weave($|\;).*/ && $2 ~ /^demo-.*$/ { print $2 }'
}

## This is very basic way of doing Weave Net peer discovery, one could potentially implement a pair of
## systemd units that write and watch an environment file and call `weave connect` when needed...
gcloud compute instance-groups managed wait-until-stable demo-node-group --quiet
/usr/bin/weave connect \
  $(list_weave_peers_in_group demo-node-group)

if ! [ -x /usr/bin/scope ] ; then
  echo "Installing current version of Weave Scope"
  $curl http://git.io/scope --output /usr/bin/scope
  chmod +x /usr/bin/scope
fi

/usr/bin/scope version

/usr/bin/scope launch


if ! [ -d /opt/rkt-v1.4.0 ] ; then
  $curl https://github.com/coreos/rkt/releases/download/v1.4.0/rkt-v1.4.0.tar.gz \
    | tar xzv -C /opt
  groupadd rkt
  /opt/rkt-v1.4.0/scripts/setup-data-dir.sh
  ln -s /opt/rkt-v1.4.0/rkt /usr/bin
  mkdir -p /etc/rkt/net.d /usr/lib/rkt/plugins/net
  ln -s /etc/cni/net.d/* /etc/rkt/net.d
  docker exec weaveplugin cat plugin \
    | tee /usr/lib/rkt/plugins/net/weave-net /usr/lib/rkt/plugins/net/weave-ipam
  chmod +x /usr/lib/rkt/plugins/net/weave-net /usr/lib/rkt/plugins/net/weave-ipam
fi

setenforce 0 ## https://github.com/coreos/rkt/issues/1727


if ! [ -x /usr/bin/docker-compose ] ; then
  $curl https://github.com/docker/compose/releases/download/1.7.0/docker-compose-Linux-x86_64 \
    --output /usr/bin/docker-compose
  chmod +x /usr/bin/docker-compose
fi

if ! [ -d /apps ] ; then
  mkdir -p /apps
  $curl https://raw.githubusercontent.com/ThePixelMonsterzApp/infra/master/docker-compose-with-weave-net.yml \
    --output /apps/docker-compose.yml
mkdir
