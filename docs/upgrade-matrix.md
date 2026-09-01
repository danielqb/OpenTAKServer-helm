# Upgrade matrix

`Chart.yaml` contains the chart version and `appVersion` identifies the
OpenTAKServer release targeted by the default image tags. Before upgrading:

1. Back up all PVCs and verify the restore procedure.
2. Review upstream OpenTAKServer release notes and database migration changes.
3. Render the chart with the production values and inspect image tags/digests,
   ports, probes, and security contexts.
4. Upgrade during a maintenance window: the single server pod has brief
   downtime while it reacquires its `ReadWriteOnce` volume.
5. Run `helm test` and verify the Web UI, API health endpoint, TAK streaming,
   certificates, and video paths.
