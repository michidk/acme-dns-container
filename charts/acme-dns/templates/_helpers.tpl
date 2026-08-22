{{- define "acme-dns.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "acme-dns.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "acme-dns.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "acme-dns.labels" -}}
helm.sh/chart: {{ include "acme-dns.chart" . }}
{{ include "acme-dns.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "acme-dns.selectorLabels" -}}
app.kubernetes.io/name: {{ include "acme-dns.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "acme-dns.configName" -}}
{{- if .Values.config.existingSecret }}
{{- .Values.config.existingSecret }}
{{- else if .Values.config.existingConfigMap }}
{{- .Values.config.existingConfigMap }}
{{- else }}
{{- printf "%s-config" (include "acme-dns.fullname" .) }}
{{- end }}
{{- end }}

{{- define "acme-dns.claimName" -}}
{{- default (include "acme-dns.fullname" .) .Values.persistence.existingClaim }}
{{- end }}

{{- define "acme-dns.validateValues" -}}
{{- if and .Values.config.existingConfigMap .Values.config.existingSecret -}}
{{- fail "set only one of config.existingConfigMap or config.existingSecret" -}}
{{- end -}}
{{- if and (gt (int .Values.replicaCount) 1) (not .Values.config.existingConfigMap) (not .Values.config.existingSecret) (eq .Values.config.database.engine "sqlite") -}}
{{- fail "replicaCount must be 1 when using the generated SQLite configuration" -}}
{{- end -}}
{{- if and (not .Values.config.existingConfigMap) (not .Values.config.existingSecret) (ne (int (regexFind "[0-9]+$" .Values.config.general.listen)) (int .Values.containerPorts.dns)) -}}
{{- fail "config.general.listen port must match containerPorts.dns" -}}
{{- end -}}
{{- if and (not .Values.config.existingConfigMap) (not .Values.config.existingSecret) (ne (int .Values.config.api.port) (int .Values.containerPorts.api)) -}}
{{- fail "config.api.port must match containerPorts.api" -}}
{{- end -}}
{{- end }}
