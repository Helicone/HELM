{{/*
Expand the name of the chart.
*/}}

{{- define "helicone.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.

TODO, make sure this is the ONLY fullname named template in this chart for consistencies sake
*/}}
{{- define "helicone.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "helicone.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helicone.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helicone.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "helicone.labels" -}}
helm.sh/chart: {{ include "helicone.chart" . }}
{{ include "helicone.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }} {{- end }}

{{- define "supabase.waitForDBInitContainer" -}}
# We need to wait for the postgresql database to be ready in order to start with Supabase.
# As it is a ReplicaSet, we need that all nodes are configured in order to start with
# the application or race conditions can occur
- name: wait-for-db
  image: {{ template "supabase.psql.image" . }}
  imagePullPolicy: {{ .Values.psqlImage.pullPolicy }}
  command:
    - bash
    - -ec
    - |
      #!/bin/bash

      set -o errexit
      set -o nounset
      set -o pipefail

      . /opt/bitnami/scripts/liblog.sh
      . /opt/bitnami/scripts/libvalidations.sh
      . /opt/bitnami/scripts/libpostgresql.sh
      . /opt/bitnami/scripts/postgresql-env.sh

      info "Waiting for host $DATABASE_HOST"
      psql_is_ready() {
          if ! PGCONNECT_TIMEOUT="5" PGPASSWORD="$DATABASE_PASSWORD" psql -U "$DATABASE_USER" -d "$DATABASE_NAME" -h "$DATABASE_HOST" -p "$DATABASE_PORT_NUMBER" -c "SELECT 1"; then
             return 1
          fi
          return 0
      }
      if ! retry_while "debug_execute psql_is_ready"; then
          error "Database not ready"
          exit 1
      fi
      info "Database is ready"
  env:
    - name: DATABASE_HOST
      value: {{ include "supabase.database.host" . | quote }}
    - name: DATABASE_PORT_NUMBER
      value: {{ include "supabase.database.port" . | quote }}
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "supabase.database.secretName" . }}
          key: {{ include "supabase.database.passwordKey" . | quote }}
    - name: DATABASE_USER
      value: {{ include "supabase.database.user" . | quote }}
    - name: DATABASE_NAME
      value: {{ include "supabase.database.name" . | quote }}
{{- end -}}

{{- define "helicone.env.supabaseServiceRoleKey" -}}
- name: SUPABASE_SERVICE_ROLE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "supabase.jwt.secretName" .Subcharts.supabase }}
      key: {{ include "supabase.jwt.serviceSecretKey" .Subcharts.supabase }}
{{- end -}}

{{- define "helicone.env.supabaseAnonKey" -}}
- name: NEXT_PUBLIC_SUPABASE_ANON_KEY
  valueFrom:
    secretKeyRef:
      name: '{{ include "supabase.jwt.secretName" .Subcharts.supabase }}'
      key: '{{ include "supabase.jwt.anonSecretKey" .Subcharts.supabase }}'
{{- end -}}

{{- define "helicone.env.supabaseUrl" -}}
- name: SUPABASE_URL
  value: 'http://{{ .Release.Name }}-kong:{{ .Values.supabase.kong.service.ports.proxyHttp }}'
{{- end -}}

{{- define "helicone.env.s3Enabled" -}}
- name: S3_ENABLED
  value: "{{ .Values.globalEnvVars.S3_ENABLED }}"
{{- end -}}

{{- define "helicone.env.datadogEnabled" -}}
- name: DATADOG_ENABLED
  value: "false"
{{- end -}}

{{- define "helicone.env.supabaseDbName" -}}
- name: DB_NAME
  value: '{{ include "supabase.database.name" .Subcharts.supabase }}'
{{- end -}}

{{- define "helicone.env.supabaseDbPassword" -}}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "supabase.database.secretName" .Subcharts.supabase }}
      key: {{ include "supabase.database.passwordKey" .Subcharts.supabase | quote }}
{{- end -}}

{{- define "helicone.env.clickhouseHost" -}}
- name: CLICKHOUSE_HOST
  value: "http://{{ include "clickhouse.name" . }}:8123"
{{- end -}}

{{- define "helicone.env.clickhouseUser" -}}
- name: CLICKHOUSE_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "clickhouse.name" . }}
      key: user
{{- end -}}

{{- define "helicone.env.clickhousePassword" -}}
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "clickhouse.name" . }}
      key: password
{{- end -}}

{{- define "s3.name" -}}
{{ include "helicone.name" . }}-s3
{{- end }}

{{- define "helicone.env.s3AccessKey" -}}
- name: S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "s3.name" . }}
      key: access_key
{{- end -}}

{{- define "helicone.env.s3SecretKey" -}}
- name: S3_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "s3.name" . }}
      key: secret_key
{{- end -}}

{{- define "helicone.env.s3BucketName" -}}
- name: S3_BUCKET_NAME
  valueFrom:
    secretKeyRef:
      name: {{ include "s3.name" . }}
      key: bucket_name
{{- end -}}

{{- define "helicone.env.s3Endpoint" -}}
- name: S3_ENDPOINT
  valueFrom:
    secretKeyRef:
      name: {{ include "s3.name" . }}
      key: endpoint
{{- end -}}

{{- define "helicone.worker.env" }}
{{ include "helicone.env.supabaseAnonKey" . }}
{{ include "helicone.env.supabaseServiceRoleKey" . }}
{{ include "helicone.env.clickhouseUser" . }}
{{ include "helicone.env.clickhousePassword" . }}
{{ include "helicone.env.supabaseUrl" . }}
{{ include "helicone.env.clickhouseHost" . }}
{{ include "helicone.env.s3Enabled" . }}
{{ include "helicone.env.s3AccessKey" . }}
{{ include "helicone.env.s3SecretKey" . }}
{{ include "helicone.env.s3BucketName" . }}
{{ include "helicone.env.s3Endpoint" . }}
{{ include "helicone.env.datadogEnabled" . }}
{{- end }}
