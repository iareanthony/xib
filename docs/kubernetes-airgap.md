# Kubernetes and air-gapped deployment

The `k8s/` chart is the portable deployment layer for XIB. It does not depend
on the `amftech-k8s` namespace, ingress, storage, Authentik, or monitoring
layout.

## Profiles

- Default: deploy one VictoriaMetrics service and one Grafana instance with
  AIB, VIB, CIB, and TIB.
- `values-existing-platform.yaml`: reuse an existing Prometheus Operator and
  Grafana deployment. IIB is enabled and exposed through a `ServiceMonitor`.
- `values-airgap.yaml`: rewrite application image locations to an internal
  registry and point TIB at internally mirrored threat feeds.

PIB and IIB are disabled in the default profile because they require operator
input: PIB needs a list of TLS endpoints and IIB needs an Authentik URL and API
token Secret.

## Connected install

```powershell
helm upgrade --install xib .\k8s --namespace xib-system --create-namespace
```

## Build an offline bundle

On an internet-connected staging machine:

```powershell
.\airgap\export-images.ps1 -OutputDirectory .\bundle
helm package .\k8s --destination .\bundle
Copy-Item .\k8s\values-airgap.yaml .\bundle\values-airgap.yaml
```

Mirror CISA KEV, EPSS, the Trivy vulnerability database, and any optional
Falco/Ollama artifacts into the transfer package. Serve the static feeds from
an internal endpoint and update `values-airgap.yaml` accordingly.

On the disconnected side, either load the archive on every node or push the
images into the cluster's internal registry:

```powershell
.\airgap\import-images.ps1 -Archive .\bundle\xib-images.tar -Runtime nerdctl
.\airgap\install.ps1 -Registry registry.internal.example/xib
```

## Required operator decisions

1. Set a StorageClass if the cluster has no default.
2. Configure `vib.dockerHosts` and `cib.dockerHosts` with reachable Docker API
   endpoints, or provide `additionalImages`. Neither scanner mounts a host
   Docker socket by default.
3. Mirror the Trivy database for VIB/CIB. Runtime database downloads are not
   possible in a fully disconnected cluster.
4. Pin all application images in `airgap/images.txt` to published immutable
   tags or digests before producing a release.
5. Install `sib-k8s` from its vendored chart as a second release when runtime
   and Kubernetes audit monitoring is required.

## Secrets

The chart does not place credentials in values files. Create secrets before
enabling their consumers. For example:

```powershell
kubectl -n xib-system create secret generic authentik-iib-monitor `
  --from-literal=token='<read-only-token>'
```

