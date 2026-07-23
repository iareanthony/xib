# XIB — Security in a Box

Umbrella project that composes all **in-a-box** security tools into a single stack with a unified Grafana posture dashboard.

XIB can run through Docker Compose or as a portable Kubernetes deployment. The
Kubernetes chart includes standalone, existing-platform, and air-gapped
profiles; see [Kubernetes and air-gapped deployment](docs/kubernetes-airgap.md).
For the operating model and complete deployment lifecycle, see the
[XIB Concept of Operations](docs/CONOPS.md).

![Dashboard preview](docs/dashboard-preview.png)

```
make up
```

That starts VIB, CIB, TIB, SIB runtime detection, VictoriaMetrics, and the
unified Grafana. The PIB and IIB monitors are optional profiles because they
require TLS targets or an existing Authentik deployment.

The Compose deployment uses the same immutable collector images as Kubernetes.
SIB is included as a pinned package and initialized automatically by `make up`.

---

## Architecture

```
xib/
├── vib/   ← Vulnerability in a Box  (Trivy scanner + CVE metrics)
├── tib/   ← Threat Intel in a Box   (CISA KEV + EPSS cross-reference)
├── cib/   ← Compliance in a Box     (SBOM, license, EOL, container policy)
├── iib/   ← Identity in a Box       (Authentik IdP, login metrics)
├── pib/   ← PKI in a Box            (step-ca, TLS cert expiry monitor)
├── sib/   ← SIEM in a Box           (Falco runtime detection + VictoriaLogs)
└── ...    ← XIB Grafana (unified XIB and SIB dashboards)
```

The Docker deployment is defined entirely in this repository and connects all collectors to one VictoriaMetrics service and one provisioned Grafana service.

---

## Quick start

```bash
git clone --recurse-submodules https://github.com/iareanthony/xib.git
cd xib
make up
```

### Kubernetes

```bash
helm upgrade --install xib ./k8s -n xib-system --create-namespace
```

The Helm release includes SIB-K8s by default: Falco runtime monitoring,
Falcosidekick, Loki, and SIB dashboards provisioned into the existing XIB
Grafana. Disable it only when the
cluster already has an equivalent runtime-detection stack:

```bash
helm upgrade --install xib ./k8s -n xib-system --create-namespace \
  --set sib.enabled=false
```

### Environment root CAs

For a Kubernetes environment with TLS interception or private certificate
authorities, copy the environment's PEM root CA bundle into the chart before
installing:

```bash
cp /path/to/environment-root-cas.pem k8s/custom-ca/ca.crt
helm upgrade --install xib ./k8s -n xib-system --create-namespace
```

Helm detects the file, creates the ConfigMap, and enables the combined trust
bundle automatically. The certificate is ignored by Git. For GitOps or a
centrally managed CA ConfigMap, leave the directory empty, create the ConfigMap
with the required shared name, and set:

```bash
kubectl -n xib-system create configmap xib-environment-ca \
  --from-file=ca.crt=/path/to/environment-root-cas.pem

--set-string global.trustedCa.existingConfigMap=xib-environment-ca
```

XIB appends the supplied certificates to the public CA bundle and provides the
combined bundle to its HTTPS clients. For Docker Compose on Linux:

```bash
XIB_ROOT_CA=/path/to/environment-root-cas.pem make up-ca
```

The generated combined bundle is kept under the ignored `.xib/` directory and
is not committed to the repository. `XIB_ROOT_CA` may alternatively be set in
the deployment's `.env` file.

For a disconnected cluster, prepare the image archive on a connected staging
machine with `airgap/export-images.ps1`, transfer the resulting bundle, mirror
or load the images, and install with `airgap/install.ps1`.

Open **http://localhost:4000** — the XIB Security Overview dashboard loads automatically.

### Docker image discovery

The default deployment discovers all containers and images on the Docker host
through an internal socket proxy. The proxy publishes no host port and permits
only the read-only container, image, info, version, and ping API endpoints.
VIB and CIB never receive the Docker socket itself.

For troubleshooting on a trusted Linux host, the direct-socket overlay remains
available as an explicit bypass:

```bash
echo "DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)" >> .env
make up-socket
```

Validate the bypass with `docker compose -f docker-compose.yml -f
docker-compose.socket.yml config --quiet`. Direct Docker socket API access is
effectively host-root access even with a read-only bind mount, so use the
bypass only for trusted images and operators.

Optional monitors can be enabled after their settings are added to `.env`:

```bash
docker compose --profile pki --profile identity up -d
```

### SIB runtime detection

Docker SIB is included as the pinned
[`iareanthony/sib`](https://github.com/iareanthony/sib) package and is part of
the main Compose application. `make up` initializes the package automatically.
A normal deployment from `.env.example` starts it:

```bash
cp .env.example .env
docker compose up -d
```

SIB dashboards and datasources are provisioned into the existing XIB Grafana
at `http://localhost:4000`; no second Grafana is deployed. VictoriaLogs uses
port `9428`, VictoriaMetrics `8429`, and Falcosidekick `2801`. The equivalent
explicit command is `docker compose --profile sib up -d`. Set
`COMPOSE_PROFILES=` in `.env` to omit SIB.
SIB requires a Linux host and privileged kernel/eBPF access; Docker Desktop is
not supported.

---

## Configuration

The XIB `.env` file is created from `.env.example` on first `make up`. Docker
SIB uses the same `.env` and main `docker-compose.yml`.

To customise the unified Grafana:

```bash
cp .env.example .env
# Edit XIB_GRAFANA_PASSWORD
make up
```

---

## Unified dashboard

The **XIB Security Overview** (`uid: xib-overview`) aggregates data from all five tools:

**Vulnerabilities & Threat Intel** (VIB + TIB)
- Critical / High CVE counts
- CVEs matched in CISA KEV catalog
- CVEs over time by severity

**Compliance** (CIB)
- Container policy violations
- License violations
- EOL components
- Containers checked

**Identity & PKI** (IIB + PIB)
- Active users, login failures
- Certs expiring within 30 days, expired certs
- Cert days remaining over time
- Login events over time

**Sync Status**
- Last sync timestamp for all five tools

---

## Makefile targets

| Target | Description |
|--------|-------------|
| `make up` | Start the full stack (runs setup first) |
| `make down` | Stop the full stack |
| `make restart` | Restart all services |
| `make build` | Rebuild all custom images |
| `make logs` | Follow all service logs |
| `make setup` | Create sub-project .env files and generate secrets |
| `make update` | Pull latest commits on all submodules |
| `make pull-submodules` | Init/clone submodules (for repos checked out without --recurse-submodules) |
| `make clean` | Stop everything and delete all volumes |

---

## Updating sub-projects

Each sub-project is pinned to a specific commit. To move all submodules to their latest `master`:

```bash
make update
make up
```

To update a single sub-project:
```bash
git submodule update --remote --merge vib
```

---

## Running tools standalone

Every sub-project is independently deployable:

```bash
cd vib
make up
```

XIB adds no dependencies to the individual tools — they function identically with or without the umbrella.

---

## License

MIT
