{{- with .generatorsObject -}}
  {{- $generators := $.generators | default list -}}

  {{- range $generatorId, $generator := . -}}
    {{- $generators = append $generators $generator -}}
  {{- end -}}

  {{- $_ := set $ "generators" $generators -}}
{{- end -}}
