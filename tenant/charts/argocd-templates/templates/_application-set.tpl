{{- define "argocd-templates.application-set" -}}
{{- `
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
  name: {{ .name }}
  {{- with .namespace }}
  namespace: {{ . }}
  {{- end }}
spec:
  {{- if ne .applyNestedSelectors nil }}
  applyNestedSelectors: {{ .applyNestedSelectors }}
  {{- end }}
  {{- if and .generatorsObject .generators }}
    {{- fail "Specify either 'generatorsObject' or 'generators', not both." }}
  {{- end }}
  {{- with .generatorsObject }}
  {{- $generators := include "resources-lib.utils.map-to-list" (dict "map" .) | fromYamlArray }}
  generators: {{ include "resources-lib.utils.render-object" (dict "value" $generators "indent" 4) }}
  {{- else with .generators }}
  generators: {{- . | toYaml | nindent 4 }}
  {{- else }}
  generators: []
  {{- end }}
  {{- if ne .goTemplate nil }}
  goTemplate: {{ .goTemplate }}
  {{- end }}
  {{- if and .goTemplateOptionsObject .goTemplateOptions }}
    {{- fail "Specify either 'goTemplateOptionsObject' or 'goTemplateOptions', not both." }}
  {{- end }}
  {{- with .goTemplateOptionsObject }}
  goTemplateOptions:
    {{- range $key, $val := . }}
    - {{ printf "%s=%s" $key (toString $val) }}
    {{- end }}
  {{- else with .goTemplateOptions }}
  goTemplateOptions: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .ignoreApplicationDifferences }}
  ignoreApplicationDifferences: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .preservedFields }}
  preservedFields: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .strategy }}
  strategy: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .syncPolicy }}
  syncPolicy: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .template }}
  template: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .templatePatch }}
  templatePatch: |
    {{- . | nindent 4 }}
  {{- end }}
` | trim -}}
{{- end -}}
