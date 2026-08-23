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
{{- define "resources.list" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $kind := .kind -}}
  {{- $includeNamespaced := ternary .includeNamespaced true (ne .includeNamespaced nil) -}}

  {{- $valuesKey := .kind | include "resources.utils.camel-case" | include "resources.utils.pluralise" -}}
  {{- $defaultsKey := .kind | include "resources.utils.camel-case" | printf "%sDefaults" -}}

  {{- $values := get $.Values $valuesKey -}}
  {{- $defaults := get $.Values $defaultsKey -}}
  {{- $defaultsList := list $.Values.defaults $defaults -}}

  {{- /* Build a list of enabled top-level resource datas */ -}}
  {{- $resources := include "resources-lib.list" (
    dict "values" $values "defaults" $defaultsList) | fromYamlArray -}}

  {{- if $includeNamespaced -}}
    {{- /* Build a list of enabled namespace resource datas */ -}}
    {{- $namespaces := include "resources.namespaces" $ | fromYamlArray -}}

    {{- /* For each namespace, also build any namespace-specific resource datas, and append those to the list */ -}}
    {{- range $namespace := $namespaces -}}
      {{- /* Build a list of enabled namespace-specific resource datas */ -}}
      {{- $namespacedResources := include "resources-lib.list" (
        dict "root" $ "values" (get $namespace $valuesKey) "defaults" $defaultsList) | fromYamlArray -}}

      {{- /* For each namespace-specific resource data, set the namespace and append it to the list of resources */ -}}
      {{- range $namespacedResources -}}
        {{- $_ := set . "namespace" $namespace.name -}}
        {{- $resources = append $resources . -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Finally, output the full set of resource datas as a YAML array */ -}}
  {{- $resources | toYaml -}}
{{- end -}}
