{{- define "api.name" -}}
{{ include "helicone.name" . }}-api
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helicone.api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
