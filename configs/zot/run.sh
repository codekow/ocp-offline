#!/bin/sh

REGISTRY_DIR=${REGISTRY_DIR:-./registry}

# create container path
[ -d ${REGISTRY_DIR}/config ] || mkdir -p ${REGISTRY_DIR}/{config,data}

# create initial config
[ -e ${REGISTRY_DIR}/config/config.json ] || cp $(dirname "$0")/config.json ${REGISTRY_DIR}/config/

zot_run(){
  podman run -d \
    --replace \
    --name mirror-registry \
    ${POD_USER} \
    -p 5000:5000 \
    -v ${REGISTRY_DIR}/config:/etc/zot:z \
    -v ${REGISTRY_DIR}/data:/var/lib/registry:z \
      ghcr.io/project-zot/zot:latest
}

zot_run
