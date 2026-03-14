# OCP Disconnected install notes

## General Info

There are multiple options for installing OCP in a disconnected env...

## Issues

- OCP `4.20.16` is not currently available on the `stable-4.20` channel. This version in the `isc.yaml` caused issues with the `oc-mirror` command

## Links

- [Installing on bare metal](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/installing_on_bare_metal)
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/installing_an_on-premise_cluster_with_the_agent-based_installer/index#installing-ocp-agent-inputs_installing-with-agent-based-installer
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#installing-mirroring-creating-registry
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#prerequisites_installing-mirroring-creating-registry
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#oc-mirror-workflows-partially-disconnected-v2_about-installing-oc-mirror-v2
- [Installing a cluster without an external registry - Single ISO Download](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/installing_an_on-premise_cluster_with_the_agent-based_installer/index#installing-ove)
  - [x] I’m installing on a disconnected/air-gapped/secured environment

## Commands

```sh
# nmstatectl is required for config validation
sudo dnf install /usr/bin/nmstatectl -y

# !! MANUAL !!
# create pull-secret
# https://console.redhat.com/openshift/downloads#tool-pull-secret
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
# !! IMPORTANT !! - these versions should match
# openshift-install needs to match the version(s) in the isc.yaml (oc-mirror)

oc version
openshift-install version

# setup autocomplete
. <(oc completion bash)
. <(openshift-install completion bash)
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

## Additional Links

- https://github.com/mariocr73/OCP-ABI-BAREMETAL
