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
    {{- if $hasNestedResources -}}
      {{- $_ := set $data "resources" $nestedResources -}}
    {{- end -}}

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
  {{- $context := .context | default $.Values -}}
  {{- $key := .key -}}
  {{- $keyPlural := .keyPlural | default (include "tenant.utils.pluralise" $key) -}}
  {{- $vars := .vars | default dict -}}
  {{- $hasNestedResources := .hasNestedResources -}}

  {{- $value := index $context $key -}}
  {{- $values := index $context $keyPlural | default dict -}}
  {{- $commonDefaults := $context.defaults | default dict -}}
  {{- $resourceDefaults := index $context (print $key "Defaults") | default dict -}}
  {{- $defaults := mustMergeOverwrite (deepCopy $commonDefaults) (deepCopy $resourceDefaults) -}}

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
      "defaults" $defaults
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
  {{- $keyPlural := .keyPlural -}}

  {{- /* Build a list of enabled top-level resource datas */ -}}
  {{- $resources := include "tenant.resource.list" (dict
    "root" $
    "key" $key
    "keyPlural" $keyPlural
  ) | fromYamlArray -}}

  {{- /* Build a list of enabled namespace resource datas */ -}}
  {{- $namespaces := include "tenant.resources.namespaces" $ | fromYamlArray -}}

  {{- /* For each namespace, also build any namespace-specific resource datas, and append those to the list */ -}}
  {{- range $namespace := $namespaces -}}
    {{- /* Build a list of enabled namespace-specific resource datas */ -}}
    {{- $namespacedResources := include "tenant.resource.list" (dict
      "root" $
      "context" ($namespace.resources | default dict)
      "key" $key
      "keyPlural" $keyPlural
      "vars" (dict "namespace" $namespace)
    ) | fromYamlArray -}}

    {{- /* For each namespace-specific resource data, set the namespace and append it to the list of resources */ -}}
    {{- range $namespacedResources -}}
      {{- $_ := set . "namespace" $namespace.name -}}
      {{- $resources = append $resources . -}}
    {{- end -}}
  {{- end -}}

  {{- /* Finally, output the full set of resource datas as a YAML array */ -}}
  {{- $resources | toYaml -}}
{{- end -}}
