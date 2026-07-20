# XIB Kubernetes Concept of Operations

## 1. Purpose

Security in a Box (XIB) is a self-hosted security visibility platform for
Kubernetes environments. It combines asset inventory, vulnerability scanning,
compliance analysis, threat-intelligence correlation, identity monitoring,
certificate monitoring, metrics storage, and dashboards in one deployable
package.

This document describes the intended operating environment, deployment
profiles, security boundaries, installation procedures, routine operations,
offline operation, upgrades, rollback, and removal of XIB.

## 2. Operational objectives

XIB is designed to:

- deploy into a dedicated Kubernetes namespace;
- run without privileged containers or host Docker socket mounts;
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

IIB and PIB dashboards are installed even when their collectors are disabled.
Their panels remain empty until the corresponding component is configured.

## 4. Deployment profiles

### 4.1 Standalone

The default `k8s/values.yaml` profile installs XIB-owned VictoriaMetrics and
Grafana services. Use this profile for a new cluster or a self-contained test.

### 4.2 Existing platform

`k8s/values-existing-platform.yaml` disables the XIB-owned metrics and Grafana
services and enables Prometheus Operator integration. Use it when the target
cluster already supplies metrics storage, Grafana, and the `ServiceMonitor`
custom resource.

Before using this profile, review datasource, dashboard sidecar, namespace, and
label requirements in the destination monitoring platform. The supplied values
file is an integration starting point, not a promise that every external
monitoring installation uses the same discovery conventions.

### 4.3 Air-gapped

`k8s/values-airgap.yaml` redirects application images to an internal registry
and redirects TIB to internal CISA KEV and EPSS mirrors. Runtime images and data
artifacts must be staged from a connected system before installation.

### 4.4 Disposable validation

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

### 6.2 Kubernetes cluster

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

1. destination cluster and explicit kubeconfig context;
2. namespace and Helm release name;
3. StorageClass and capacity;
4. connected or disconnected operating mode;
5. internal registry hostname and trust configuration;
6. outbound proxy or egress policy, if applicable;
7. image and feed mirror locations;
8. Grafana credential Secret ownership;
9. Authentik URL and token Secret if IIB is enabled;
10. TLS endpoints if PIB is enabled; and
11. backup and retention requirements.

Always use `--kube-context` on Helm commands and `--context` on kubectl commands
when the operator workstation can access more than one cluster.

## 8. Connected deployment

Clone XIB and select the intended release branch or tag:

```bash
git clone --recurse-submodules https://github.com/iareanthony/xib.git
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

SIB-K8s remains a separate Helm release because Falco and Kubernetes audit
collection have additional kernel, host, API-server, and artifact requirements.
Install the vendored `sib-k8s` chart from the same offline transfer set when
runtime and Kubernetes audit monitoring are required. The XIB `sib` values are
integration metadata, not an embedded Falco installation.

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

List release history:

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

Remove the release:

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
