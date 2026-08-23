{{- define "resources-lib.utils.camel-case" -}}
  {{- $pascalCase := camelcase . -}}
  {{- $camelCase := printf
    "%s%s"
    ($pascalCase | substr 0 1 | lower)
    ($pascalCase | substr 1 (len $pascalCase))
  }}

  {{- $camelCase -}}
{{- end -}}

{{- define "resources-lib.utils.pluralise" -}}
  {{- $lastChar := . | trunc -1 -}}

  {{- if eq $lastChar "y" -}}
    {{- printf "%sies" (trimSuffix "y" .) -}}
  {{- else -}}
    {{- printf "%ss" . -}}
  {{- end -}}
{{- end -}}

{{- define "resources-lib.utils.render-object" -}}
  {{- $value := .value -}}
  {{- $indent := .indent -}}

  {{- if ne $value nil -}}
    {{- if $value -}}
      {{- $value | toYaml | nindent $indent -}}
    {{- else -}}
      {{- $value | toYaml -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "resources-lib.utils.map-to-list" -}}
  {{- /* Extract arguments */ -}}
  {{- $map := .map | default dict -}}
  {{- $field := .field -}}

  {{- $values := list -}}

  {{- range $key, $_ := $map -}}
    {{- if eq . nil -}}
      {{- continue -}}
    {{- end -}}

    {{- $enabled := ternary .enabled true (ne .enabled nil) -}}

    {{- if not $enabled -}}
      {{- continue -}}
    {{- end -}}

    {{- if and $field (not (get . $field)) -}}
      {{- $_ := set . $field $key -}}
    {{- end -}}

    {{- $_ := unset . "enabled" -}}
    {{- $values = append $values . -}}
  {{- end -}}

  {{- $values | toYaml -}}
{{- end -}}
