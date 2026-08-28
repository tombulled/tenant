{{- define "tenant.resource.data" -}}
  {{- /* Extract arguments */ -}}
  {{- $root := .root -}}
  {{- $id := .id -}}
  {{- $data := .data -}}
  {{- $defaults := .defaults | default dict -}}
  {{- $vars := .vars | default dict -}}
  {{- $hasNestedResources := ternary .hasNestedResources false (ne .hasNestedResources nil) -}}

  {{- /* If the resource data is nil, disable this resource (it is considered unwanted) */ -}}
  {{- if eq $data nil -}}
    {{- $data = dict "enabled" false -}}
  {{- end -}}

  {{- /* Apply defaults */ -}}
  {{- $data = mustMergeOverwrite (deepCopy $defaults) (deepCopy $data) -}}

  {{- /* If the resource has an ID, set the `id` field */ -}}
  {{- if ne $id nil -}}
    {{- $_ := set $data "id" $id }}
  {{- end -}}

  {{- /* Only create a resource if it is enabled (defaults to enabled unless told otherwise) */ -}}
  {{- $enabled := ternary $data.enabled true (ne $data.enabled nil) -}}
  {{- if $enabled -}}
    {{- /* If unspecified, default the resource's name to the resource's ID (if one exists) */ -}}
    {{- if and (eq $data.name nil) (ne $id nil) -}}
      {{- $_ := set $data "name" $id -}}
    {{- end -}}

    {{- /* If the resource has nested resources, remove these before self-templating, otherwise they'll get templated twice */ -}}
    {{- $nestedResources := dict -}}
    {{- if $hasNestedResources -}}
      {{- $nestedResources = $data.resources -}}
      {{- $_ := unset $data "resources" -}}
    {{- end -}}

    {{- /* Template the resource's name using the resource's data */ -}}
    {{- /* This is deliberately done first to reduce the chance of circular references */ -}}
    {{- $_ := set $data "name" (include "tenant.utils.template" (dict
      "value" (get $data "name")
      "context" $root
      "scope" $data
      "vars" $vars
    )) -}}

    {{- /* Template the resource's data using itself */ -}}
    {{- $data = include "tenant.utils.template" (dict
      "value" $data
      "context" $root
      "scope" $data
      "vars" $vars
    ) | fromYaml -}}

    {{- /* If the resource has nested resources, re-add these now that self-templating has happened */ -}}
    {{- if and $hasNestedResources (ne $nestedResources nil) -}}
      {{- $_ := set $data "resources" $nestedResources -}}
    {{- end -}}

    {{- /* Finally, output the new resource data */ -}}
    {{- $data | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "tenant.utils.get-defaults" -}}
  {{- $context := .context -}}
  {{- $key := .key -}}

  {{- $commonDefaults := $context.defaults | default dict -}}
  {{- $resourceDefaults := index $context (print $key "Defaults") | default dict -}}
  {{- $defaults := mustMergeOverwrite (deepCopy $commonDefaults) (deepCopy $resourceDefaults) -}}

  {{- $defaults | toYaml -}}
{{- end -}}

{{- define "tenant.resource.list" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $context := ternary .context $.Values (ne .context nil) -}}
  {{- $defaults := .defaults | default dict -}}
  {{- $key := .key -}}
  {{- $keyPlural := .keyPlural | default (include "tenant.utils.pluralise" $key) -}}
  {{- $vars := .vars | default dict -}}
  {{- $hasNestedResources := .hasNestedResources -}}

  {{- $value := index $context $key -}}
  {{- $values := index $context $keyPlural | default dict -}}

  {{- $contextDefaults := include "tenant.utils.get-defaults" (dict
    "context" $context
    "key" $key
  ) | fromYaml -}}
  {{- $mergedDefaults := mustMergeOverwrite (deepCopy $defaults) (deepCopy $contextDefaults) -}}

  {{- if and (ne $value nil) $values -}}
    {{- fail (printf "Specify either '%s' or '%s', not both." $key $keyPlural) -}}
  {{- end -}}

  {{- $valuesList := list -}}
  {{- if ne $value nil -}}
    {{- $valuesList = append $valuesList (dict "key" nil "val" $value) -}}
  {{- else -}}
    {{- range $key, $val := $values -}}
      {{- $valuesList = append $valuesList (dict "key" $key "val" $val) -}}
    {{- end -}}
  {{- end -}}

  {{- $resourceDatas := list -}}

  {{- /* Iterate over each configured resource */ -}}
  {{- range $valuesList -}}
    {{- $key := .key -}}
    {{- $val := .val -}}

    {{- /* Build the resource's data */ -}}
    {{- $data := include "tenant.resource.data" (dict
      "root" $
      "id" $key
      "data" $val
      "defaults" $mergedDefaults
      "vars" $vars
      "hasNestedResources" $hasNestedResources
    ) | fromYaml -}}

    {{- /* If the resource is enabled, append it to the list of enabled resources */ -}}
    {{- with $data -}}
      {{- $resourceDatas = append $resourceDatas . -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the resource data of the enabled resources as a YAML list */ -}}
  {{- $resourceDatas | toYaml -}}
{{- end -}}

{{- define "tenant.resource.list-with-namespaced" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $key := .key -}}
  {{- $keyPlural := .keyPlural -}}

  {{- /* Build a list of enabled top-level resource datas */ -}}
  {{- $resources := include "tenant.resource.list" (dict
    "root" $
    "key" $key
    "keyPlural" $keyPlural
  ) | fromYamlArray -}}

  {{- /* Build a list of enabled namespace resource datas */ -}}
  {{- $namespaces := include "tenant.resources.namespaces" $ | fromYamlArray -}}

  {{- $defaults := include "tenant.utils.get-defaults" (dict
    "context" $.Values
    "key" $key
  ) | fromYaml -}}

  {{- /* For each namespace, also build any namespace-specific resource datas, and append those to the list */ -}}
  {{- range $namespace := $namespaces -}}
    {{- /* Create a copy of the resource defaults, updated to include the namespace */ -}}
    {{- $namespacedDefaults := mustMergeOverwrite (deepCopy $defaults) (dict "namespace" $namespace.name) -}}

    {{- /* Build a list of enabled namespace-specific resource datas */ -}}
    {{- $namespacedResources := include "tenant.resource.list" (dict
      "root" $
      "context" ($namespace.resources | default dict)
      "key" $key
      "keyPlural" $keyPlural
      "vars" (dict "namespace" $namespace)
      "defaults" $namespacedDefaults
    ) | fromYamlArray -}}

    {{- /* Add all of the namespace-specific resource datas to the list of resources */ -}}
    {{- $resources = concat $resources $namespacedResources -}}
  {{- end -}}

  {{- /* Finally, output the full set of resource datas as a YAML array */ -}}
  {{- $resources | toYaml -}}
{{- end -}}
