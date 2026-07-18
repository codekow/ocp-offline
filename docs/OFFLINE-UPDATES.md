# Offline Updates Notes

```sh
# install update operator
oc apply -k configs/gitops/operators/cincinnati-operator/operator/overlays/v1/
```

```sh
POLICY_ENGINE_GRAPH_URI="$(oc -n openshift-update-service get updateservice/main -o jsonpath='{.status.policyEngineURI}/api/upgrades_info/v1/graph{"\n"}')"
PATCH="{\"spec\":{\"upstream\":\"${POLICY_ENGINE_GRAPH_URI}\"}}"

oc patch clusterversion/version -p "${PATCH}" --type merge

```

## Build graph data image

```sh
cat << FILE > Dockerfile
FROM registry.access.redhat.com/ubi8/ubi:8.1

ENV GRAPH_URL=https://github.com/openshift/cincinnati-graph-data/archive/master.tar.gz

RUN mkdir -p /var/lib/cincinnati/graph-data/ && \
    curl -L "\${GRAPH_URL}" | tar vzx -C /var/lib/cincinnati/graph-data/ --strip-components=1
FILE

podman build -f ./Dockerfile -t graph-data-image:latest

# podman save -o graph-data.tar  graph-data-image:latest

```

## Links

- https://access.redhat.com/labs/ocpupgradegraph/update_path
- https://access.redhat.com/labs/ocpupgradegraph/update_path?channel=stable-4.18&arch=x86_64&is_show_hot_fix=false&current_ocp_version=4.18.46&target_ocp_version=4.20.40
- https://archyslife.blogspot.com/2025/03/openshift-install-and-configure.html
- https://medium.com/@hillayamir/openshift-update-service-your-personal-over-the-air-update-service-776b43230011
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/disconnected_environments/index#update-service-overview_updating-disconnected-cluster-osus
