{{- define "resources.utils.camel-case" -}}
  {{- $pascalCase := camelcase . -}}
  {{- $camelCase := printf
    "%s%s"
    ($pascalCase | substr 0 1 | lower)
    ($pascalCase | substr 1 (len $pascalCase))
  }}

  {{- $camelCase -}}
{{- end -}}

{{- define "resources.utils.pluralise" -}}
  {{- $lastChar := . | trunc -1 -}}

  {{- if eq $lastChar "y" -}}
    {{- printf "%sies" (trimSuffix "y" .) -}}
  {{- else -}}
    {{- printf "%ss" . -}}
  {{- end -}}
{{- end -}}
