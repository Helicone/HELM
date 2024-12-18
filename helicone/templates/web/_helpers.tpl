{{- define "web.name" -}}
{{ include "helicone.name" . }}-web
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helicone.web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "helicone.web.env" }}
{{ include "helicone.env.supabaseUrl" . }}
{{ include "helicone.env.supabaseDbPassword" . }}
{{ include "helicone.env.supabaseDbName" . }}
{{ include "helicone.env.s3Enabled" . }}
{{ include "helicone.env.s3AccessKey" . }}
{{ include "helicone.env.s3SecretKey" . }}
{{ include "helicone.env.s3BucketName" . }}
{{ include "helicone.env.s3Endpoint" . }}
- name: NEXT_PUBLIC_SUPABASE_URL
  value: {{ .Values.helicone.web.supabasePublicUrl | quote }}
- name: NEXT_PUBLIC_HELICONE_JAWN_SERVICE
  value: {{ .Values.helicone.jawn.publicUrl | quote }}
- name: DB_HOST
  value: '{{ include "supabase.database.host" .Subcharts.supabase }}'
- name: NEXT_PUBLIC_API_BASE_PATH
  value: "/api2"
- name: NEXT_PUBLIC_BASE_PATH
  value: "/api2/v1"
- name: DB_PORT
  value: '{{ include "supabase.database.port" .Subcharts.supabase }}'
- name: DB_DRIVER
  value: "postgres"
- name: DB_SSL
  value: "disable"
- name: DB_USER
  value: "postgres"
- name: DATABASE_URL
  value: "postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=$(DB_SSL)&options=-c%20search_path%3Dpublic,extensions"
- name: NEXT_PUBLIC_IS_ON_PREM
  value: "true"
{{- end }}

{{- define "helicone.web.clickhouseEnv" }}
{{ include "helicone.env.clickhouseHost" . }}
{{ include "helicone.env.clickhouseUser" . }}
{{ include "helicone.env.clickhousePassword" . }}
{{- end }}
