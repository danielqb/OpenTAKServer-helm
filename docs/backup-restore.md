# Backup and restore

Back up these persistent volumes independently:

- OpenTAKServer data: CA material, configuration, uploads, logs, and video.
- PostGIS: application database and migrations.
- RabbitMQ: broker state and queued messages.

For production, prefer storage snapshots or a Kubernetes backup system that
preserves PVCs and Secrets. Test restores into a separate namespace before a
release upgrade. Restore the database before starting the server if the data
volume contains configuration that references it. Never commit exported
Secrets to this repository.
