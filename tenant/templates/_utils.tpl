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

{{- define "tenant.utils.dynamic-get" -}}
  {{- $map := .map | default dict -}}
  {{- $keys := .keys | default list -}}

  {{- $value := $map -}}
  {{- range $key := $keys -}}
    {{- /* If the current value isn't a map, abort as we can't traverse any deeper */ -}}
    {{- if ne (kindOf $value) "map" -}}
      {{- $value = "" -}}
      {{- break -}}
    {{- end -}}

    {{- /* Update '$value' to use the value of the current key */ -}}
    {{- /* After the last iteration, '$value' will contain the final value */ -}}
    {{- $value = get $value $key -}}
  {{- end -}}

  {{- $value -}}
{{- end -}}

{{- define "tenant.utils.dynamic-set" -}}
  {{- $map := .map -}}
  {{- $keys := .keys | default list -}}
  {{- $value := .value -}}

  {{- $obj := $map -}}
  {{- range $key := initial $keys -}}
    {{- if not (hasKey $obj $key) -}}
      {{- $_ := set $obj $key (dict) -}}
    {{- end -}}

    {{- $obj = index $obj $key -}}

    {{- if ne (kindOf $obj) "map" -}}
      {{- $obj = dict -}}
      {{- break -}}
    {{- end -}}
  {{- end -}}

  {{- $_ := set $obj (last $keys) $value -}}
{{- end -}}

{{- define "tenant.utils.map-to-list" -}}
  {{- $map := .map | default dict -}}
  {{- $field := .field -}}

  {{- $values := list -}}

  {{- range $key, $_ := include "tenant.utils.filter-map" $map | fromYaml -}}
    {{- $enabledVal := index . "$enabled" -}}
    {{- $enabled := ternary $enabledVal true (ne $enabledVal nil) -}}

    {{- if not $enabled -}}
      {{- continue -}}
    {{- end -}}

    {{- if and $field (not (get . $field)) -}}
      {{- $_ := set . $field $key -}}
    {{- end -}}

    {{- $_ := unset . "$enabled" -}}
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
