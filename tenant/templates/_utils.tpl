{{- define "tenant.utils.list-or-map" -}}
  {{- $value := .value -}}
  {{- $propagateMapKeyToFields := .propagateMapKeyToFields | default list -}}
  {{- $priorityMapKey := .priorityMapKey -}}

  {{- if kindIs "map" $value }}
    {{- $maps := list $value -}}
    {{- if ne $priorityMapKey nil -}}
      {{- $maps = list (pick $value $priorityMapKey) (omit $value $priorityMapKey) -}}
    {{- end -}}

    {{- $values := list -}}
    {{- range $maps -}}
      {{- range $key, $val := . -}}
        {{- if eq . nil -}}
          {{- continue -}}
        {{- end -}}

        {{- $enabledVal := index . "$enabled" -}}
        {{- $enabled := ternary $enabledVal true (ne $enabledVal nil) -}}
        {{- $_ := unset . "$enabled" -}}

        {{- if not $enabled -}}
          {{- continue -}}
        {{- end -}}

        {{- range $field := $propagateMapKeyToFields -}}
          {{- if not (get $val $field) -}}
            {{- $_ := set $val $field $key -}}
          {{- end -}}
        {{- end -}}

        {{- $values = append $values . -}}
      {{- end -}}
    {{- end -}}

    {{- $value = $values -}}
  {{- end -}}

  {{- $value | toYaml -}}
{{- end -}}

{{- define "tenant.utils.filter-map" -}}
  {{- $map := dict -}}

  {{- range $key, $val := . | default dict -}}
    {{- if eq $val nil -}}
      {{- continue -}}
    {{- end -}}

    {{- if kindIs "map" $val -}}
      {{- $val = include "tenant.utils.filter-map" $val | fromYaml -}}
    {{- else if kindIs "slice" $val -}}
      {{- $val = include "tenant.utils.filter-list" $val | fromYamlArray -}}
    {{- end -}}

    {{- $_ := set $map $key $val -}}
  {{- end -}}

  {{- $map | toYaml -}}
{{- end -}}

{{- define "tenant.utils.filter-list" -}}
  {{- $list := list -}}

  {{- range $val := . | default list -}}
    {{- if eq $val nil -}}
      {{- continue -}}
    {{- end -}}

    {{- if kindIs "map" $val -}}
      {{- $val = include "tenant.utils.filter-map" $val | fromYaml -}}
    {{- else if kindIs "slice" $val -}}
      {{- $val = include "tenant.utils.filter-list" $val | fromYamlArray -}}
    {{- end -}}

    {{- $list = append $list $val -}}
  {{- end -}}

  {{- $list | toYaml -}}
{{- end -}}

{{- define "tenant.utils.validate-yaml" -}}
  {{- $map := . | fromYaml -}}

  {{- if $map.Error | default "" | hasPrefix "error converting YAML to JSON" -}}
    {{- fail (printf "%s. For: %s" $map.Error (quote .)) -}}
  {{- end -}}

  {{- . -}}
{{- end -}}

{{- define "tenant.utils.post-render" -}}
  {{- $map := . -}}

  {{- if typeIs "string" $map -}}
    {{- $map = fromYaml $map -}}
  {{- end -}}

  {{- $map | include "tenant.utils.filter-map" -}}
{{- end -}}

{{- define "tenant.utils.entries" -}}
  {{- $entries := list -}}

  {{- range $key, $val := . | default dict -}}
    {{- $entries = append $entries (dict
      "key" $key
      "val" $val
    ) -}}
  {{- end -}}

  {{- $entries | toYaml -}}
{{- end -}}

{{- define "tenant.utils.merge" -}}
  {{- $merged := dict -}}

  {{- range $map := . -}}
    {{- if eq $map nil -}}
      {{- continue -}}
    {{- end -}}

    {{- $merged = mustMergeOverwrite $merged (deepCopy $map) -}}
  {{- end -}}

  {{- $merged | toYaml -}}
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
  {{- $map := ternary .map (dict) (ne .map nil) -}}
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

  {{- $map | toYaml -}}
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
