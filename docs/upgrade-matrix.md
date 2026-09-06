# Upgrade matrix

`Chart.yaml` contains the chart version and `appVersion` identifies the
OpenTAKServer release every OTS container runs.

## One image for every OTS process

`server`, `cot-parser`, `eud-handler` and `eud-handler-ssl` all run the single
`ghcr.io/danielqb/opentakserver` image (pinned by digest), each with its own
command. This is the **atalaya fork**
([`danielqb/OpenTAKServer`](https://github.com/danielqb/OpenTAKServer)) built from
the OpenTAKServer `1.7.13` tag: upstream's own `ghcr.io/brian7704/*` images install
the code with `pip install git+…@<branch>`, which tracks a moving branch at build
time — that is why `ghcr.io/brian7704/ots_cot_parser:1.7.13` actually contains
OpenTAKServer `1.5.14`.

To move to a new OpenTAKServer release:

1. In `danielqb/OpenTAKServer`, cut an `atalaya-<version>` branch from the upstream
   tag, re-apply the Dockerfile changes if upstream's diverged, and push an
   `atalaya-v<version>` tag to run the `atalaya-images` workflow.
2. Here, bump `server.image.tag` **and** `server.image.digest` together (plus the
   matching `server.cotParser/eudHandler/eudHandlerSsl.image.digest`), then
   `appVersion` and the chart `version`.

Before upgrading:

1. Back up all PVCs and verify the restore procedure.
2. Review upstream OpenTAKServer release notes and database migration changes.
3. Render the chart with the production values and inspect image tags/digests,
   ports, probes, and security contexts. `helm diff upgrade` against the running
   release shows exactly what changes.
4. Upgrade during a maintenance window: the single server pod has brief
   downtime while it reacquires its `ReadWriteOnce` volume.
5. Run `helm test` and verify the Web UI, API health endpoint, TAK streaming,
   certificates, and video paths.
