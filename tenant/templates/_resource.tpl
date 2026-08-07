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

  {{- /* Set the resource ID */ -}}
  {{- $_ := set $data "id" $id }}

  {{- /* Only create a resource if it is enabled (defaults to enabled unless told otherwise) */ -}}
  {{- $enabled := ternary $data.enabled true (ne $data.enabled nil) -}}
  {{- if $enabled -}}
    {{- /* If unspecified, default the resource's name to the resource's ID */ -}}
    {{- if eq $data.name nil -}}
      {{- $_ := set $data "name" $id -}}
    {{- end -}}

    {{- /* Template the resource's name using the resource's data */ -}}
    {{- /* This is deliberately done first to reduce the chance of circular references */ -}}
    {{- $_ := set $data "name" (tpl (get $data "name") $data) -}}

    {{- /* Template the resource's data using itself */ -}}
    {{- $data = tpl ($data | toYaml) $data | fromYaml -}}

    {{- /* Finally, output the new resource data */ -}}
    {{- $data | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "tenant.resource.list" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $values := .values | default dict -}}
  {{- $defaults := .defaults | default dict -}}

  {{- $resourceDatas := list -}}

  {{- /* Iterate over each configured resource */ -}}
  {{- range $id, $_ := $values -}}
    {{- /* Build the resource's data */ -}}
    {{- $data := include "tenant.resource.data" (dict "root" $ "id" $id "data" . "defaults" $defaults) | fromYaml -}}

    {{- /* If the resource is enabled, append it to the list of enabled resources */ -}}
    {{- with $data -}}
      {{- $resourceDatas = append $resourceDatas . -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the resource data of the enabled resources as a YAML list */ -}}
  {{- $resourceDatas | toYaml -}}
{{- end -}}

{{- define "tenant.resource.namespaces" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" $.Values.namespaces "defaults" $.Values.namespaceDefaults) -}}
{{- end -}}

{{- define "tenant.resource.list-with-namespaced" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $key := .key -}}
  {{- $defaults := .defaults | default dict -}}

  {{- $resources := include "tenant.resource.list" (
    dict "root" $ "values" (get $.Values $key) "defaults" $defaults) | fromYamlArray -}}

  {{- $namespaces := include "tenant.resource.namespaces" $ | fromYamlArray -}}

  {{- range $namespace := $namespaces -}}
    {{- $namespacedResources := include "tenant.resource.list" (
    dict "root" $ "values" (get $namespace $key) "defaults" $defaults) | fromYamlArray -}}

    {{- range $namespacedResources -}}
      {{- $_ := set . "namespace" $namespace.name -}}
      {{- $resources = append $resources . -}}
    {{- end -}}
  {{- end -}}

  {{- $resources | toYaml -}}
{{- end -}}
