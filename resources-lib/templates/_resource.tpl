{{- /*
  Build a resource's data.

  Terminology:
    "resource" - A Kubernetes resource (e.g. Role, Namespace, etc.)
    "resource data" - A map containing all the fields the resource's template will be executed using.

  This nested-template does the followng:
    1. If the resource's data is `nil`, the resource is treated as disabled (and will not get created)
         This is a convenient way to quickly disable a resource, e.g:
           namespaces:
             my-ns: ~
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
             namespaceDefaults:
               annotations:
                 drink: coke
             namespaces:
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
           namespaces:
             foo: {}
         Would yield resource data of:
           id: foo
    4. Ignores any resources that are disabled.
         Important considerations:
           * Resources are enabled by default (if the `enabled` field isn't specified)
           * To disable a resource you must set `enabled: false`, e.g:
               namespaces:
                 foo:
                   enabled: false
    5. Defaults the resource's name to the resource's ID (if a `name` field wasn't specified)
         For example, the following resource:
           namespaces:
             foo: {}
         Would yield resource data of:
           id: foo
           name: foo
         Whereas, the following resource:
           namespaces:
             foo:
               name: bar
         Would yield resource data of:
           id: foo
           name: bar
    6. Templates the resource's name using the resource's data
        The resource's name is templated first to reduce the chance of circular references.
         For example, the following resource:
           namespaces:
             foo:
               name: "{{.id}}-runner"
         Would yield resource data of:
           id: foo
           name: foo-runner
    7. Templates the resource's data using itself
         For example, the following resource:
           namespaces:
             foo:
               name: some-cool-ns
               annotations:
                 my-id-is: "{{.id}}"
                 my-name-is: "{{.name}}"
         Would yield resource data of:
           id: foo
           name: some-cool-ns
           annotations:
             my-id-is: foo
             my-name-is: some-cool-ns
*/ -}}
{{- define "resources.data" -}}
  {{- /* Extract arguments */ -}}
  {{- $id := .id -}}
  {{- $data := .data -}}
  {{- $defaults := .defaults | default list -}}

  {{- /* If the resource data is nil, disable this resource (it is considered unwanted) */ -}}
  {{- if eq $data nil -}}
    {{- $data = dict "enabled" false -}}
  {{- end -}}

  {{- /* Apply defaults */ -}}
  {{- $datasToMerge := append $defaults $data -}}
  {{- $data := dict -}}
  {{- range $dataToMerge := $datasToMerge -}}
    {{- $data = mustMergeOverwrite $data ($dataToMerge | default dict | deepCopy) -}}
  {{- end -}}

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
    `values` - Map of resources (e.g. `{"foo": {}, "bar": {}}`)
    `defaults` - List of resource defaults to apply to each resource (in ascending order of precedence)
*/ -}}
{{- define "resources.list" -}}
  {{- /* Extract arguments */ -}}
  {{- $values := .values | default dict -}}
  {{- $defaults := .defaults | default list -}}

  {{- $resourceDatas := list -}}

  {{- /* Iterate over each configured resource */ -}}
  {{- range $id, $_ := $values -}}
    {{- /* Build the resource's data */ -}}
    {{- $data := include "resources.data" (dict
        "id" $id
        "data" .
        "defaults" $defaults
    ) | fromYaml -}}

    {{- /* If the resource is enabled, append it to the list of enabled resources */ -}}
    {{- with $data -}}
      {{- $resourceDatas = append $resourceDatas . -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the resource data of the enabled resources as a YAML list */ -}}
  {{- $resourceDatas | toYaml -}}
{{- end -}}
