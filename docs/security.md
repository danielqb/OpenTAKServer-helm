# Security guidance

- Enable TLS on the Ingress and use cert-manager or a pre-created TLS Secret.
- Use `opentakserver.existingSecret` and the external database/broker Secret
  options instead of putting credentials in values files.
- Restrict `streamingService.loadBalancerSourceRanges` and
  `mediamtx.service.loadBalancerSourceRanges` in production.
- Keep `nginxProxy` disabled unless ATAK certificate enrollment or mTLS Marti
  endpoints are required.
- Pin images with digests where reproducibility matters.
- Review the rendered manifests after changing security contexts, host access,
  service types, or exposed ports.
