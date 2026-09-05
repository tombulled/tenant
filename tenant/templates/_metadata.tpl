{{- define "tenant.metadata" -}}
{{- $data := .data -}}
{{- $finalizers := ternary .finalizers true (ne .finalizers nil) -}}
{{- $namespace := ternary .namespace true (ne .namespace nil) -}}

{{- with $data -}}
{{- with .annotations }}
annotations: {{- . | toYaml | nindent 4 }}
{{- end }}
{{- if $finalizers }}
{{- with .finalizers }}
finalizers: {{- . | toYaml | nindent 4 }}
{{- end }}
{{- end }}
{{- with .labels }}
labels: {{- . | toYaml | nindent 4 }}
{{- end }}
name: {{ .name | quote }}
{{- if $namespace }}
{{- with .namespace }}
namespace: {{ . | quote }}
{{- end }}
{{- end }}
{{- end -}}
{{- end -}}
