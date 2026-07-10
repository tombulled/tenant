{{- with .sourcesObject -}}
  {{- $sources := $.sources | default list -}}

  {{- range $sourceId, $_ := . -}}
    {{- if eq . nil -}}
      {{- continue -}}
    {{- end -}}

    {{- $enabled := ternary .enabled true (ne .enabled nil) -}}

    {{- if not $enabled -}}
      {{- continue -}}
    {{- end -}}

    {{- $_ := set . "ref" (.ref | default $sourceId) -}}
    {{- $_ := set . "name" (.name | default $sourceId) -}}

    {{- $sources = append $sources . -}}
  {{- end -}}

  {{- $_ := set $ "sources" $sources -}}
{{- end -}}
