#!/bin/bash

set -eo pipefail

BIN_PATH=scratch/usr/local/bin
BASH_COMP=scratch/etc/bash_completion.d

[ -d "${BIN_PATH}" ] || mkdir -p "${BIN_PATH}"
[ -d "${BASH_COMP}" ] || mkdir -p "${BASH_COMP}"

PATH=${BIN_PATH}:${PATH}

SCRIPT_URL=https://raw.githubusercontent.com/redhat-na-ssa/demo-ai-gitops-catalog/main/scripts/library

# download update if file missing
[ -e bin.sh ] || curl -sLO "${SCRIPT_URL}/bin.sh"

# shellcheck disable=SC1091
. bin.sh

# cleanup
rm -rf scratch .oc-mirror.log tools-x86_64.tgz

OCP_VERSION=stable-4.20

bin_check butane latest
bin_check oc "${OCP_VERSION}"
bin_check oc-mirror "${OCP_VERSION}"
bin_check openshift-install "${OCP_VERSION}"
bin_check opm "${OCP_VERSION}"

chmod 755 "${BIN_PATH}"/*

[ -e "${BIN_PATH}"/LICENSE ] && rm "${BIN_PATH}"/LICENSE
tar -czf tools-x86_64.tgz -C scratch . --owner=0 --group=0
