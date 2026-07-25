{{- define "tenant.application.template" -}}
  {{- "{{- /* Apply defaults */ -}}" }}
  {{- printf "{{- $commonDefaults := `%s` | fromJson -}}" ($.Values.defaults | default dict | toJson) | nindent 0 }}
  {{- printf "{{- $appDefaults := `%s` | fromJson -}}" ($.Values.applicationDefaults | default dict | toJson) | nindent 0 }}
  {{- "{{- $_ := mustMergeOverwrite . $commonDefaults $appDefaults (deepCopy .) -}}" | nindent 0 }}
  {{- "" | nindent 0}}

  {{- "{{- /* Default the application's name to its ID (if a name hasn't been specified) */ -}}" | nindent 0 }}
  {{- "{{- $_ := set . \"name\" (.name | default .id) -}}" | nindent 0 }}
  {{- "" | nindent 0 }}

  {{- $.Files.Get "files/application-template.yaml" | trim | nindent 0 }}
{{- end -}}

{{- define "tenant.resource.data" -}}
  {{- /* Extract arguments */ -}}
  {{- $root := .root -}}
  {{- $id := .id -}}
  {{- $data := .data -}}
  {{- $defaults := .defaults | default dict -}}

  {{- /* If the resource data is nil, disable this resource (it is considered unwanted) */ -}}
  {{- if eq $data nil -}}
    {{- $data = dict "enabled" false -}}
  {{- end -}}

  {{- /* Apply defaults */ -}}
  {{- $commonDefaults := $root.Values.defaults | default dict -}}
  {{- $data = mustMergeOverwrite (deepCopy $commonDefaults) (deepCopy $defaults) (deepCopy $data) -}}

  {{- /* Only create a resource if it is enabled (defaults to enabled unless told otherwise) */ -}}
  {{- $enabled := ternary $data.enabled true (ne $data.enabled nil) -}}
  {{- if $enabled -}}
    {{- /* If unspecified, default the resource's name to the resource's ID */ -}}
    {{- if eq $data.name nil -}}
      {{- $_ := set $data "name" $id -}}
    {{- end -}}

    {{- /* Template the resource's data using itself */ -}}
    {{- $data = tpl ($data | toYaml) $data | fromYaml -}}

    {{- /* Finally, output the new resource data */ -}}
    {{- $data | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "tenant.resource.list" -}}
  {{- $ := .root -}}
  {{- $values := .values | default dict -}}
  {{- $defaults := .defaults | default dict -}}

  {{- $resourceDatas := list -}}

  {{- /* Iterate over each configured resource */ -}}
  {{- range $id, $_ := $values -}}
    {{- /* Build the resource's data */ -}}
    {{- $data := include "tenant.resource.data" (dict "root" $ "id" $id "data" . "defaults" $defaults) | fromYaml -}}

    {{- /* If the resource is enabled, append it to the list of enabled resources */ -}}
    {{- if $data -}}
      {{- $resourceDatas = append $resourceDatas $data -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the resource data of the enabled resources as a YAML list */ -}}
  {{- $resourceDatas | toYaml -}}
{{- end -}}
