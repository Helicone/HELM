{{- define "oai.name" -}}
{{ include "helicone.name" . }}-oai
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helicone.oai.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oai.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
