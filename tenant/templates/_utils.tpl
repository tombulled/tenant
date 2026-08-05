{{- define "tenant.utils.map-to-list" -}}
  {{- $values := list -}}

  {{- range $ -}}
    {{- $enabled := ternary .enabled true (ne .enabled nil) -}}

    {{- if not $enabled -}}
      {{- continue -}}
    {{- end -}}

    {{- $_ := unset . "enabled" -}}
    {{- $values = append $values . -}}
  {{- end -}}

  {{- $values | toYaml -}}
{{- end -}}
