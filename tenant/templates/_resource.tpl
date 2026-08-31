{{- define "tenant.resource.data" -}}
  {{- /* Extract arguments */ -}}
  {{- $data := .data -}}
  {{- $defaults := .defaults | default list -}}
  {{- $templateContext := .templateContext -}}
  {{- $templateVars := .templateVars | default dict -}}
  {{- $templateExclude := .templateExclude | default list -}}
  {{- $templateFirst := .templateFirst | default list -}}

  {{- /* If the resource data is nil, disable the resource */ -}}
  {{- if eq $data nil -}}
    {{- $data = dict "$enabled" false -}}
  {{- end -}}

  {{- /* Apply defaults */ -}}
  {{- $data = include "tenant.utils.merge" (append $defaults $data) | fromYaml -}}

  {{- /* Only create the resource if it is enabled (defaults to enabled) */ -}}
  {{- $enabled := index $data "$enabled" -}}
  {{- if ne $enabled false -}}
    {{- /* Remove any fields prefixed with a '$' from the resource data, and add these as template variables */ -}}
    {{- range $key, $val := $data -}}
      {{- if hasPrefix "$" $key -}}
        {{- $_ := set $templateVars (trimPrefix "$" $key) $val -}}
        {{- $_ := unset $data $key -}}
      {{- end -}}
    {{- end -}}

    {{- /* Temporarily remove any fields that should be excluded from templating */ -}}
    {{- $templateExcluded := dict -}}
    {{- range $key := $templateExclude -}}
      {{- if hasKey $data $key -}}
        {{- $_ := set $templateExcluded $key (index $data $key) -}}
        {{- $_ := unset $data $key -}}
      {{- end -}}
    {{- end -}}

    {{- /* If no template context was provided, template the data within the context of itself */ -}}
    {{- if eq $templateContext nil -}}
      {{- $templateContext = $data -}}
    {{- end -}}

    {{- /* Template fields first that should "jump the queue" */ -}}
    {{- range $key := $templateFirst -}}
      {{- $value := include "tenant.utils.dynamic-get" (dict
        "map" $data
        "keys" (splitList "." $key)
      ) -}}
      {{- $valueTemplated := include "tenant.utils.template" (dict
        "value" $value
        "context" $templateContext
        "scope" $data
        "vars" $templateVars
      ) -}}
      {{- $_ := include "tenant.utils.dynamic-set" (dict
        "map" $data
        "keys" (splitList "." $key)
        "value" $valueTemplated)
      -}}
    {{- end -}}

    {{- /* Template the resource's data using itself */ -}}
    {{- $data = include "tenant.utils.template" (dict
      "value" $data
      "context" $templateContext
      "scope" $data
      "vars" $templateVars
    ) | fromYaml -}}

    {{- /* Re-add any fields that were excluded from templating */ -}}
    {{- range $key, $val := $templateExcluded -}}
      {{- $_ := set $data $key $val -}}
    {{- end -}}

    {{- /* Finally, output the new resource data */ -}}
    {{- $data | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "tenant.resource.get-defaults" -}}
  {{- $context := .context -}}
  {{- $key := .key -}}

  {{- include "tenant.utils.merge" (list
    $context.defaults
    (index $context (print $key "Defaults"))
  ) -}}
{{- end -}}

{{- define "tenant.resource.list" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $context := ternary .context $.Values (ne .context nil) -}}
  {{- $key := .key -}}
  {{- $keyPlural := .keyPlural | default (include "tenant.utils.pluralise" $key) -}}
  {{- $defaults := .defaults | default dict -}}
  {{- $templateVars := .templateVars | default dict -}}
  {{- $templateExclude := .templateExclude -}}
  {{- $nameField := .nameField | default "name" -}}

  {{- $value := index $context $key -}}
  {{- $values := index $context $keyPlural | default dict -}}

  {{- $valuesEntries := include "tenant.utils.entries" $values | fromYamlArray -}}
  {{- if ne $value nil -}}
    {{- $valuesEntries = append $valuesEntries (dict "key" "" "val" $value) -}}
  {{- end -}}

  {{- $contextDefaults := include "tenant.resource.get-defaults" (dict
    "context" $context
    "key" $key
  ) | fromYaml -}}

  {{- $resourceDatas := list -}}

  {{- /* Iterate over each configured resource */ -}}
  {{- range $valuesEntries -}}
    {{- $id := .key -}}
    {{- $data := .val -}}

    {{- /* Build the resource's data */ -}}
    {{- $data := include "tenant.resource.data" (dict
      "data" $data
      "defaults" (list
        (include "tenant.utils.dynamic-set" (dict
          "keys" (splitList "." $nameField)
          "value" $id
        ) | fromYaml)
        $defaults
        $contextDefaults
      )
      "templateContext" $
      "templateVars" (include "tenant.utils.merge" (list
        $templateVars
        (dict "id" $id)
      ) | fromYaml)
      "templateExclude" $templateExclude
      "templateFirst" (list
        $nameField
      )
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
  {{- $nameField := .nameField -}}

  {{- /* Build a list of enabled top-level resource datas */ -}}
  {{- $resources := include "tenant.resource.list" (dict
    "root" $
    "key" $key
    "keyPlural" $keyPlural
    "nameField" $nameField
  ) | fromYamlArray -}}

  {{- /* Build a list of enabled namespace resource datas */ -}}
  {{- $namespaces := include "tenant.resources.namespaces" $ | fromYamlArray -}}

  {{- $defaults := include "tenant.resource.get-defaults" (dict
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
      "templateVars" (dict "namespace" $namespace)
      "defaults" $namespacedDefaults
      "nameField" $nameField
    ) | fromYamlArray -}}

    {{- /* Add all of the namespace-specific resource datas to the list of resources */ -}}
    {{- $resources = concat $resources $namespacedResources -}}
  {{- end -}}

  {{- /* Finally, output the full set of resource datas as a YAML array */ -}}
  {{- $resources | toYaml -}}
{{- end -}}
