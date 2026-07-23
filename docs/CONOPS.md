# XIB Concept of Operations

## 1. Purpose

Security in a Box (XIB) is a self-hosted security visibility platform for
Docker and Kubernetes environments. It combines asset inventory, vulnerability scanning,
compliance analysis, threat-intelligence correlation, identity monitoring,
certificate monitoring, metrics storage, and dashboards in one deployable
package.

This document describes the intended operating environment, deployment
profiles, security boundaries, installation procedures, routine operations,
offline operation, upgrades, rollback, and removal of XIB.

## 2. Operational objectives

XIB is designed to:

- deploy as a self-contained Docker Compose project without Git submodules;
- deploy into a dedicated Kubernetes namespace;
- limit Docker discovery to a restricted, internal-only socket proxy;
- discover Kubernetes workloads using read-only API access;
- support connected and disconnected clusters;
- use persistent local or enterprise-provided Kubernetes storage;
- reuse an existing monitoring platform when one is available;
- provide component dashboards and a unified security posture dashboard; and
- remain removable without modifying application workloads in the monitored
  cluster.

XIB is an analysis and visibility platform. It does not automatically patch,
quarantine, delete, or reconfigure monitored workloads.

## 3. System architecture

The default standalone profile contains the following services:

| Component | Function | Default state |
|---|---|---|
| AIB | Live Kubernetes asset inventory and relationship graph | Enabled |
| VIB | Kubernetes image discovery and Trivy vulnerability scanning | Enabled |
| CIB | Image SBOM, license, EOL, and compliance analysis | Enabled |
| TIB | CISA KEV and EPSS correlation against VIB findings | Enabled |
| IIB | Authentik identity metrics exporter | Disabled |
| PIB | TLS certificate health monitor | Disabled |
| Docker socket proxy | Restricted host container and image discovery for VIB/CIB | Enabled |
| VictoriaMetrics | Shared time-series metrics storage | Enabled |
| Grafana | Component and unified dashboards | Enabled |

The standalone deployment uses one VictoriaMetrics service. Grafana provisions
the following datasource aliases against that service so the original component
dashboards continue to work:

- `vib-vm`
- `tib-vm`
- `cib-vm`
- `iib-vm`
- `pib-vm`
- `xib-metrics`

Grafana provisions six dashboards in the **XIB** folder:

- XIB — Security Overview
- VIB — Vulnerability Overview
- TIB — Threat Intelligence Overview
- CIB — Compliance Overview
- IIB — Identity Overview
- PIB — PKI Certificate Health

Grafana automatic plugin preinstallation, update checks, usage reporting, and
the news feed are disabled. This avoids unnecessary outbound requests on
restricted, intercepted, and disconnected networks. Plugins explicitly
required by a selected deployment profile remain operator-controlled.

For environments that intercept TLS or use private certificate authorities,
operators can provide PEM root CAs without modifying container images. The Helm
profile automatically detects `k8s/custom-ca/ca.crt`, or accepts an existing
ConfigMap through `global.trustedCa.existingConfigMap`; an init container
combines those roots with the public CA bundle and exposes it to XIB
application HTTPS clients. The Compose `make up-ca` target performs the
equivalent bundle preparation on a Linux host. Environment CA files and
generated bundles must not be committed.

IIB and PIB dashboards are installed even when their collectors are disabled.
Their panels remain empty until the corresponding component is configured.

## 4. Deployment profiles

### 4.1 Docker Compose

The root `docker-compose.yml` runs VIB, CIB, TIB, VictoriaMetrics, and Grafana
without Kubernetes. It uses the same immutable application image digests as the
Helm chart. PIB and IIB are optional profiles because they require configured
TLS endpoints or an existing Authentik service.

Compose uses one VictoriaMetrics service and provisions all six Grafana
dashboards. VIB and CIB inspect both the registry images listed in
`XIB_SCAN_IMAGES` and host containers discovered through the restricted socket
proxy. The collectors do not receive the host Docker socket directly.

### 4.2 Kubernetes standalone

The default `k8s/values.yaml` profile installs XIB-owned VictoriaMetrics and
Grafana services plus the vendored SIB-K8s runtime stack. Use this profile for
a new cluster or a self-contained test.

### 4.3 Kubernetes existing platform

`k8s/values-existing-platform.yaml` disables the XIB-owned metrics and Grafana
services and enables Prometheus Operator integration. Use it when the target
cluster already supplies metrics storage, Grafana, and the `ServiceMonitor`
custom resource.

Before using this profile, review datasource, dashboard sidecar, namespace, and
label requirements in the destination monitoring platform. The supplied values
file is an integration starting point, not a promise that every external
monitoring installation uses the same discovery conventions.

### 4.4 Air-gapped

`k8s/values-airgap.yaml` redirects application images to an internal registry
and redirects TIB to internal CISA KEV and EPSS mirrors. Runtime images and data
artifacts must be staged from a connected system before installation.

### 4.5 Disposable validation

A k3d cluster is the reference disposable test environment. It runs Kubernetes
nodes in Docker containers and can be removed as a single unit without changing
another Kubernetes cluster.

## 5. Security and trust boundaries

### 5.1 Kubernetes access

XIB uses one service account. A ClusterRole grants `get`, `list`, and `watch`
access to the workload, networking, and RBAC resources required by AIB and the
Kubernetes-native VIB/CIB adapters. It does not grant create, update, patch,
delete, exec, impersonate, secret-read, or admission-control permissions.

Service-account tokens are mounted only into components that need Kubernetes
API discovery. Other components run with token automounting disabled.

### 5.2 Container controls

Chart-managed application containers run as non-root with:

- privilege escalation disabled;
- all Linux capabilities dropped;
- `RuntimeDefault` seccomp;
- a read-only root filesystem where supported; and
- explicit writable mounts for data, cache, and temporary files.

VIB and CIB use the Kubernetes API to discover image references. They do not
mount `/var/run/docker.sock` and do not require privileged access to containerd.

### 5.3 Secrets

Do not store credentials directly in values files. Reference pre-created
Kubernetes Secrets for Grafana overrides, Authentik tokens, registry
credentials, and other integrations.

When the standalone profile generates a Grafana password, the chart preserves
that password across Helm upgrades. For controlled environments, create an
explicit Secret and set `platform.grafana.admin.existingSecret`.

### 5.4 Network access

In connected mode, components may contact:

- configured container registries;
- Trivy vulnerability databases;
- the CISA KEV feed;
- the FIRST EPSS API; and
- configured Authentik, certificate, or alert endpoints.

In disconnected mode, these dependencies must resolve to internal mirrors.

## 6. Prerequisites

### 6.1 Operator workstation

- `kubectl` configured for the destination cluster
- Helm 3
- Docker or another supported tool for staging OCI images
- PowerShell 7 for the supplied `.ps1` helpers, or equivalent commands
- sufficient access to create namespaces, RBAC, Deployments, Services,
  ConfigMaps, Secrets, and PersistentVolumeClaims

### 6.2 Docker host

- Docker Engine with the Compose v2 plugin
- Linux containers and working container DNS
- at least 4 CPU cores, 8 GiB RAM, and 30 GiB free storage for a basic test
- registry and threat-feed connectivity, or the preloaded offline bundle
- `curl`, Python 3, and GNU Make when using `make smoke`

Docker volumes persist VictoriaMetrics, Grafana, Trivy caches, CIB evidence,
and TIB state. The default Grafana listener binds only to `127.0.0.1`.

### 6.3 Kubernetes cluster

- supported Linux worker nodes
- a default StorageClass, or an explicit `global.storageClass`
- working cluster DNS
- enough capacity for the selected profile
- registry connectivity or images preloaded into every relevant node

The default standalone storage requests are:

| Claim | Requested size |
|---|---:|
| VictoriaMetrics | 20 GiB |
| Grafana | 2 GiB |
| AIB | 5 GiB |
| VIB | 10 GiB |
| CIB | 10 GiB |
| TIB | 5 GiB |

Adjust these values for retention, workload count, and vulnerability volume.

## 7. Pre-deployment planning

Before installation, record:

1. deployment mode: Docker Compose or Kubernetes;
2. Docker host, or destination cluster and explicit kubeconfig context;
3. namespace and Helm release name when using Kubernetes;
4. storage capacity and retention;
5. connected or disconnected operating mode;
6. internal registry hostname and trust configuration;
7. outbound proxy or egress policy, if applicable;
8. image and feed mirror locations;
9. Grafana credential ownership;
10. Authentik URL and token if IIB is enabled;
11. TLS endpoints if PIB is enabled; and
12. backup and retention requirements.

Always use `--kube-context` on Helm commands and `--context` on kubectl commands
when the operator workstation can access more than one cluster.

## 8. Connected deployment

### 8.1 Docker Compose

Clone the repository; submodules are not required:

```bash
git clone https://github.com/iareanthony/xib.git
cd xib
cp .env.example .env
```

Before startup, replace `XIB_GRAFANA_PASSWORD=CHANGE_ME` in `.env`. Review
`BIND_ADDR`, retention, scan intervals, and `XIB_SCAN_IMAGES`. Also review
`XIB_CONTAINER_PREFIX` if more than one XIB stack will run on the same Docker
host. Containers use deterministic names such as `xib-grafana`, `xib-vib`, and
`xib-victoriametrics`; changing the prefix prevents collisions between stacks.
Start and verify:

```bash
docker compose pull
docker compose up -d
make smoke
docker compose ps
```

Grafana is available at `http://localhost:4000` by default. The one-shot
`initialize-volumes` container must exit with status zero; this is normal and
prepares non-root collector volume ownership.

Enable optional monitors only after configuring their inputs in `.env`:

```bash
docker compose --profile pki --profile identity up -d
```

- `PIB_ENDPOINTS` is a comma-separated list of TLS hosts or `host:port` targets.
- `AUTHENTIK_URL` and `AUTHENTIK_TOKEN` connect IIB to an existing Authentik.

Use `docker compose logs -f vib cib tib grafana` for troubleshooting. VIB and
CIB combine `XIB_SCAN_IMAGES` with images discovered on the Docker host.

#### Docker socket discovery

The default deployment mounts the host socket only into an internal Docker
socket proxy. The proxy publishes no host port and permits only the container,
image, info, version, and ping read APIs. VIB and CIB connect to that proxy over
the private Compose network.

For troubleshooting on a trusted Linux Docker host, enable the direct-socket
bypass with the opt-in overlay:

```bash
echo "DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)" >> .env
make up-socket
```

The bypass mounts `/var/run/docker.sock` into VIB and CIB, points their Docker
clients at it, and adds its numeric group owner to the non-root collector
processes.

Treat Docker socket access as host-root-equivalent. A read-only bind mount does
not make Docker API operations read-only. Do not enable the bypass on a shared
or untrusted host. Validate the merged definition before use:

```bash
docker compose -f docker-compose.yml -f docker-compose.socket.yml config --quiet
```

### 8.2 Kubernetes

Clone XIB and select the intended release branch or tag:

```bash
git clone https://github.com/iareanthony/xib.git
cd xib
```

Validate the chart without changing the cluster:

```bash
helm lint ./k8s
helm template xib ./k8s \
  --namespace xib-system \
  --kube-context <context> > rendered.yaml
```

Run the preflight checks:

```powershell
./airgap/preflight.ps1 -Namespace xib-system
```

Install the standalone profile:

```bash
helm upgrade --install xib ./k8s \
  --kube-context <context> \
  --namespace xib-system \
  --create-namespace \
  --wait \
  --timeout 10m
```

If the cluster has no default StorageClass:

```bash
helm upgrade --install xib ./k8s \
  --kube-context <context> \
  --namespace xib-system \
  --create-namespace \
  --set-string global.storageClass=<storage-class> \
  --wait \
  --timeout 10m
```

## 9. Air-gapped deployment

### 9.1 Connected staging system

Review `airgap/images.txt` and replace release tags with approved immutable
digests where required by policy. Export the images:

```powershell
./airgap/export-images.ps1 -OutputDirectory ./bundle
helm package ./k8s --destination ./bundle
Copy-Item ./k8s/values-airgap.yaml ./bundle/values-airgap.yaml
```

Also stage:

- the Trivy vulnerability database and Java database if Java scanning is used;
- a CISA KEV JSON mirror;
- an EPSS response mirror with the FIRST API's top-level `data` array;
- internal CA certificates for private registries and HTTPS mirrors;
- optional Falco artifacts for the separate SIB release; and
- optional local LLM artifacts.

Transfer the bundle through the approved media-handling process and validate
its checksums on the disconnected side.

### 9.2 Disconnected registry

Load the archive into a Docker or nerdctl runtime:

```powershell
./airgap/import-images.ps1 \
  -Archive ./bundle/xib-images.tar \
  -Runtime nerdctl
```

Alternatively, mirror images into an internal registry:

```powershell
./airgap/mirror-images.ps1 \
  -Registry registry.internal.example/xib
```

Update `values-airgap.yaml` with the internal registry and feed service, then
install:

```powershell
./airgap/install.ps1 \
  -Release xib \
  -Namespace xib-system \
  -Registry registry.internal.example/xib
```

No pod should attempt an external download during disconnected operation.
Validate this with cluster egress logs or an explicit deny-all egress policy in
a pre-production environment.

### 9.3 Disconnected Docker Compose

On the connected staging system, create both image and supporting-artifact
archives. Add `-IncludeOllamaModel` only when the selected model is approved and
the transfer medium has sufficient capacity:

```powershell
./airgap/export-images.ps1 -OutputDirectory ./bundle
./airgap/populate-artifacts.ps1 -OutputDirectory ./bundle
```

On the disconnected Docker host, verify `bundle/SHA256SUMS`, then load the OCI
archives before starting Compose:

```bash
docker load --input bundle/xib-images.tar
docker load --input bundle/xib-artifact-images.tar
docker compose up -d
make smoke
```

Serve the bundled CISA and EPSS data from an approved internal HTTP endpoint
and set `CISA_KEV_URL` and `EPSS_API_URL` in `.env`. Pre-populate or mount the
bundled Trivy cache before denying egress. Confirm with firewall logs that no
container attempts to reach an external registry, database, or feed.

## 10. Optional component configuration

### 10.1 IIB

IIB monitors an existing Authentik installation. Create a read-only Authentik
API token Secret:

```bash
kubectl --context <context> -n xib-system create secret generic authentik-iib-monitor \
  --from-literal=token='<read-only-token>'
```

Set the Authentik service URL and enable IIB:

```bash
helm upgrade xib ./k8s \
  --kube-context <context> \
  --namespace xib-system \
  --set iib.enabled=true \
  --set-string iib.authentikUrl=http://authentik-server.authentication.svc:80 \
  --set-string iib.existingSecret=authentik-iib-monitor \
  --wait
```

### 10.2 PIB

PIB monitors configured TLS endpoints; it does not replace cert-manager or a
certificate authority unless the operator deliberately deploys those services
separately. Set the endpoint inventory and enable PIB only after its immutable
collector image is available in the selected registry.

### 10.3 SIB

SIB is intentionally managed as a separate runtime-security deployment because
Falco requires kernel, host, API-server, and artifact permissions outside the
normal XIB collector trust boundary.

For Docker, XIB vendors the Apache-2.0 `iareanthony/sib` fork at commit
`af84d2f26081dbc80d23e6830d1855082ecc274e`. The default `.env.example`
activates the `sib` Compose profile, so the complete Docker environment starts
without Make or a secondary repository checkout:

```bash
cp .env.example .env
docker compose up -d
docker compose ps
docker compose logs -f sib-falco sib-sidekick
```

The main `docker-compose.yml` deploys Falco, Falcosidekick, VictoriaLogs,
VictoriaMetrics, and node-exporter. It does not deploy a second Grafana. The
existing XIB Grafana joins the SIB network, installs the VictoriaLogs datasource
plugin, and provisions the pinned SIB package's datasources and dashboards into the
**SIB Runtime Security** folder at port `3000`. SIB endpoints use VictoriaLogs
`9428`, VictoriaMetrics `8429`, and Falcosidekick `2801`. Operators can set
`COMPOSE_PROFILES=` to omit SIB or invoke it explicitly with
`docker compose --profile sib up -d`.

SIB Falco runs privileged, mounts `/dev`, `/proc`, `/etc`, and the Docker
socket, and uses modern eBPF. Treat it as host-root-equivalent. It requires a
supported Linux kernel and does not support Docker Desktop.

For Kubernetes, the vendored `sib-k8s` chart is an enabled dependency of the
main XIB Helm release. A normal XIB install therefore adds the Falco DaemonSet,
the generic Kubernetes audit receiver, Falcosidekick, and Loki. The existing
XIB Grafana provisions Loki as a datasource and loads the SIB dashboards into
the **SIB Runtime Security** folder. Set `sib.enabled=false` only when the cluster
already has equivalent runtime monitoring. The optional AI analyzer remains
disabled until an operator configures an LLM endpoint.

## 11. Post-deployment validation

Check workloads and storage:

```bash
kubectl --context <context> -n xib-system get pods,deploy,svc,pvc
```

Expected conditions:

- selected Deployments have available replicas;
- pods are `Running` with zero unexpected restarts;
- all required PVCs are `Bound`;
- services have EndpointSlices; and
- AIB, VIB, CIB, and TIB logs show completed startup work.

Check AIB:

```bash
kubectl --context <context> -n xib-system logs deployment/xib-xib-aib
```

Look for a completed startup scan and non-zero asset counts.

Check VIB:

```bash
kubectl --context <context> -n xib-system logs deployment/xib-xib-vib
```

Look for Kubernetes image discovery, completed registry scans, and metrics
pushes. Images that exist only in a node cache and not in a registry cannot be
pulled by Trivy using a reference alone; publish or mirror those images.

Check CIB and TIB:

```bash
kubectl --context <context> -n xib-system logs deployment/xib-xib-cib
kubectl --context <context> -n xib-system logs deployment/xib-xib-tib
```

Look for completed SBOM/license checks, KEV synchronization, VIB CVE retrieval,
and threat-intelligence correlation.

Access Grafana temporarily:

```bash
kubectl --context <context> -n xib-system \
  port-forward service/xib-xib-grafana 3000:3000
```

Read generated credentials:

```bash
kubectl --context <context> -n xib-system \
  get secret xib-xib-grafana-admin \
  -o jsonpath='{.data.admin-user}' | base64 -d

kubectl --context <context> -n xib-system \
  get secret xib-xib-grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

Verify that the **XIB** folder contains all six provisioned dashboards.

## 12. Routine operations

### 12.1 Daily

- review pod availability and restart counts;
- review failed or stale VIB, CIB, and TIB scan indicators;
- inspect critical vulnerabilities and KEV matches;
- confirm metrics ingestion remains current; and
- investigate image-pull and feed-mirror failures.

### 12.2 Weekly

- review storage utilization and retention;
- review newly discovered assets and workload images;
- verify offline mirror freshness where applicable;
- review CIB license and EOL findings; and
- confirm backups can be read.

### 12.3 Per release

- pin image digests;
- generate and retain an image manifest and checksums;
- scan the release images and Helm package;
- validate in a disposable cluster;
- validate in a representative pre-production cluster;
- record configuration changes and upgrade notes; and
- retain the prior release bundle for rollback.

## 13. Backup and recovery

Back up the PVC data for:

- VictoriaMetrics, which holds historical security metrics;
- Grafana, which holds users and UI-created changes;
- AIB, which holds the asset graph database;
- TIB, which holds synchronized feed and correlation state; and
- VIB/CIB data when local cache or evidence retention is required.

Use storage-native snapshots or a Kubernetes backup system consistent with the
destination platform. Protect backups as security-sensitive operational data.

Provisioned dashboards and datasources are stored in Git and do not depend on a
Grafana database backup. UI edits to provisioned dashboards should be exported
and committed before rebuilding Grafana.

## 14. Upgrades

### 14.1 Docker Compose

Back up the named volumes, pull the selected repository release, verify that
the digest lock changed as expected, and recreate services:

```bash
git pull --ff-only
docker compose pull
docker compose up -d
make smoke
```

Do not use `docker compose down -v` during an upgrade; `-v` deletes persistent
metrics, Grafana state, caches, and collector data.

### 14.2 Kubernetes

1. Review the release notes, image manifest, chart diff, and new permissions.
2. Back up persistent data.
3. Render the new chart and compare it with the installed release.
4. Test the exact values in a disposable cluster.
5. Run the Helm upgrade with `--wait` and an explicit context.
6. Validate pods, PVCs, logs, datasource health, and dashboards.

Example:

```bash
helm upgrade xib ./k8s \
  --kube-context <context> \
  --namespace xib-system \
  --values values-site.yaml \
  --wait \
  --timeout 10m
```

Generated Grafana credentials are preserved across upgrades. Do not delete and
recreate the Grafana Secret independently of its persistent database unless the
admin password is also reset in Grafana.

## 15. Rollback

For Docker Compose, check out the prior approved XIB tag or commit, load its
image archive if disconnected, and run `docker compose up -d`. Persistent data
formats may not be backward-compatible; restore volume backups when required.

For Kubernetes, list release history:

```bash
helm --kube-context <context> -n xib-system history xib
```

Rollback chart-managed resources:

```bash
helm --kube-context <context> -n xib-system rollback xib <revision> \
  --wait --timeout 10m
```

Helm rollback does not downgrade persistent data formats automatically. Consult
component release notes before rolling back across a storage-schema change.

## 16. Removal

Stop Docker Compose while retaining persistent volumes:

```bash
docker compose down
```

Use `docker compose down -v` only when permanent deletion of XIB's Docker data
is explicitly intended and backups have been verified.

Remove the Kubernetes release:

```bash
helm --kube-context <context> -n xib-system uninstall xib
```

PVCs may remain depending on Kubernetes and chart behavior. Confirm backup and
retention requirements before deleting them:

```bash
kubectl --context <context> -n xib-system get pvc
```

Delete the namespace only after verifying that it contains no shared resources:

```bash
kubectl --context <context> delete namespace xib-system
```

For the disposable reference environment, delete the entire k3d cluster:

```bash
k3d cluster delete xib-test
```

## 17. Known limitations

- IIB requires an existing Authentik service and API token.
- PIB requires a published collector image and an operator-defined endpoint
  inventory.
- SIB/Falco is installed as a separate release.
- Node-cache-only image references cannot be scanned from a registry until they
  are published or mirrored.
- Trivy and threat-intelligence data must be refreshed through controlled
  mirrors in disconnected environments.
- The existing-platform profile requires site-specific Grafana and Prometheus
  integration validation.

## 18. Reference validation environment

The initial Kubernetes distribution was validated in an ephemeral k3d cluster
on Pop!_OS 24.04 with one server and one agent node. The validated core profile
ran AIB, VIB, CIB, TIB, VictoriaMetrics, and Grafana concurrently with no pod
restarts. It demonstrated:

- AIB live Kubernetes inventory;
- Kubernetes-native VIB and CIB image discovery without a Docker socket;
- registry-backed Trivy scanning;
- CISA KEV synchronization and VIB correlation;
- persistent storage binding;
- stable Grafana credentials across Helm upgrades; and
- provisioning of all six Grafana dashboards.

This reference test demonstrates functional integration. Each destination
cluster still requires capacity, storage, network, registry, policy, backup,
and disaster-recovery validation appropriate to its mission.
