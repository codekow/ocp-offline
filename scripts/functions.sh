#!/bin/bash

SCRATCH=${PWD}/scratch

download_files(){
  SCRATCH=${SCRATCH:-${PWD}/scratch}
  OCP_VER=${1:-4.20.15}

  [ -e ~/bin ] || mkdir -p ~/bin

  [ -e "${SCRATCH}" ] || mkdir -p "${SCRATCH}"

  cd ${SCRATCH}
  [ -e tmp ] || mkdir tmp

  # ocp mirror
  # https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/

  # get oc
  wget -c -nc https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/${OCP_VER}/openshift-client-linux-${OCP_VER}.tar.gz
  tar vzxf openshift-client-*.tar.gz
  mv oc kubectl ~/bin

  # get oc-mirror
  wget -c -nc https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/${OCP_VER}/oc-mirror.tar.gz
  tar vzxf oc-mirror*.tar.gz
  chmod +x oc-mirror
  mv oc-mirror ~/bin

  # get mirror-registry
  wget -c -nc https://mirror.openshift.com/pub/cgw/mirror-registry/latest/mirror-registry-amd64.tar.gz

  mkdir registry
  cd registry

  tar vzxf ../mirror-registry*.tar.gz
  cd ..
}

oc_mirror_src2files(){

TMPDIR=${SCRATCH} \
  oc-mirror --v2 \
    -c ${SCRATCH}/isc.yaml \
    --cache-dir ${SCRATCH}/cache \
    --authfile ${SCRATCH}/pull-secret.txt \
    --image-timeout 60m \
      file://${SCRATCH}/files
}

oc_mirror_files2mirror(){

  pull_secret_merge_with_mirror

  TMPDIR=${SCRATCH} \
  oc-mirror --v2 \
    -c ${SCRATCH}/isc.yaml \
    --dest-tls-verify=false \
    --authfile ${SCRATCH}/merged-auth.json \
    --image-timeout 60m \
    --from file://${SCRATCH}/files \
      docker://$(hostname):8443/redhat
}

oc_mirror_src2mirror(){

  pull_secret_merge_with_mirror

  TMPDIR=${SCRATCH} \
  oc-mirror --v2 \
    -c ${SCRATCH}/isc.yaml \
    --cache-dir ${SCRATCH}/cache \
    --dest-tls-verify=false \
    --workspace file://${SCRATCH}/workspace \
    --authfile ${SCRATCH}/merged-auth.json \
    --image-timeout 60m \
      docker://$(hostname):8443/redhat
}

mirror_registry_install(){

  [ -x mirror-registry ] || return 0

  REG_PATH=/srv/registry
  REG_USER=init
  REG_PASS=alongpassword

  mkdir -p ${REG_PATH}/{config,data,db}

  ./mirror-registry install \
    --initUser "${REG_USER}" \
    --initPassword "${REG_PASS}" \
    --sqliteStorage ${REG_PATH}/db \
    --quayRoot ${REG_PATH}/config \
    --quayStorage ${REG_PATH}/data

  # update CA trust
  cat ${REG_PATH}/quay-rootCA/rootCA.pem | sudo tee /etc/pki/ca-trust/source/anchors/quay.pem
  sudo update-ca-trust extract

  # open firewall (optional)
  sudo firewall-cmd --add-port=8443/tcp --permanent
  sudo firewall-cmd --reload
}

mirror_registry_uninstall(){
  [ -x mirror-registry ] || return 0

  ./mirror-registry uninstall

  sudo firewall-cmd --remove-port=8443/tcp --permanent
  sudo firewall-cmd --reload
}

pull_secret_merge_with_mirror(){
  [ -e pull-secret.txt ] || return 0
  [ -e ${XDG_RUNTIME_DIR}/containers/auth.json ] || return 0

  jq -s '.[0] * .[1]' pull-secret.txt ${XDG_RUNTIME_DIR}/containers/auth.json > merged-auth.json
}
