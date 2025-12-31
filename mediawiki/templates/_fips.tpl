{{/*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return true if FIPS mode is enabled
Usage:
{{ include "common.fips.enabled" . }}
*/}}
{{- define "common.fips.enabled" -}}
{{- $fipsEnabled := false -}}
{{- if .Values.global -}}
  {{- if .Values.global.defaultFips -}}
    {{- if or (eq .Values.global.defaultFips "restricted") (eq .Values.global.defaultFips "relaxed") -}}
      {{- $fipsEnabled = true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $fipsEnabled -}}
{{- end -}}

{{/*
Return the FIPS configuration value for a specific component
Usage:
{{ include "common.fips.config" (dict "tech" "openssl" "fips" .Values.component.fips "global" .Values.global) }}
*/}}
{{- define "common.fips.config" -}}
{{- $fipsConfig := "" -}}
{{- if .fips -}}
  {{- $fipsConfig = .fips | toString -}}
{{- else if .global -}}
  {{- if .global.defaultFips -}}
    {{- $fipsConfig = .global.defaultFips | toString -}}
  {{- end -}}
{{- end -}}
{{- if eq .tech "openssl" -}}
  {{- if or (eq $fipsConfig "restricted") (eq $fipsConfig "relaxed") -}}
    {{- printf "1" -}}
  {{- else -}}
    {{- printf "0" -}}
  {{- end -}}
{{- else -}}
  {{- $fipsConfig | toString -}}
{{- end -}}
{{- end -}}
