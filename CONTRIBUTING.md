# Contributing

## Workflow

1. Create a focused branch from the default branch.
2. Explain the operational impact of chart changes in the pull request.
3. Add or update a test for every changed rendering path.
4. Run the required Helm checks locally.
5. Keep commits small and describe breaking values changes explicitly.

## Pull request checklist

- [ ] `helm lint` passes.
- [ ] `helm template` passes with TLS enabled.
- [ ] `helm unittest` passes.
- [ ] `values.schema.json` is updated when values are added or changed.
- [ ] README or `docs/` is updated for user-visible behavior.
- [ ] Image tags are pinned, or the reason for a rolling tag is documented.
- [ ] No secrets, generated manifests, `.tgz` packages, or
      `.codebase-memory/` artifacts are included.

## Chart compatibility

The chart deploys a single OpenTAKServer instance. Changes must preserve the
shared `/app/ots` volume semantics, PostGIS requirement, RabbitMQ integration,
and the distinction between HTTP Ingress traffic and layer-4 TAK streaming.

## Security

Use existing Kubernetes Secrets for production credentials whenever possible.
Do not put credentials in `values.yaml`, examples, issue comments, or commits.
Security-sensitive changes should include a note in `docs/security.md`.

## Releases

Chart releases use tags in the form `chart-v<version>`. The tag version must
match `Chart.yaml`; the publish workflow checks this before pushing to GHCR.
