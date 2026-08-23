{{- /*
  Builds and returns a list of *enabled* resource datas.

  Parameters:
    `root` - Root context (`$`)
    `values` - List of resources, e.g. `.Values.namespaces`
    `defaults` - Map of resource defaults, e.g. `.Values.namespaceDefaults`
*/ -}}
{{- define "resources.list" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $values := .values | default dict -}}
  {{- $defaults := .defaults | default dict -}}

  {{- $resourceDatas := list -}}

  {{- /* Iterate over each configured resource */ -}}
  {{- range $id, $_ := $values -}}
    {{- /* Build the resource's data */ -}}
    {{- $data := include "resources.data" (dict "root" $ "id" $id "data" . "defaults" $defaults) | fromYaml -}}

    {{- /* If the resource is enabled, append it to the list of enabled resources */ -}}
    {{- with $data -}}
      {{- $resourceDatas = append $resourceDatas . -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the resource data of the enabled resources as a YAML list */ -}}
  {{- $resourceDatas | toYaml -}}
{{- end -}}

{{- /*
  Builds and returns a list of *enabled* resource datas, *including* any attached to namespaces.
  
  Parameters:
    `root` - The root context
    `key` - The key identifiying the list of resources, e.g. "namespaces", "networkPolicies", etc.
    `defaults` - Map of resource-specific defaults, e.g. `.Values.namespaceDefaults`
  
  For example:
    resourceQuotas:
      a: {}
    namespaces:
      b:
        resourceQuotas:
          c: {}
  Would output the following ResourceQuota resource datas:
    - id: a
      name: a
    - id: c
      name: c
      namespace: b
*/ -}}
{{- define "resources.list-with-namespaced" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $key := .key -}}
  {{- $defaults := .defaults | default dict -}}

  {{- /* Build a list of enabled top-level resource datas */ -}}
  {{- $resources := include "resources.list" (
    dict "root" $ "values" (get $.Values $key) "defaults" $defaults) | fromYamlArray -}}

  {{- /* Build a list of enabled namespace resource datas */ -}}
  {{- $namespaces := include "resources.namespaces" $ | fromYamlArray -}}

  {{- /* For each namespace, also build any namespace-specific resource datas, and append those to the list */ -}}
  {{- range $namespace := $namespaces -}}
    {{- /* Build a list of enabled namespace-specific resource datas */ -}}
    {{- $namespacedResources := include "resources.list" (
    dict "root" $ "values" (get $namespace $key) "defaults" $defaults) | fromYamlArray -}}

    {{- /* For each namespace-specific resource data, set the namespace and append it to the list of resources */ -}}
    {{- range $namespacedResources -}}
      {{- $_ := set . "namespace" $namespace.name -}}
      {{- $resources = append $resources . -}}
    {{- end -}}
  {{- end -}}

  {{- /* Finally, output the full set of resource datas as a YAML array */ -}}
  {{- $resources | toYaml -}}
{{- end -}}
