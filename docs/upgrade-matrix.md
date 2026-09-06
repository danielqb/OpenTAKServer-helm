# Upgrade matrix

`Chart.yaml` contains the chart version and `appVersion` identifies the
OpenTAKServer release every OTS container runs.

## One image for every OTS process

`server`, `cot-parser`, `eud-handler` and `eud-handler-ssl` all run the single
`ghcr.io/brian7704/opentakserver` image (pinned by digest), each with its own
command. The dedicated `ots_cot_parser` / `ots_eud_handler[_ssl]` images are not
used — upstream builds them from a stale `docker` branch, so their `1.7.x` tags
actually contain OpenTAKServer `1.5.14`. To move to a new OpenTAKServer release,
bump `server.image.tag` **and** `server.image.digest` together (and the matching
`server.cotParser/eudHandler/eudHandlerSsl.image.digest`), then `appVersion`.

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
