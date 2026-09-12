{{- define "tenant.metadata" -}}
  {{- (dict
    "annotations" .annotations
    "finalizers" .finalizers
    "labels" .labels
    "name" .name
    "namespace" .namespace
  ) | include "tenant.utils.filter-map" -}}
{{- end -}}

{{- define "tenant.metadata.excluding" -}}
  {{- $data := . | first -}}
  {{- $excludeFields := . | rest -}}

  {{- $metadata := include "tenant.metadata" $data | fromYaml -}}

  {{- range $excludeFields -}}
    {{- $_ := unset $metadata . -}}
  {{- end -}}

  {{- $metadata | toYaml -}}
{{- end -}}
