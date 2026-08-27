{{- define "argocd-templates.application" -}}
{{- `
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .name }}
  {{- with .namespace }}
  namespace: {{ . }}
  {{- end }}
  {{- with .finalizers }}
  finalizers: {{ . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
spec:
  {{- with .destination }}
  destination: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .ignoreDifferences }}
  ignoreDifferences: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- if and .infoObject .info }}
    {{- fail "Specify either 'infoObject' or 'info', not both." }}
  {{- end }}
  {{- with .infoObject }}
  info:
    {{- range $key, $val := . }}
    {{- /* Every key gets automatically converted from camel case to title case, e.g. "gitRepo" -> "Git Repo" */}}
    - name: {{ $key | snakecase | replace "_" " " | title }}
      value: {{ $val }}
    {{- end }}
  {{- else with .info }}
  info: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .project }}
  project: {{ . }}
  {{- end }}
  {{- if ne .revisionHistoryLimit nil }}
  revisionHistoryLimit: {{ .revisionHistoryLimit }}
  {{- end }}
  {{- with .source }}
  source: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .sourceHydrator }}
  sourceHydrator: {{- . | toYaml | nindent 4}}
  {{- end }}
  {{- if and .sourcesObject .sources }}
    {{- fail "Specify either 'sourcesObject' or 'sources', not both." }}
  {{- end }}
  {{- with .sourcesObject }}
  sources:
    {{- $mainSourceKey := "main" }}
    {{- $sourcesList := list (pick . $mainSourceKey) (omit . $mainSourceKey) }}
    {{- range $sourcesList }}
    {{- range $sourceId, $_ := . }}
    {{- if or (eq . nil) (eq .enabled false) -}}
      {{- continue -}}
    {{- end -}}
    {{- if and (eq .ref nil) (eq .chart nil) }}
      {{- $_ := set . "ref" $sourceId }}
    {{- end }}
    {{- $_ := set . "name" (.name | default $sourceId) }}
    - {{ . | toYaml | nindent 6 | trim }}
    {{- end }}
    {{- end }}
  {{- else with .sources }}
  sources: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .syncPolicy }}
    {{- $syncPolicy := . }}
    {{- with .syncOptionsObject }}
      {{- $syncOptions := list }}
      {{- range $key, $val := . }}
        {{- $syncOptions = append $syncOptions (printf "%s=%s" (title $key) (toString $val)) }}
      {{- end }}
      {{- $_ := unset $syncPolicy "syncOptionsObject" }}
      {{- $_ := set $syncPolicy "syncOptions" $syncOptions }}
    {{- end }}
  syncPolicy: {{- . | toYaml | nindent 4 }}
  {{- end }}
` | trim -}}
{{- end -}}
