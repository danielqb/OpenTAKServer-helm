{{/*
Return the chart fullname
*/}}
{{- define "opentakserver.fullname" -}}
{{- include "common.names.fullname" . -}}
{{- end -}}

{{/*
Component fullnames
*/}}
{{/*
The server pod/services use a Release-name-based name (not common.names.fullname) so that
the RabbitMQ subchart's `auth_http.*` URLs in values.yaml can reference it deterministically.
*/}}
{{- define "opentakserver.server.fullname" -}}
{{- printf "%s-server" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opentakserver.webui.fullname" -}}
{{- printf "%s-webui" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opentakserver.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opentakserver.rabbitmq.fullname" -}}
{{- printf "%s-rabbitmq" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "opentakserver.nginxProxy.fullname" -}}
{{- printf "%s-nginx-proxy" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels / selector labels
*/}}
{{- define "opentakserver.labels" -}}
{{ include "common.labels.standard" . }}
{{- end -}}

{{- define "opentakserver.selectorLabels" -}}
{{ include "common.labels.matchLabels" . }}
{{- end -}}

{{/*
ServiceAccount name
*/}}
{{- define "opentakserver.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "common.names.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Main chart-managed Secret (SECRET_KEY, CA password, MediaMTX token)
*/}}
{{- define "opentakserver.secretName" -}}
{{- if .Values.opentakserver.existingSecret -}}
{{- .Values.opentakserver.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Image renderers
*/}}
{{- define "opentakserver.server.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.server.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.cotParser.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.server.cotParser.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.eudHandler.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.server.eudHandler.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.eudHandlerSsl.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.server.eudHandlerSsl.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.webui.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.webui.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.mediamtx.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.mediamtx.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.nginxProxy.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.nginxProxy.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.postgresql.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.postgresql.image "global" .Values.global) -}}
{{- end -}}
{{- define "opentakserver.rabbitmq.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.rabbitmq.image "global" .Values.global) -}}
{{- end -}}

{{- define "opentakserver.imagePullSecrets" -}}
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.server.image .Values.server.cotParser.image .Values.server.eudHandler.image .Values.server.eudHandlerSsl.image .Values.webui.image .Values.mediamtx.image .Values.nginxProxy.image .Values.postgresql.image .Values.rabbitmq.image) "context" $) -}}
{{- end -}}

{{/*
Database helpers
*/}}
{{- define "opentakserver.database.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- include "opentakserver.postgresql.fullname" . -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "opentakserver.database.port" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.service.port -}}
{{- else -}}
{{- .Values.externalDatabase.port -}}
{{- end -}}
{{- end -}}

{{- define "opentakserver.database.name" -}}
{{- if .Values.postgresql.enabled -}}{{- .Values.postgresql.auth.database -}}{{- else -}}{{- .Values.externalDatabase.database -}}{{- end -}}
{{- end -}}

{{- define "opentakserver.database.user" -}}
{{- if .Values.postgresql.enabled -}}{{- .Values.postgresql.auth.username -}}{{- else -}}{{- .Values.externalDatabase.user -}}{{- end -}}
{{- end -}}

{{- define "opentakserver.database.secretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.existingSecret | default (include "opentakserver.postgresql.fullname" .) -}}
{{- else -}}
{{- .Values.externalDatabase.existingSecret | default (printf "%s-externaldb" (include "common.names.fullname" .)) -}}
{{- end -}}
{{- end -}}

{{- define "opentakserver.database.secretPasswordKey" -}}
{{- if .Values.postgresql.enabled -}}
password
{{- else -}}
{{- .Values.externalDatabase.existingSecretPasswordKey -}}
{{- end -}}
{{- end -}}

{{/*
SQLAlchemy URI without the password (psycopg reads PGPASSWORD from the environment)
*/}}
{{- define "opentakserver.database.uri" -}}
{{- printf "postgresql+psycopg://%s@%s:%v/%s" (include "opentakserver.database.user" .) (include "opentakserver.database.host" .) (include "opentakserver.database.port" .) (include "opentakserver.database.name" .) -}}
{{- end -}}

{{/*
RabbitMQ helpers
*/}}
{{- define "opentakserver.rabbitmq.host" -}}
{{- if .Values.rabbitmq.enabled -}}
{{- include "opentakserver.rabbitmq.fullname" . -}}
{{- else -}}
{{- required "externalRabbitmq.host is required when rabbitmq.enabled=false" .Values.externalRabbitmq.host -}}
{{- end -}}
{{- end -}}

{{- define "opentakserver.rabbitmq.username" -}}
{{- if .Values.rabbitmq.enabled -}}{{- .Values.rabbitmq.auth.username -}}{{- else -}}{{- .Values.externalRabbitmq.username -}}{{- end -}}
{{- end -}}

{{- define "opentakserver.rabbitmq.secretName" -}}
{{- if .Values.rabbitmq.enabled -}}
{{- include "opentakserver.rabbitmq.fullname" . -}}
{{- else -}}
{{- .Values.externalRabbitmq.existingSecret | default (printf "%s-externalrabbitmq" (include "common.names.fullname" .)) -}}
{{- end -}}
{{- end -}}

{{- define "opentakserver.rabbitmq.secretPasswordKey" -}}
{{- if .Values.rabbitmq.enabled -}}
rabbitmq-password
{{- else -}}
{{- .Values.externalRabbitmq.existingSecretPasswordKey -}}
{{- end -}}
{{- end -}}

{{/*
Public FQDN / Ingress hostname
*/}}
{{- define "opentakserver.fqdn" -}}
{{- .Values.opentakserver.fqdn | default .Values.ingress.hostname -}}
{{- end -}}

{{- define "opentakserver.ingress.hostname" -}}
{{- .Values.ingress.hostname | default .Values.opentakserver.fqdn -}}
{{- end -}}

{{/*
MediaMTX API address consumed by OpenTAKServer
*/}}
{{- define "opentakserver.mediamtx.apiAddress" -}}
{{- printf "http://127.0.0.1:%v" .Values.mediamtx.apiPort -}}
{{- end -}}

{{/*
Shared environment variables for every OpenTAKServer container
*/}}
{{- define "opentakserver.commonEnv" -}}
- name: OTS_DATA_FOLDER
  value: {{ .Values.persistence.dataFolder | quote }}
- name: HOME
  value: {{ .Values.persistence.dataFolder | quote }}
- name: DEBUG
  value: {{ ternary "True" "False" .Values.opentakserver.debug | quote }}
- name: OTS_FQDN
  value: {{ include "opentakserver.fqdn" . | default "_" | quote }}
- name: OTS_LISTENER_ADDRESS
  value: "0.0.0.0"
- name: OTS_LISTENER_PORT
  value: {{ .Values.service.ports.http | quote }}
- name: OTS_TCP_STREAMING_PORT
  value: {{ .Values.server.eudHandler.containerPort | quote }}
- name: OTS_SSL_STREAMING_PORT
  value: {{ .Values.server.eudHandlerSsl.containerPort | quote }}
- name: OTS_ENABLE_TCP_STREAMING_PORT
  value: {{ ternary "True" "False" .Values.server.eudHandler.enabled | quote }}
- name: OTS_COT_PARSER_PROCESSES
  value: {{ .Values.server.cotParser.processes | quote }}
- name: SQLALCHEMY_DATABASE_URI
  value: {{ include "opentakserver.database.uri" . | quote }}
- name: PGHOST
  value: {{ include "opentakserver.database.host" . | quote }}
- name: PGPORT
  value: {{ include "opentakserver.database.port" . | quote }}
- name: PGUSER
  value: {{ include "opentakserver.database.user" . | quote }}
- name: PGDATABASE
  value: {{ include "opentakserver.database.name" . | quote }}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "opentakserver.database.secretName" . }}
      key: {{ include "opentakserver.database.secretPasswordKey" . }}
- name: OTS_RABBITMQ_SERVER_ADDRESS
  value: {{ include "opentakserver.rabbitmq.host" . | quote }}
- name: OTS_RABBITMQ_USERNAME
  value: {{ include "opentakserver.rabbitmq.username" . | quote }}
- name: OTS_RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "opentakserver.rabbitmq.secretName" . }}
      key: {{ include "opentakserver.rabbitmq.secretPasswordKey" . }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "opentakserver.secretName" . }}
      key: secret-key
- name: OTS_CA_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "opentakserver.secretName" . }}
      key: ca-password
- name: OTS_CA_NAME
  value: {{ .Values.opentakserver.ca.name | quote }}
- name: OTS_CA_EXPIRATION_TIME
  value: {{ .Values.opentakserver.ca.expirationDays | quote }}
- name: OTS_CA_COUNTRY
  value: {{ .Values.opentakserver.ca.country | quote }}
- name: OTS_CA_STATE
  value: {{ .Values.opentakserver.ca.state | quote }}
- name: OTS_CA_CITY
  value: {{ .Values.opentakserver.ca.city | quote }}
- name: OTS_CA_ORGANIZATION
  value: {{ .Values.opentakserver.ca.organization | quote }}
- name: OTS_CA_ORGANIZATIONAL_UNIT
  value: {{ .Values.opentakserver.ca.organizationalUnit | quote }}
- name: OTS_MEDIAMTX_ENABLE
  value: {{ ternary "True" "False" .Values.mediamtx.enabled | quote }}
{{- if .Values.mediamtx.enabled }}
- name: OTS_MEDIAMTX_API_ADDRESS
  value: {{ include "opentakserver.mediamtx.apiAddress" . | quote }}
- name: OTS_MEDIAMTX_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "opentakserver.secretName" . }}
      key: mediamtx-token
{{- end }}
{{- if .Values.opentakserver.extraEnvVars }}
{{- include "common.tplvalues.render" (dict "value" .Values.opentakserver.extraEnvVars "context" $) | nindent 0 }}
{{- end }}
{{- end -}}

{{/*
envFrom sources shared by every OpenTAKServer container
*/}}
{{- define "opentakserver.commonEnvFrom" -}}
{{- if .Values.opentakserver.extraEnvVarsCM }}
- configMapRef:
    name: {{ .Values.opentakserver.extraEnvVarsCM }}
{{- end }}
{{- if .Values.opentakserver.extraEnvVarsSecret }}
- secretRef:
    name: {{ .Values.opentakserver.extraEnvVarsSecret }}
{{- end }}
{{- end -}}

{{/*
Validate configuration
*/}}
{{- define "opentakserver.validateValues" -}}
{{- if and .Values.ingress.enabled (not (include "opentakserver.ingress.hostname" .)) -}}
{{- fail "ingress.enabled=true requires either opentakserver.fqdn or ingress.hostname to be set" -}}
{{- end -}}
{{- if and .Values.ingress.enabled .Values.ingress.tls (not .Values.ingress.tlsSecret) (not .Values.ingress.certManager.enabled) -}}
{{- fail "ingress.tls=true requires ingress.tlsSecret or ingress.certManager.enabled" -}}
{{- end -}}
{{- end -}}
