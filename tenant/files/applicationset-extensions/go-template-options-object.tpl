{{- with .goTemplateOptionsObject -}}
  {{- $goTemplateOptions := $.goTemplateOptions | default list -}}

  {{- range $key, $val := . -}}
    {{- $goTemplateOptions = append $goTemplateOptions (printf "%s=%s" $key (toString $val)) -}}
  {{- end -}}

  {{- $_ := set $ "goTemplateOptions" $goTemplateOptions -}}
{{- end -}}
