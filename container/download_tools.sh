#!/bin/bash

set -euo pipefail

BIN_PATH=scratch/usr/local/bin
BASH_COMP=scratch/etc/bash_completion.d

[ -d "${BIN_PATH}" ] || mkdir -p "${BIN_PATH}"
[ -d "${BASH_COMP}" ] || mkdir -p "${BASH_COMP}"

PATH=${BIN_PATH}:${PATH}

SCRIPT_URL=https://raw.githubusercontent.com/redhat-na-ssa/demo-ai-gitops-catalog/v0.20/scripts/library

[ -e bin.sh ] || curl -sLO "${SCRIPT_URL}/bin.sh"

# shellcheck disable=SC1091
. bin.sh

# cleanup
rm -rf scratch .oc-mirror.log tools-x86_64.tgz

bin_check oc
bin_check oc-mirror
bin_check openshift-install

chmod 755 "${BIN_PATH}"/*

rm "${BIN_PATH}"/LICENSE || true
tar -czf tools-x86_64.tgz -C scratch . --owner=0 --group=0
