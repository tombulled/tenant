{{- define "tenant.metadata._build" -}}
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

{{- define "tenant.metadata" -}}
  {{- include "tenant.metadata._build" (dict
    "data" .
  ) -}}
{{- end -}}

{{- define "tenant.metadata.no-namespace" -}}
  {{- include "tenant.metadata._build" (dict
    "data" .
    "namespace" false
  ) -}}
{{- end -}}

{{- define "tenant.metadata.no-namespace-or-finalizers" -}}
  {{- include "tenant.metadata._build" (dict
    "data" .
    "finalizers" false
    "namespace" false
  ) -}}
{{- end -}}
