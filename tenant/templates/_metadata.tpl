{{- define "tenant.metadata" -}}
  {{- (dict
    "annotations" .annotations
    "finalizers" .finalizers
    "labels" .labels
    "name" .name
    "namespace" .namespace
  ) | include "tenant.utils.filter-map" -}}
{{- end -}}

{{- define "tenant.metadata.no-namespace" -}}
  {{- $metadata := include "tenant.metadata" . | fromYaml -}}
  {{- $_ := unset $metadata "namespace" -}}
  {{- $metadata | toYaml -}}
{{- end -}}

{{- define "tenant.metadata.no-namespace-or-finalizers" -}}
  {{- $metadata := include "tenant.metadata.no-namespace" . | fromYaml -}}
  {{- $_ := unset $metadata "finalizers" -}}
  {{- $metadata | toYaml -}}
{{- end -}}
