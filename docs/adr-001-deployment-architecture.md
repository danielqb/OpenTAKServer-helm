# ADR-001: Single-instance OpenTAKServer deployment

## Status

Accepted

## Decision

Run the tightly coupled OpenTAKServer processes in one StatefulSet pod with a
shared `ReadWriteOnce` data volume. Deploy the Web UI separately. Keep PostGIS
and RabbitMQ as first-party StatefulSets unless external services are selected.

## Context

The application shares `/app/ots`, maintains state in its socket handlers, and
does not support horizontal scaling of the server process. Database migrations
require PostGIS, while the RabbitMQ setup includes MQTT and the HTTP auth
backend expected by OpenTAKServer.

## Consequences

This preserves upstream behavior and keeps the chart portable, but the server
has a single active replica and upgrades cause brief downtime. Availability for
the data and database PVCs must be provided through storage and backup policy,
not by increasing the server replica count.
