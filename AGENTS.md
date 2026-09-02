# AGENTS.md

## Scope

This repository contains the OpenTAKServer Helm chart and its vendored
`charts/common` library. Changes should preserve Helm 3 compatibility and the
single-instance deployment model documented in `README.md`.

## Repository rules

- Do not commit secrets, kubeconfigs, rendered manifests, or `.codebase-memory/`.
- Keep `Chart.lock` synchronized with `Chart.yaml` when dependencies change.
- Prefer immutable container image digests for production examples.
- Keep chart values documented with Bitnami-style `## @param` comments.
- Do not scale the OpenTAKServer StatefulSet horizontally: its processes share
  state and a `ReadWriteOnce` data volume.
- Keep `charts/common` vendored unless the dependency strategy is deliberately
  changed and documented.

## Required checks

Before opening a pull request, run:

```console
helm lint . --strict --set opentakserver.fqdn=example.invalid --set ingress.tlsSecret=example-tls
helm template opentakserver . --set opentakserver.fqdn=example.invalid --set ingress.tlsSecret=example-tls
helm unittest .
```

The `--strict` flag and `values.schema.json` are what CI enforces; keep the
schema in sync when values are added, removed, or retyped.

For changes affecting networking, persistence, security contexts, or external
services, also render the relevant values combination and update the matching
documentation or test.

## Codebase analysis

`codebase-memory` may be used locally for architectural analysis. Its generated
artifacts are intentionally local and must not be added to Git.
