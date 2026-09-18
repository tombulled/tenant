{{- define "tenant.metadata" -}}
  {{- (dict
    "annotations" .annotations
    "finalizers" .finalizers
    "labels" .labels
    "name" .name
    "namespace" .namespace
  ) | include "tenant.utils.filter-map" -}}
{{- end -}}
