{{- define "tenant.utils.filter-list" -}}
  {{- $list := list -}}

  {{- range $val := . | default list -}}
    {{- if ne $val nil -}}
      {{- $list = append $list $val -}}
    {{- end -}}
  {{- end -}}

  {{- $list | toYaml -}}
{{- end -}}

{{- define "tenant.utils.filter-map" -}}
  {{- $map := dict -}}

  {{- range $key, $val := . | default dict -}}
    {{- if ne $val nil -}}
      {{- $_ := set $map $key $val -}}
    {{- end -}}
  {{- end -}}

  {{- $map | toYaml -}}
{{- end -}}

{{- define "tenant.utils.render-object" -}}
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

{{- define "tenant.utils.map-to-list" -}}
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

{{- define "tenant.utils.template" -}}
  {{- $value := .value -}}
  {{- $context := .context -}}
  {{- $scope := .scope -}}
  {{- $vars := .vars | default dict -}}

  {{- $valueString := ternary $value (toYaml $value) (typeIs "string" $value) -}}

  {{- $input := dict
    "context" $context
    "scope" $scope
    "vars" $vars
  -}}

  {{- $template := "{{- $ := .context -}}" -}}

  {{- range $key := $vars | keys -}}
    {{- $template = printf "{{- $%s := .vars.%s -}}" $key $key | print $template -}}
  {{- end -}}

  {{- if .scope -}}
    {{- $template = printf "{{- with .scope -}}%s{{- end -}}" $valueString | print $template -}}
  {{- else -}}
    {{- $template = $valueString | print $template -}}
  {{- end -}}

  {{- tpl $template $input -}}
{{- end -}}
