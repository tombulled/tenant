{{- with .syncPolicy -}}
  {{- /* Build Sync Options Dictionary */ -}}
  {{- $syncOptionsDict := dict -}}
  {{- range $syncOption := .syncOptions | default list }}
    {{- $key := (split "=" $syncOption)._0 }}
    {{- $val := (split "=" $syncOption)._1 }}
    {{- $_ := set $syncOptionsDict $key $val }}
  {{- end }}
  {{- range $key, $val := .syncOptionsObject | default dict }}
    {{- $_ := set $syncOptionsDict (title $key) (toString $val) }}
  {{- end }}

  {{- /* Build Sync Options List*/ -}}
  {{- $syncOptionsList := list -}}
  {{- range $key, $val := $syncOptionsDict }}
    {{- $syncOptionsList = append $syncOptionsList (printf "%s=%s" $key $val) }}
  {{- end }}

  {{- /* Patch Sync Policy */ -}}
  {{- $_ := unset . "syncOptionsObject" -}}
  {{- if $syncOptionsList -}}
    {{- $_ := set . "syncOptions" $syncOptionsList -}}
  {{- else -}}
    {{- $_ := unset . "syncOptions" -}}
  {{- end -}}
{{- end -}}
