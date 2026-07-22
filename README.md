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

For a disconnected cluster, prepare the image archive on a connected staging
machine with `airgap/export-images.ps1`, transfer the resulting bundle, mirror
or load the images, and install with `airgap/install.ps1`.

Open **http://localhost:4000** — the XIB Security Overview dashboard loads automatically.

### Optional Docker socket discovery

The default deployment scans `XIB_SCAN_IMAGES` without mounting the host Docker
socket. On a trusted Linux host, enable dynamic local image discovery:

```bash
echo "DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)" >> .env
make up-socket
```

Validate with `docker compose -f docker-compose.yml -f
docker-compose.socket.yml config --quiet`. Docker socket API access is
effectively host-root access even with a read-only bind mount, so enable this
mode only for trusted images and operators.

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
