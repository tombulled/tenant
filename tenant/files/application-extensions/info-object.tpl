{{- with .infoObject -}}
  {{- $info := $.info | default list -}}

  {{- range $key, $val := . -}}
    {{- $name := $key | snakecase | replace "_" " " | title }}
    {{- $obj := dict "name" $name "value" $val }}

    {{- $info = append $info $obj -}}
  {{- end -}}

  {{- $_ := set $ "info" $info -}}
{{- end -}}
