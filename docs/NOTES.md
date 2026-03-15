# OCP Disconnected install notes

## General Info

There are multiple options for installing OCP in a disconnected environment:

- Single ISO (no external registry)
- Agent based install

Additional options

- Installer Provisioned Install (IPI)- 3 masters + 1 bastion
- User Provisioned Install (UPI)

## Issues

- OCP `4.20.16` is not currently available on the `stable-4.20` channel. This version in the `isc.yaml` caused issues with the `oc-mirror` command

## Links

- [Installing on bare metal](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/installing_on_bare_metal)
- [Installing with Agent Based Installer](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/installing_an_on-premise_cluster_with_the_agent-based_installer/index#installing-ocp-agent-inputs_installing-with-agent-based-installer)
- [Installing a mirrored registry in a disconnected environment - Prereqs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#prerequisites_installing-mirroring-creating-registry)
- [Installing a mirrored registry in a disconnected environment](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#installing-mirroring-creating-registry)
- [oc-mirror in a partially disconnected env](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#oc-mirror-workflows-partially-disconnected-v2_about-installing-oc-mirror-v2)
- [Installing a cluster without an external registry - Single ISO Download](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/installing_an_on-premise_cluster_with_the_agent-based_installer/index#installing-ove)
  - [x] I’m installing on a disconnected/air-gapped/secured environment
- [Agent Based Installer - Home Lab Notes](https://github.com/mariocr73/OCP-ABI-BAREMETAL)

## Commands

Install `nmstatectl` on your bastion host - this is required to verify your network config in `agent-config.yaml`

```sh
# nmstatectl is required for config validation
sudo dnf install /usr/bin/nmstatectl -y
```

Create a `pull-secret.txt`

```sh
# !! MANUAL !!
# create pull-secret
# https://console.redhat.com/openshift/downloads#tool-pull-secret
# vi pull-secret.txt
```

```sh
git clone https://github.com/codekow/ocp-offline
cd ocp-offline

# make new folder for all the artifacts
mkdir ocp-install
cd ocp-install

# load functions
. ../scripts/functions.sh

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
# copy the isc.yaml into current dir
cp ../dump/agent/isc-ocp*.yaml .

# these commands are used to create tar(s) and load the tar(s) into the disconnected mirror
# oc_mirror_src2files
# oc_mirror_files2mirror

# install mirror-registry
# this folder will have the extracted mirror-registry files
cd quay
mirror_registry_install /srv/registry
cd ..

# directly mirror what is online to a disconnected registry
oc_mirror_src2mirror
```

```sh
# login to mirror registry
podman login $(hostname):8443
```

Create an iso to add worker nodes to an existing cluster

```sh
oc adm node-image create
```
