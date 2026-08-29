{{- define "tenant.resource.data" -}}
  {{- /* Extract arguments */ -}}
  {{- $id := .id -}}
  {{- $data := .data -}}
  {{- $defaults := .defaults | default dict -}}
  {{- $templateContext := .templateContext -}}
  {{- $templateVars := .templateVars | default dict -}}
  {{- $templateExclude := .templateExclude | default list -}}
  {{- $nameField := .nameField -}}

  {{- /* Internal fields */ -}}
  {{- $fieldId := "$id" -}}
  {{- $fieldEnabled := "$enabled" -}}

  {{- /* If the resource data is nil, disable the resource */ -}}
  {{- if eq $data nil -}}
    {{- $data = dict $fieldEnabled false -}}
  {{- end -}}

  {{- /* Apply defaults */ -}}
  {{- $data = mustMergeOverwrite (deepCopy $defaults) (deepCopy $data) -}}

  {{- /* Only create the resource if it is enabled (defaults to enabled) */ -}}
  {{- $enabled := index $data $fieldEnabled -}}
  {{- if ne $enabled false -}}
    {{- /* If a resource ID was specified in the data, we'll respect that */ -}}
    {{- if hasKey $data $fieldId -}}
      {{- $id = index $data $fieldId -}}
    {{- end -}}

    {{- /* If the resource has an ID, but no name, default the resource's name to the resource's ID */ -}}
    {{- if ne $nameField nil -}}
      {{- $name := include "tenant.utils.dynamic-get" (dict "map" $data "keys" (splitList "." $nameField)) -}}
      {{- if and (ne $id nil) (not $name) -}}
        {{- $_ := include "tenant.utils.dynamic-set" (dict "map" $data "keys" (splitList "." $nameField) "value" $id) -}}
      {{- end -}}
    {{- end -}}

    {{- /* Set the resource ID as a template variable */ -}}
    {{- $_ := set $templateVars "id" $id -}}

    {{- /* Remove any fields prefixed with a '$' from the resource data, and add these as template variables */ -}}
    {{- range $key, $val := $data -}}
      {{- if hasPrefix "$" $key -}}
        {{- $_ := unset $data $key -}}
        {{- $_ := set $templateVars (trimPrefix "$" $key) $val -}}
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

    {{- /* Template the resource's name using the resource's data */ -}}
    {{- /* This is deliberately done first to reduce the chance of circular references */ -}}
    {{- if ne $nameField nil -}}
      {{- $name := include "tenant.utils.dynamic-get" (dict "map" $data "keys" (splitList "." $nameField)) -}}
      {{- $templatedName := include "tenant.utils.template" (dict
        "value" $name
        "context" $templateContext
        "scope" $data
        "vars" $templateVars
      ) -}}
      {{- $_ := include "tenant.utils.dynamic-set" (dict "map" $data "keys" (splitList "." $nameField) "value" $templatedName) -}}
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
  {{- $templateVars := .templateVars | default dict -}}
  {{- $templateExclude := .templateExclude -}}
  {{- $nameField := .nameField | default "name" -}}

  {{- $value := index $context $key -}}
  {{- $values := index $context $keyPlural | default dict -}}

  {{- $contextDefaults := include "tenant.resource.get-defaults" (dict
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
      "id" $key
      "data" $val
      "defaults" $mergedDefaults
      "templateContext" $
      "templateVars" $templateVars
      "templateExclude" $templateExclude
      "nameField" $nameField
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
