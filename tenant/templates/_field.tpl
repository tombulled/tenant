{{- define "tenant.field.multi-line-string" -}}
  {{- $value := .value -}}
  {{- $indent := .indent -}}

  {{- $trueIndent := sub $indent 2 | int }}

  {{- $value | toString | toYaml | indent $trueIndent | trimPrefix (repeat $trueIndent " ") -}}
{{- end -}}
