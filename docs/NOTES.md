# OCP Disconnected install notes

## Issues

- OCP `4.20.16` is not currently available on the `stable-4.20` channel. This version in the `isc.yaml` caused issues with the `oc-mirror` command

## Links

- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#installing-mirroring-creating-registry
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#prerequisites_installing-mirroring-creating-registry
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#oc-mirror-workflows-partially-disconnected-v2_about-installing-oc-mirror-v2

## Commands

```sh
sudo dnf install /usr/bin/nmstatectl -y

# create pull-secret
# https://console.redhat.com/openshift/downloads#tool-pull-secret
# !! MANUAL !!
# vi pull-secret.txt
```

```sh
mkdir ocp-install
cd ocp-install

# setup functions
. scripts/functions.sh

download_files
```

```sh
# setup autocomplete
. <(oc completion bash)
. <(oc-mirror --v2 completion bash)
```

```sh
# oc_mirror_src2files
# oc_mirror_files2mirror

# install mirror-registry
cd quay
mirror_registry_install /srv/registry
cd ..

oc_mirror_src2mirror
```

```sh
# login to mirror registry
podman login $(hostname):8443
```
