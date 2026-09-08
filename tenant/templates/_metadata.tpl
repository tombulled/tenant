{{- define "tenant.metadata" -}}
  {{- $data := .data -}}
  {{- $finalizers := ternary .finalizers true (ne .finalizers nil) -}}
  {{- $namespace := ternary .namespace true (ne .namespace nil) -}}

  {{- with $data -}}
    {{- (dict
      "annotations" .annotations
      "finalizers" (ternary .finalizers nil $finalizers)
      "labels" .labels
      "name" .name
      "namespace" (ternary .namespace nil $namespace)
    ) | include "tenant.utils.filter-map" -}}
  {{- end -}}
{{- end -}}
