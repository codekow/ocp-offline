# OCP Disconnected install notes

## Issues

- OCP `4.20.16` is not currently available on the `stable-4.20` channel. This version in the `isc.yaml` caused issues with the `oc-mirror` command

## Links

- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#installing-mirroring-creating-registry
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#prerequisites_installing-mirroring-creating-registry
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#oc-mirror-workflows-partially-disconnected-v2_about-installing-oc-mirror-v2

## Commands

```sh
# create pull-secret
# https://console.redhat.com/openshift/downloads#tool-pull-secret
# !! MANUAL !!
# vi pull-secret.txt
```

```sh
mkdir ocp-install
cd ocp-install

# ocp mirror
# https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/
OCP_VER=4.20.15

# get oc
wget https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/${OCP_VER}/openshift-client-linux-${OCP_VER}.tar.gz
tar vzxf openshift-client-*.tar.gz
mv oc kubectl ~/bin

# get oc-mirror
wget https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/${OCP_VER}/oc-mirror.tar.gz
tar vzxf oc-mirror*.tar.gz
chmod +x oc-mirror
mv oc-mirror ~/bin

# setup autocomplete
. <(oc completion bash)
. <(oc-mirror --v2 completion bash)
```

```sh
# get mirror-registry
wget https://mirror.openshift.com/pub/cgw/mirror-registry/latest/mirror-registry-amd64.tar.gz

mkdir registry
cd registry

tar vzxf ../mirror-registry*.tar.gz
mv mirror-registry ~/bin
```

```sh
# login to mirror registry
podman login $(hostname):8443
```

```sh
REG_PATH=/srv/registry



# combine pull-secret
jq -s '.[0] * .[1]' pull-secret.txt ${XDG_RUNTIME_DIR}/containers/auth.json > merged.json

# update CA trust
cp ${REG_PATH}/quay-rootCA/rootCA.pem /etc/pki/ca-trust/source/anchors/quay.pem
update-ca-trust extract

# open firewall (optional)
firewall-cmd --add-port=8443/tcp --permanent
firewall-cmd --reload
```

```sh
TMPDIR=${PWD}/tmp \
  ./oc-mirror --v2 -c ${PWD}/isc.yaml \
  --from file://${PWD}/files \
  --cache-dir ${PWD}/cache \
  --dest-tls-verify=false \
  --image-timeout 60m docker://$(hostname):8443/redhat
```
