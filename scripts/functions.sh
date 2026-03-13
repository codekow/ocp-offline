#!/bin/bash

download_files(){
  SCRATCH=${1:-${PWD}}
  OCP_VER=${2:-4.20.15}

  [ -e ~/bin ] || mkdir -p ~/bin

  [ -e "${SCRATCH}" ] || mkdir -p "${SCRATCH}"

  cd ${SCRATCH}
  [ -e tmp ] || mkdir tmp

  # create pull-secret
  # https://console.redhat.com/openshift/downloads#tool-pull-secret
  # !! MANUAL !!
  # vi pull-secret.txt

  # ocp mirror
  # https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/

  # get oc
  wget -c -nc https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/${OCP_VER}/openshift-client-linux-${OCP_VER}.tar.gz
  tar vzxf openshift-client-*.tar.gz
  [ -e README.md ] && (cat README.md; rm README.md)
  mv oc kubectl ~/bin

  # get openshift-install
  wget -c -nc https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_VER}/openshift-install-linux.tar.gz
  tar vzxf openshift-install-*.tar.gz
  [ -e README.md ] && (cat README.md; rm README.md)
  mv openshift-install ~/bin

  # get oc-mirror
  wget -c -nc https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/${OCP_VER}/oc-mirror.tar.gz
  tar vzxf oc-mirror*.tar.gz
  [ -e README.md ] && (cat README.md; rm README.md)
  chmod +x oc-mirror
  mv oc-mirror ~/bin

  # get mirror-registry
  wget -c -nc https://mirror.openshift.com/pub/cgw/mirror-registry/latest/mirror-registry-amd64.tar.gz

  # unpack mirror-registry files in dir
  [ -e quay ] || mkdir quay
  cd quay

  tar vzxf ../mirror-registry*.tar.gz
  cd ..
}

oc_mirror_src2files(){
  SCRATCH=${SCRATCH:-${PWD}}

  TMPDIR=${SCRATCH} \
  oc-mirror --v2 \
    -c ${SCRATCH}/isc.yaml \
    --cache-dir ${SCRATCH}/cache \
    --authfile ${SCRATCH}/pull-secret.txt \
    --image-timeout 60m \
      file://${SCRATCH}/files
}

oc_mirror_files2mirror(){
  SCRATCH=${SCRATCH:-${PWD}}

  pull_secret_merge_with_mirror

  TMPDIR=${SCRATCH} \
  oc-mirror --v2 \
    -c ${SCRATCH}/isc.yaml \
    --dest-tls-verify=false \
    --authfile ${SCRATCH}/pull-secret.json \
    --image-timeout 60m \
    --from file://${SCRATCH}/files \
      docker://$(hostname):8443/redhat
}

oc_mirror_src2mirror(){
  SCRATCH=${SCRATCH:-${PWD}}

  pull_secret_merge_with_mirror

  TMPDIR=${SCRATCH} \
  oc-mirror --v2 \
    -c ${SCRATCH}/isc.yaml \
    --dest-tls-verify=false \
    --workspace file://${SCRATCH}/workspace \
    --authfile ${SCRATCH}/pull-secret.json \
    --image-timeout 60m \
      docker://$(hostname):8443/redhat
}

mirror_registry_install(){

  [ -x mirror-registry ] || return 0

  REG_PATH=${1:-${PWD}}
  REG_USER=${2:-init}
  REG_PASS=${3:-alongpassword}

  mkdir -p ${REG_PATH}/{config,data,db}

  ./mirror-registry install \
    --initUser "${REG_USER}" \
    --initPassword "${REG_PASS}" \
    --sqliteStorage ${REG_PATH}/db \
    --quayRoot ${REG_PATH}/config \
    --quayStorage ${REG_PATH}/data

  # update CA trust
  cat ${REG_PATH}/config/quay-rootCA/rootCA.pem | sudo tee /etc/pki/ca-trust/source/anchors/quay.pem
  sudo update-ca-trust extract

  # open firewall (optional)
  sudo firewall-cmd --add-port=8443/tcp --permanent
  sudo firewall-cmd --reload

  podman login $(hostname):8443 -u "${REG_USER}" -p "${REG_PASS}"
}

mirror_registry_uninstall(){
  [ -x mirror-registry ] || return 0

  sudo rm /etc/pki/ca-trust/source/anchors/quay.pem
  sudo update-ca-trust extract

  sudo firewall-cmd --remove-port=8443/tcp --permanent
  sudo firewall-cmd --reload

  ./mirror-registry uninstall
}

pull_secret_merge_with_mirror(){
  [ -e pull-secret.txt ] || return 0
  [ -e ${XDG_RUNTIME_DIR}/containers/auth.json ] || return 0

  jq -s '.[0] * .[1]' pull-secret.txt ${XDG_RUNTIME_DIR}/containers/auth.json > pull-secret.json

  [ -e auth.json] || mv ${XDG_RUNTIME_DIR}/containers/auth.json auth.json
  cp pull-secret.json ${XDG_RUNTIME_DIR}/containers/auth.json
}

extract_ocp_install(){
  # https://access.redhat.com/solutions/7062500
  echo "
    This openshift-install will not work correctly w/ agent create image...
  "

  echo '
  oc adm release extract \
    -a pull-secret.json \
    --command=openshift-install \
    "$(hostname):8443/redhat/openshift/release-images:${OCP_VER:-4.20.15}-x86_64"
  '
}

extract_iso(){
  oc image extract \
    --path=/coreos/coreos-x86_64.iso:${HOME}/.cache/agent/image_cache \
    --filter-by-os=linux/amd64 \
    --confirm \
    $(hostname):8443/redhat/openshift/release:4.20.15-x86_64-rhel-coreos
}
