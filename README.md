# OpenTAKServer Helm chart

Helm chart for [OpenTAKServer](https://opentakserver.io) (OTS) — a self-hosted TAK
server for ATAK / iTAK / WinTAK clients. It packages the full stack described by the
official [`OpenTAKServer-Docker`](https://github.com/brian7704/OpenTAKServer-Docker)
compose file. The OpenTAKServer container image comes from the atalaya fork
([`danielqb/OpenTAKServer`](https://github.com/danielqb/OpenTAKServer), branch
`atalaya-1.7.13`) because upstream's `ghcr.io/brian7704/*` images are built off a
moving branch and mislabel their version (see below); supporting images
(MediaMTX, PostGIS, RabbitMQ, nginx, web UI) are the upstream ones.

The chart follows the conventions of the Bitnami [`common`](https://github.com/bitnami/charts/tree/main/bitnami/common)
library chart (values layout, naming, labels, image and secret helpers), which it pulls as
its only subchart. PostGIS and RabbitMQ are shipped as small first-party StatefulSets using
their official upstream images — see the notes below.

## TL;DR

This chart is published (public, no login needed) to
`oci://ghcr.io/danielqb/charts/opentakserver` on every push to `main` that
touches `Chart.yaml`/`values.yaml`/`templates/**`
(`.github/workflows/publish-chart.yml`, triggered by a `chart-v*` tag - see
that workflow for how the tag maps to a chart version). Install straight
from there, no local checkout needed:

```console
helm install ots oci://ghcr.io/danielqb/charts/opentakserver --version 0.1.0 \
  --namespace opentakserver --create-namespace \
  --set opentakserver.fqdn=tak.example.com \
  --set ingress.certManager.enabled=true \
  --set ingress.certManager.clusterIssuer=letsencrypt-prod
```

Or from a local checkout:

```console
git clone https://github.com/danielqb/OpenTAKServer-helm.git && cd OpenTAKServer-helm
helm dependency build
helm install ots . \
  --namespace opentakserver --create-namespace \
  --set opentakserver.fqdn=tak.example.com \
  --set ingress.certManager.enabled=true \
  --set ingress.certManager.clusterIssuer=letsencrypt-prod
```

Then log in to `https://tak.example.com` with **administrator / password** and change
the password immediately.

There's no image to build for this chart itself. The OpenTAKServer server
(`ghcr.io/danielqb/opentakserver`) and web UI (`ghcr.io/danielqb/opentakserver-ui`)
come from the atalaya forks, pinned by digest; the rest are upstream images
(`bluenviron/mediamtx`, `nginxinc/nginx-unprivileged`, `postgis/postgis`,
`library/rabbitmq`).
See "Database and broker" below for why PostGIS/RabbitMQ are first-party
StatefulSets rather than Bitnami subcharts.

## Architecture

OpenTAKServer is a **single-instance** application (in-process scheduler, stateful
socket handlers, a shared data folder). The tightly-coupled processes therefore run
as containers in **one StatefulSet pod** that shares a single `ReadWriteOnce` PVC
mounted at `/app/ots`:

| Container         | Image                                                     | Purpose                                    |
|-------------------|-----------------------------------------------------------|--------------------------------------------|
| `opentakserver`   | `ghcr.io/danielqb/opentakserver`                          | REST / CoT / Marti API on `:8081`          |
| `cot-parser`      | `ghcr.io/danielqb/opentakserver` — `cot_parser`           | CoT message processing                     |
| `eud-handler`     | `ghcr.io/danielqb/opentakserver` — `eud_handler --no-ssl` | Plaintext TCP CoT streaming `:8088`        |
| `eud-handler-ssl` | `ghcr.io/danielqb/opentakserver` — `eud_handler --ssl`    | Mutual-TLS CoT streaming `:8089`           |
| `mediamtx`        | `bluenviron/mediamtx`                                     | Video (RTSP/RTMP/HLS/WebRTC/SRT) — sidecar |
| `nginx-proxy`     | `nginxinc/nginx-unprivileged`                             | Optional TAK edge proxy — sidecar          |

All four OpenTAKServer processes run **one image**, pinned by digest — the
atalaya fork's `ghcr.io/danielqb/opentakserver`, built from the OpenTAKServer
1.7.13 tag. Upstream's `ghcr.io/brian7704/ots_cot_parser` / `ots_eud_handler[_ssl]`
images are not used: they install the code with `pip install git+…@docker`, a
branch frozen at `1.5.14`, so their `1.7.x` tags are mislabelled. That one image
contains the `cot_parser` and `eud_handler` console scripts, so the chart just
overrides each sidecar's command (`server.cotParser.command`,
`server.eudHandler.command` / `.args`, etc.).

Deployed separately:

| Component    | Kind        | Notes                                                        |
|--------------|-------------|-------------------------------------------------------------|
| Web UI       | Deployment  | `ghcr.io/danielqb/opentakserver-ui` (fork, UI `v1.7.5`), stateless, scalable |
| PostGIS      | StatefulSet | `postgis/postgis` — **required**, plain PostgreSQL will not work |
| RabbitMQ     | StatefulSet | official `rabbitmq` image with the MQTT plugin + HTTP auth backend |

The application auto-runs its database migrations and generates its Certificate
Authority on first boot — there is no separate init Job. The server pod has a
`wait-for-dependencies` init container that blocks until PostGIS and RabbitMQ accept
connections (OpenTAKServer has no reconnect on its first broker connection).

### Networking

* **`ingress`** (enabled by default) exposes the browser-facing Web UI and REST /
  socket.io API over HTTPS. Path prefixes in `ingress.apiPaths` (`/api`,
  `/socket.io`, `/Marti`) are routed to the API service; `/hls` and `/webrtc` to
  MediaMTX; everything else to the Web UI. TLS is provided by `ingress.tlsSecret`
  or cert-manager (`ingress.certManager.*`).
* **`streamingService`** (a `LoadBalancer` by default) exposes the layer-4 TAK
  ports that an Ingress cannot handle: `8088` (TCP CoT), `8089` (SSL CoT), and —
  when `nginxProxy.enabled=true` — `8443` / `8446` / `8883`.
* **`mediamtx.service`** (a `LoadBalancer` by default) exposes the video protocols.

### nginx-proxy (optional, off by default)

The upstream compose ships an nginx reverse proxy that terminates TLS for the
TAK-specific ports using the OTS-generated CA:

* `8443` — Marti API with **mandatory client-certificate** (mutual TLS) for data sync
* `8446` — automatic certificate **enrollment** for ATAK/iTAK
* `8883` — MQTTS → RabbitMQ

A standard Kubernetes Ingress cannot express client-certificate enrollment, so this
component is provided as a sidecar for deployments that need native ATAK/iTAK
enrollment. Enable it with `--set nginxProxy.enabled=true`; its ports are then added
to `streamingService`.

## Database and broker — why first-party, not Bitnami subcharts

**PostGIS:** OpenTAKServer's schema migrations use PostGIS / `geoalchemy2` types, so the
database **must** have the PostGIS extension. The Bitnami PostgreSQL container image does
not bundle PostGIS and its Helm chart is tightly coupled to the Bitnami image layout, so
this chart ships a small first-party StatefulSet based on the official `postgis/postgis`
image (the same image used by the upstream compose).

**RabbitMQ:** the `bitnami/rabbitmq` subchart was the original plan, but as of the Bitnami
catalogue change (August 2025) the versioned `docker.io/bitnami/rabbitmq` image tags were
removed from the free registry, which breaks that chart out of the box. This chart instead
runs the official `rabbitmq:*-management` image wired exactly like the upstream compose
(`rabbitmq_mqtt` + `rabbitmq_auth_backend_http` plugins, MQTT listener on 1883, HTTP auth
backend against OpenTAKServer).

To use an external database instead:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: my-postgis.db.svc
  port: 5432
  user: ots
  database: ots
  existingSecret: my-postgis-credentials
  existingSecretPasswordKey: password
```

The external server must have PostGIS available (`CREATE EXTENSION postgis`). A
CloudNativePG or Crunchy PGO cluster running a PostGIS image works well.

## Secrets

`SECRET_KEY`, the CA password and the MediaMTX token are generated on first install
and persisted in the `<release>-secrets` Secret (via `common.secrets.passwords.manage`,
so they survive upgrades). Provide your own with `opentakserver.secretKey`,
`opentakserver.ca.password`, `mediamtx.apiToken`, or a fully pre-populated
`opentakserver.existingSecret` (keys: `secret-key`, `ca-password`, `mediamtx-token`).

The bundled PostGIS and RabbitMQ passwords are likewise auto-generated and persisted.

## Persistence

| PVC                     | Default size | Access mode      | Contents                              |
|-------------------------|--------------|------------------|---------------------------------------|
| `<release>-data`        | 20Gi         | `ReadWriteOnce`  | CA, config.yml, uploads, logs, video  |
| PostGIS `data`          | 10Gi         | `ReadWriteOnce`  | database                              |
| RabbitMQ                | 8Gi          | `ReadWriteOnce`  | message broker state                  |

`ReadWriteOnce` is sufficient because every process that writes to `/app/ots` runs
in the same pod. Only switch `persistence.accessModes` to `ReadWriteMany` if you
split the components across pods.

## Common configuration

```yaml
opentakserver:
  fqdn: tak.example.com          # REQUIRED - written to OTS_FQDN and used by the Ingress
  debug: false
  extraEnvVars:                  # any OTS_* setting from opentakserver/defaultconfig.py
    - name: OTS_ENABLE_EMAIL
      value: "false"

ingress:
  enabled: true
  ingressClassName: nginx
  certManager:
    enabled: true
    clusterIssuer: letsencrypt-prod

streamingService:
  type: LoadBalancer
  externalTrafficPolicy: Local   # preserve TAK client source IPs

mediamtx:
  enabled: true
nginxProxy:
  enabled: false                 # set true for ATAK certificate enrollment / mTLS Marti
```

Post-install, settings can also be changed from the Web UI admin panel; OpenTAKServer
persists them to `config.yml` on the data PVC, which then takes precedence over the
environment variables set by the chart.

### Gateway API

`gateway` is an independent alternative to `ingress` - enable either, both,
or neither. It carries the same path split as the Ingress (`gateway.apiPaths`
→ the API service, `/hls`/`/webrtc` → mediamtx when enabled, everything else
→ the web UI) as one `HTTPRoute` with multiple `rules`. Unlike Ingress, TLS is
a property of the *Gateway's own listener*, not this route - there's no
`gateway.tls`/`certManager` here, because a shared Gateway is usually
provisioned and TLS-terminated by a platform team, not by each app's chart.
Point `gateway.parentRefs` at an existing listener; this chart never creates
the `Gateway` resource itself.

```yaml
gateway:
  enabled: true
  hostname: tak.example.com   # falls back to ingress.hostname, then opentakserver.fqdn
  parentRefs:
    - name: my-gateway
      namespace: gateway-infra   # omit to default to this release's namespace
      sectionName: https         # omit to attach to every listener
```

`gateway.filters` is a free-form list of Gateway API `HTTPRouteFilter`
objects, rendered as-is onto the API and web UI rules (not the MediaMTX
rules). Use it for anything the spec allows - header rewriting, redirects,
URL rewrites, request mirroring. One common case: when the route is reached
through a different hostname than the one OpenTAKServer must advertise in the
QR codes / data packages it generates (it derives those from the request
`Host`), pin the forwarded host:

```yaml
gateway:
  enabled: true
  hostname: tak.internal.example      # how clients reach the route
  filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        set:
          - name: X-Forwarded-Host
            value: tak.public.example  # what OTS should advertise
          - name: X-Forwarded-Proto
            value: https
```

`gateway.extraRules` appends raw `HTTPRoute` rules after the chart's own, for
routing paths the chart does not model.

## Parameters

See [`values.yaml`](values.yaml) — every parameter is documented inline with a
Bitnami-style `## @param` annotation. Key sections: `global`, `opentakserver`,
`server`, `persistence`, `service` / `streamingService` / `ingress`, `webui`,
`mediamtx`, `nginxProxy`, `postgresql` / `externalDatabase`, `rabbitmq` /
`externalRabbitmq`.

Values are validated by [`values.schema.json`](values.schema.json). Repository
contribution rules are in [`CONTRIBUTING.md`](CONTRIBUTING.md), and deployment
constraints are recorded in [`AGENTS.md`](AGENTS.md).

## Validation

Run the same core checks used by CI:

```console
helm lint . --strict \
  --set opentakserver.fqdn=example.invalid \
  --set ingress.tlsSecret=example-tls
helm template ots . \
  --set opentakserver.fqdn=example.invalid \
  --set ingress.tlsSecret=example-tls
helm unittest .
```

CI also renders the nginx-proxy and external database/RabbitMQ scenarios.

## Upgrading

`helm upgrade` performs a rolling replacement of the single server pod (brief
downtime while the new pod acquires the `ReadWriteOnce` volume). Database migrations
run automatically when the new `opentakserver` container starts.

## Uninstalling

```console
helm uninstall ots -n opentakserver
```

PVCs are retained; delete them manually if you want to discard all data.

## Local testing with kind

`hack/kind-config.yaml` creates a single-node cluster with the `ingress-ready=true`
label and host port mappings (`8080→80`, `8443→443`) expected by ingress-nginx:

```console
kind create cluster --name ots --config hack/kind-config.yaml
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx -n ingress-nginx --create-namespace \
  --set controller.hostPort.enabled=true \
  --set-string controller.nodeSelector."ingress-ready"="true"

helm dependency build   # only needed if you removed charts/common
helm install ots . -n opentakserver --create-namespace \
  --set opentakserver.fqdn=opentak.local \
  --set streamingService.type=ClusterIP \
  --set mediamtx.service.type=ClusterIP
```

Then add `127.0.0.1 opentak.local` to `/etc/hosts` and browse to
`http://opentak.local:8080`.

## Vendored dependency

`charts/common/` (the Bitnami common library) is committed pre-extracted rather than
left as a `.tgz` reference. This keeps `helm install`/`helm template` working without
a network round-trip to the OCI registry, and works around a `helm dependency build`
quirk observed with this repo's toolchain that fails to resolve `.tgz` subcharts. To
refresh it: `rm -rf charts && helm dependency update && (cd charts && for f in *.tgz;
do tar xzf "$f" && rm "$f"; done)`.
