{{- /*
  Build a resource's data.

  Terminology:
    "resource" - A Kubernetes resource (e.g. Application, ClusterRole, Namespace, etc.)
    "resource data" - A map containing all the fields the resource's template will be executed using.

  This nested-template does the followng:
    1. If the resource's data is `nil`, the resource is treated as disabled (and will not get created)
         This is a convenient way to quickly disable a resource, e.g:
           applications:
             my-app: ~
    2. Applies the resource's defaults.
         The order of precedence for resource data (low -> high) is:
           * `.Values.defaults`
           * `.Values.<resource-name-singular>Defaults`
           * `.Values.<resource-name-plural>.<some-id>`
         Example:
           The following values:
             defaults:
               annotations:
                 food: pizza
             applicationDefaults:
               annotations:
                 drink: coke
             applications:
               foo:
                 annotations:
                   snack: chips
           Would get merged to become:
             annotations:
               food: pizza
               drink: coke
               snack: chips
    3. Adds the resource's ID as an `id` field in the resource's data
         This means that the resource's ID can be used when self-templating the resource's data.
         For example:
           applications:
             foo: {}
         Would yield resource data of:
           id: foo
    4. Ignores any resources that are disabled.
         Important considerations:
           * Resources are enabled by default (if the `enabled` field isn't specified)
           * To disable a resource you must set `enabled: false`, e.g:
               applications:
                 foo:
                   enabled: false
    5. Defaults the resource's name to the resource's ID (if a `name` field wasn't specified)
         For example, the following resource:
           applications:
             foo: {}
         Would yield resource data of:
           id: foo
           name: foo
         Whereas, the following resource:
           applications:
             foo:
               name: bar
         Would yield resource data of:
           id: foo
           name: bar
    6. Templates the resource's name using the resource's data
        The resource's name is templated first to reduce the chance of circular references.
         For example, the following resource:
           applications:
             foo:
               name: "{{.id}}-runner"
         Would yield resource data of:
           id: foo
           name: foo-runner
    7. Templates the resource's data using itself
         For example, the following resource:
           applications:
             foo:
               name: some-cool-app
               annotations:
                 my-id-is: "{{.id}}"
                 my-name-is: "{{.name}}"
         Would yield resource data of:
           id: foo
           name: some-cool-app
           annotations:
             my-id-is: foo
             my-name-is: some-cool-app
*/ -}}
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

{{- /*
  Builds and returns a list of *enabled* resource datas.

  Parameters:
    `root` - Root context (`$`)
    `values` - List of resources, e.g. `.Values.namespaces`
    `defaults` - Map of resource defaults, e.g. `.Values.namespaceDefaults`
*/ -}}
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

{{- /*
  Builds and returns a list of *enabled* namespace resource datas.

  Accepts a single argument of the root context (`$`).
*/ -}}
{{- define "tenant.resource.namespaces" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" $.Values.namespaces "defaults" $.Values.namespaceDefaults) -}}
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
{{- define "tenant.resource.list-with-namespaced" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $key := .key -}}
  {{- $defaults := .defaults | default dict -}}

  {{- /* Build a list of enabled top-level resource datas */ -}}
  {{- $resources := include "tenant.resource.list" (
    dict "root" $ "values" (get $.Values $key) "defaults" $defaults) | fromYamlArray -}}

  {{- /* Build a list of enabled namespace resource datas */ -}}
  {{- $namespaces := include "tenant.resource.namespaces" $ | fromYamlArray -}}

  {{- /* For each namespace, also build any namespace-specific resource datas, and append those to the list */ -}}
  {{- range $namespace := $namespaces -}}
    {{- /* Create a copy of the defaults, updated to include the namespace */ -}}
    {{- $namespacedDefaults := mustMergeOverwrite (deepCopy $defaults) (dict "namespace" $namespace.name) -}}

    {{- /* Build a list of enabled namespace-specific resource datas */ -}}
    {{- $namespacedResources := include "tenant.resource.list" (
      dict "root" $ "values" (get $namespace $key) "defaults" $namespacedDefaults) | fromYamlArray -}}

    {{- /* Add all of the namespace-specific resource datas to the list of resources */ -}}
    {{- $resources = concat $resources $namespacedResources -}}
  {{- end -}}

  {{- /* Finally, output the full set of resource datas as a YAML array */ -}}
  {{- $resources | toYaml -}}
{{- end -}}
