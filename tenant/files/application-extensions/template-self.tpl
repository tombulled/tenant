{{- $template := $ | toYaml -}}

{{- range $match := regexFindAll "{{ *\\..*? *}}" $template -1 -}}
  {{- $keys := substr 2 (int (sub (len $match) 2)) $match | trim | substr 1 -1 | splitList "." -}}
  {{- $obj := $ -}}

  {{- range $key := $keys -}}
    {{- if or (not $obj) (ne (kindOf $obj) "map") -}}
      {{- $obj = "" -}}
      {{- break -}}
    {{- end -}}

    {{- /* Convert `$obj` to `map[string]interface {}`, otherwise Sprig's `get` function fails */ -}}
    {{- $newObj := dict -}}
    {{- range $key, $val := $obj -}}
      {{- $_ := set $newObj $key $val -}}
    {{- end -}}
    {{- $obj = $newObj -}}

    {{- $obj = get $obj $key -}}
  {{- end -}}

  {{- $template = replace $match ($obj | default "") $template -}}
{{- end -}}

{{- $templatedObj := $template | fromYaml -}}

{{- range $key, $val := $templatedObj -}}
  {{- $_ := set $ $key $val -}}
{{- end -}}
