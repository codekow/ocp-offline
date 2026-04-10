#!/bin/bash
# set -x

# shellcheck disable=SC2140,SC2086

# HELP BEGIN
# local_registry.sh - Setup a local container registry with authentication and browser UI
#
# https://www.redhat.com/en/blog/openshift-private-registry
# https://distribution.github.io/distribution/about/deploying/
#
# Prerequisites:
#   - podman
#   - openssl
#   - curl
#   - htpasswd (httpd-tools)
#   - sudo/root privileges for systemd and firewall changes
#
# Usage:
#   ./local_registry.sh [--auth] [--help]
#
# Options:
#   --auth      Enable authentication for the registry (default: off)
#   --help, -h  Show this help message and exit
#
# Example:
#   ./local_registry.sh --auth
#
# This script will:
#   - Generate self-signed certs and htpasswd if needed
#   - Start a local registry (zot) and browser UI with podman
#   - Configure systemd service and firewall
#   - Output registry credentials and config info
#
# For more details, see the project README.
# HELP END

help() {
  sed -n '/^# HELP BEGIN/,/^# HELP END/ {/^# HELP BEGIN/d;/^# HELP END/d;s/^# *//p;}' "$0"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  help
  exit 0
fi

check_cmds() {
  REQUIRED_CMDS="podman openssl curl htpasswd"

  for dep in $REQUIRED_CMDS; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "[ERROR] Required command not found: $dep"
      missing=1
    fi
  done

  if [ -n "$missing" ]; then
    echo "[FATAL] Please install the missing dependencies and re-run this script."
    exit 1
  fi
}

genpass(){
  < /dev/urandom LC_ALL=C tr -dc Aa-zZ0-9 | head -c "${1:-32}"
}

registry_get_catalog(){
  curl -k -u "${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}" "https://${REGISTRY_HOSTNAME}:5000/v2/_catalog"
}

registry_init_mkdir(){
  mkdir -p registry/{config/secret,data/zot}
}

registry_init(){

  REGISTRY_HOSTNAME=${REGISTRY_HOSTNAME:-localhost}
  REGISTRY_USERNAME=${REGISTRY_USERNAME:-registry}
  REGISTRY_PASSWORD=${REGISTRY_PASSWORD:-$(genpass 16)}

  [ -d registry/data/zot ] || registry_init_mkdir

  if [ ! -e registry/registry-info.txt ]; then
    echo "
      REGISTRY_HOSTNAME=${REGISTRY_HOSTNAME}
      REGISTRY_USERNAME=${REGISTRY_USERNAME}
      REGISTRY_PASSWORD=${REGISTRY_PASSWORD}
      REGISTRY_AUTH=${REGISTRY_AUTH:-Y}
      REGISTRY_TLS=${REGISTRY_TLS:-Y}
    " > registry/registry-info.txt
  else
    # shellcheck source=/dev/null
    . registry/registry-info.txt
  fi
}

registry_cert_create(){
  if [ ! -e "registry/config/${REGISTRY_HOSTNAME}.key" ]; then
    [ -e registry/config ] || registry_init_mkdir
    openssl req \
      -x509 -days 3650 \
      -newkey rsa:4096 \
      -nodes -sha256 \
      -keyout "registry/config/${REGISTRY_HOSTNAME}.key" \
      -out "registry/config/${REGISTRY_HOSTNAME}.crt" \
      -subj "/C=NA/ST=NA/L=NA/O=NA/OU=NA/CN=${REGISTRY_HOSTNAME}" \
      -addext "subjectAltName = DNS:localhost, DNS:${REGISTRY_HOSTNAME}, DNS:${REGISTRY_HOSTNAME%%.*}"
  fi
}

registry_cert_ca_trust(){
  if [ -d /etc/pki/ca-trust/source/anchors/ ]; then
    [ -e /etc/pki/ca-trust/source/anchors/"${REGISTRY_HOSTNAME}.crt" ] && return
    echo "copying ${REGISTRY_HOSTNAME}.crt to /etc/pki/ca-trust/source/anchors/"
    sudo cp -u "registry/config/${REGISTRY_HOSTNAME}.crt" /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust
  else
    sudo cp -u "registry/config/${REGISTRY_HOSTNAME}.crt" /usr/local/share/ca-certificates/
  fi
}

registry_auth_create(){
  if [ ! -e registry/config/secret/htpasswd ]; then
    which htpasswd || dnf -y install httpd-tools
    touch registry/config/secret/htpasswd
    htpasswd -bB registry/config/secret/htpasswd "${REGISTRY_USERNAME}" "${REGISTRY_PASSWORD}"
  fi
}

registry_firewall_setup(){
  which firewall-cmd || return
    firewall-cmd --permanent --add-port=5000/tcp
    firewall-cmd --reload
}

registry_systemd_create(){

cat << FILE > registry/mirror-registry.service
[Unit]
Description="Container Registry"

[Service]
Restart=always
ExecStart=/usr/bin/podman start -a mirror-registry
ExecStop=/usr/bin/podman stop -t 10 mirror-registry

[Install]
WantedBy=network-online.target
FILE
}

registry_systemd_setup(){
  cp registry/mirror-registry.service /etc/systemd/system/mirror-registry.service

  systemctl daemon-reload
  systemctl enable --now mirror-registry.service
  systemctl restart mirror-registry.service
}

registry_zot_config(){

# https://github.com/project-zot/zot

cat << JSON > registry/config/00-zot.tmp
{
  "storage": {
    "rootDirectory": "/var/lib/registry",
    "commit": false,
    "dedupe": true,
    "gc": true,
    "gcDelay": "1h",
    "gcInterval": "24h"
  },
  "http": {
    "address": "0.0.0.0",
    "port": "5000",
JSON

if [ "${REGISTRY_TLS}" = "Y" ]; then
cat << JSON > registry/config/01-zot.tmp
    "tls": {
      "cert": "/etc/zot/${REGISTRY_HOSTNAME}.crt",
      "key": "/etc/zot/${REGISTRY_HOSTNAME}.key"
    },
JSON
fi

if [ "${REGISTRY_AUTH}" = "Y" ]; then
cat << JSON >> registry/config/10-zot.tmp
    "auth": {
      "htpasswd": {
        "path": "/etc/zot/secret/htpasswd"
      },
      "failDelay": 5
    },
    "realm": "zot",
JSON
fi

cat << JSON >> registry/config/20-zot.tmp
    "compat": ["docker2s2"]
  },
  "log": {
    "level": "info",
    "output": "/var/lib/registry/zot-main.log",
    "audit": "/var/lib/registry/zot-audit.log"
  },
  "extensions": {
JSON

touch registry/config/secret/upstream-auth.json
cat << JSON > registry/config/secret/upstream-auth.json.example
{
  "example.com": {
    "username": "admin",
    "password": "admin"
  }
}
JSON

cat << JSON >> registry/config/30-zot.tmp
		"sync": {
      "enable": true,
      "credentialsFile": "/etc/zot/secret/upstream-auth.json",
      "registries": [
        {
          "urls": ["https://index.docker.io"],
          "content": [
            {
              "prefix": "**", 
              "destination": "/docker.io"
            }
          ],
          "onDemand": true,
          "tlsVerify": true,
          "maxRetries": 5,
          "retryDelay": "30s"
JSON

registry_zot_config_registry k8s.gcr.io
registry_zot_config_registry ghcr.io
registry_zot_config_registry quay.io
registry_zot_config_registry registry.access.redhat.com
registry_zot_config_registry registry.connect.redhat.com
registry_zot_config_registry registry.redhat.io

cat << JSON >> registry/config/99-zot.tmp
				}
      ]
    },
    "search": {
      "enable": true,
      "cve": {
        "updateInterval": "4h"
      }
    },
    "ui": {
      "enable": true
    },
    "mgmt": {
      "enable": true
    },
    "trust": {
      "enable": true,
      "cosign": true,
      "notation": true
    },
    "scrub": {
      "interval": "72h"
    }
  }
}
JSON

  cat registry/config/*-zot*.tmp > registry/config/config.json
  rm registry/config/*.tmp
}

registry_zot_config_registry(){
  REGISTRY_URI=${1:-k8s.gcr.io}

cat << JSON >> registry/config/31-zot-${REGISTRY_URI}.tmp
				},
        {
          "urls": ["https://${REGISTRY_URI}"],
          "content": [
            {
              "prefix": "**", 
              "destination": "/${REGISTRY_URI}"
            }
          ],
          "onDemand": true,
          "tlsVerify": true,
          "maxRetries": 5,
          "retryDelay": "30s"
JSON

[ -e registry/registries.conf ] || registry_registries_conf_create

cat << CONFIG >> registry/registries.conf
[[registry]]
prefix = "${REGISTRY_URI}"
location = "${REGISTRY_URI}"
[[registry.mirror]]
location = "${REGISTRY_HOSTNAME}:5000/${REGISTRY_URI}"

CONFIG

}

registry_zot_run(){

  registry_zot_config

  [ $EUID -eq 0 ] && POD_USER="--user 1000"

  podman run -d \
    --replace \
    --name mirror-registry \
    ${POD_USER} \
    -p 5000:5000 \
    -v ./registry/config:/etc/zot:z \
    -v ./registry/data/zot:/var/lib/registry:z \
      ghcr.io/project-zot/zot:latest
}

registry_v2_run(){
  if [ -n "${REGISTRY_AUTH}" ]; then
    REGISTRY_AUTH_INFO="
    -e REGISTRY_AUTH=htpasswd \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/config/htpasswd \
    -e REGISTRY_AUTH_HTPASSWD_REALM=Registry"
  fi

  podman rm mirror-registry --force

  # shellcheck disable=SC2086
  podman run -d \
    --name mirror-registry \
    --replace \
    -p 5000:5000 \
    -v ./registry/data:/var/lib/registry:z \
    -v ./registry/config:/config:z \
    -e REGISTRY_HTTP_SECRET="$(openssl rand -hex 48)" \
    -e REGISTRY_HTTP_TLS_CERTIFICATE="/config/${REGISTRY_HOSTNAME}.crt" \
    -e REGISTRY_HTTP_TLS_KEY="/config/${REGISTRY_HOSTNAME}.key" \
    ${REGISTRY_AUTH_INFO} \
      docker.io/library/registry:2
}

registry_login_create(){
cat << FILE > registry/auth.json
{
  "auths": {
    "${REGISTRY_HOSTNAME}:5000": {
      "auth": "$(echo -n "${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}" | base64 -w0)"
    }
  }
}
FILE
}

registry_registries_conf_create(){
cat << CONFIG > registry/registries.conf
# \$HOME/.config/containers/registries.conf
# https://www.redhat.com/en/blog/manage-container-registries

[[registry]]
location="${REGISTRY_HOSTNAME}:5000"
# insecure=true

CONFIG
}

local_registry_mirror(){

  registry_auth_create
  registry_cert_create
  registry_login_create
  registry_systemd_create
  registry_registries_conf_create

  # registry_v2_run
  registry_zot_run
}

registry_print_info(){
  cat registry/config/"${REGISTRY_HOSTNAME}".crt
  cat registry/registry-info.txt
  # cat registry/auth.json
  # cat registry/registries.conf
}

local_registry_browser_run(){
  # https://github.com/klausmeyer/docker-registry-browser

  podman run -d \
    --name registry-browser \
    --replace \
    -e SECRET_KEY_BASE="$(openssl rand -hex 48)" \
    -e DOCKER_REGISTRY_URL=https://registry:5000 \
    -e NO_SSL_VERIFICATION=true \
    -e ENABLE_DELETE_IMAGES=true \
    -p 8080:8080 \
      docker.io/klausmeyer/docker-registry-browser
}

mirror_registry_install(){
  check_cmds
  registry_init
  local_registry_mirror
  # local_registry_browser_run
  registry_print_info
}
