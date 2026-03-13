#!/bin/sh                    
                                    
oc_mirror_src2files(){
                                    
TMPDIR=${PWD}/tmp \
  oc-mirror --v2 \
    -c ${PWD}/isc.yaml \
    --cache-dir ${PWD}/cache \
    --authfile ${PWD}/pull-secret.txt \
    --image-timeout 60m \
      file://${PWD}/files
}

oc_mirror_files2mirror(){

TMPDIR=${PWD}/tmp \
  oc-mirror --v2 \
    -c ${PWD}/isc.yaml \
    --cache-dir ${PWD}/cache \
    --dest-tls-verify=false \
    --authfile ${PWD}/merged-auth.json \
    --image-timeout 60m \
    --from file://${PWD}/files \
      docker://$(hostname):8443/redhat
}

oc_mirror_src2mirror(){

TMPDIR=${PWD}/tmp \
  oc-mirror --v2 \
    -c ${PWD}/isc.yaml \
    --cache-dir ${PWD}/cache \
    --dest-tls-verify=false \
    --workspace file://${PWD}/workspace \
    --authfile ${PWD}/pull-secret.txt \
    --image-timeout 60m \
      docker://$(hostname):8443/redhat
}

mirror_registry_install(){
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
}

mirror_registry_uninstall(){
  ./mirror-registry uninstall
}

pull_secret_merge_with_mirror(){
  [ -e pull-secret.txt ] || return 0
  [ -e ${XDG_RUNTIME_DIR}/containers/auth.json ] || return 0

  jq -s '.[0] * .[1]' pull-secret.txt ${XDG_RUNTIME_DIR}/containers/auth.json > merged-auth.json
}
