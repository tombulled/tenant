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
  {{- $map := .map | default dict -}}
  {{- $field := .field -}}

  {{- $values := list -}}

  {{- range $key, $_ := include "tenant.utils.filter-map" $map | fromYaml -}}
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

{{- define "tenant.utils.pluralise" -}}
  {{- $lastChar := . | trunc -1 -}}

  {{- if eq $lastChar "y" -}}
    {{- printf "%sies" (trimSuffix "y" .) -}}
  {{- else -}}
    {{- printf "%ss" . -}}
  {{- end -}}
{{- end -}}

{{- define "tenant.utils.template" -}}
  {{- $value := .value -}}
  {{- $context := .context -}}
  {{- $scope := .scope -}}
  {{- $vars := .vars | default dict -}}

  {{- $valueString := ternary $value (toYaml $value) (typeIs "string" $value) -}}

  {{- $input := dict
    "context" $context
    "scope" ($scope | default $context)
    "vars" $vars
  -}}

  {{- $template := "{{- $ := .context -}}" -}}

  {{- range $key := $vars | keys -}}
    {{- $template = printf "{{- $%s := .vars.%s -}}" $key $key | print $template -}}
  {{- end -}}

  {{- $template = printf "{{- with .scope -}}%s{{- end -}}" $valueString | print $template -}}

  {{- tpl $template $input -}}
{{- end -}}
