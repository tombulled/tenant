{{- define "build-extensions" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $path := .path -}}

  {{- /* For each file in the path (globbed) */ -}}
  {{- range $path, $_ := $.Files.Glob $path -}}
    {{- /* Generate an extension ID by stripping the file extension (e.g. foo.yaml -> foo) */ -}}
    {{- $extensionId := $path | base | splitList "." | first }}

    {{- /* Output a template block including the application extension's contents */ -}}
    {{- printf "{{- /* %s */ -}}" $path | nindent 0 }}
    {{- printf "{{- block \"application.extension.%s\" . -}}" $extensionId | nindent 0 }}
    {{- $.Files.Get $path | trim | nindent 2 }}
    {{- "{{- end -}}" | nindent 0 }}
    {{- "" | nindent 0 }}
  {{- end -}}
{{- end -}}

{{- define "application-template" -}}
  {{- "{{- /* Apply defaults */ -}}" | nindent 0 }}
  {{- printf "{{- $commonDefaults := `%s` | fromJson -}}" ($.Values.common | toJson) | nindent 0 }}
  {{- printf "{{- $appDefaults := `%s` | fromJson -}}" ($.Values.applicationDefaults | toJson) | nindent 0 }}
  {{- "{{- $applicationData := mustMergeOverwrite $commonDefaults $appDefaults (deepCopy .) -}}" | nindent 0 }}
  {{- "" | nindent 0 }}

  {{- "{{- /* Set the application name if unspecified */ -}}" | nindent 0 }}
  {{- "{{- $_ := set $applicationData \"name\" ($applicationData.name | default $applicationData.id) -}}" | nindent 0 }}
  {{- "" | nindent 0 }}

  {{- "{{- with $applicationData -}}" | nindent 0 }}
    {{- include "build-extensions" (dict "root" $ "path" "files/application-extensions/*.tpl") | trim | nindent 0 }}
    {{- "" | nindent 0 }}

    {{- $.Files.Get "files/application-template.yaml" | trim | nindent 0 }}
  {{- "{{- end -}}" | nindent 0 }}
{{- end -}}

{{- define "build-resource-data" -}}
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
  {{- $data = mustMergeOverwrite (deepCopy $root.Values.common) (deepCopy $defaults) (deepCopy $data) }}

  {{- /* Set the resource ID */ -}}
  {{- $_ := set $data "id" $id }}

  {{- /* Only create a resource if it is enabled (defaults to enabled unless told otherwise) */ -}}
  {{- $enabled := ternary $data.enabled true (ne $data.enabled nil) }}
  {{- if $enabled -}}
    {{- /* If unspecified, default the resource's name to the resource's ID */ -}}
    {{- if eq $data.name nil -}}
      {{- $_ := set $data "name" $id -}}
    {{- end -}}

    {{- /* Template the resource's data using itself (inception!) */ -}}
    {{- $data = tpl ($data | toYaml) $data | fromYaml -}}

    {{- /* Finally, output the new resource data */ -}}
    {{- $data | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "namespaces" -}}
  {{- $namespaces := list -}}

  {{- /* Iterate over each configured namespace */ -}}
  {{- range $id, $_ := .Values.namespaces -}}
    {{- /* Build the namespace's resource data */ -}}
    {{- $namespace := include "build-resource-data" (dict "root" $ "id" $id "data" . "defaults" $.Values.namespaceDefaults) | fromYaml -}}

    {{- /* If the namespace is enabled, append it to the list of enabled namespaces */ -}}
    {{- if $namespace -}}
      {{- $namespaces = append $namespaces $namespace -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the resource data of the enabled namespaces as a YAML list */ -}}
  {{- $namespaces | toYaml -}}
{{- end -}}
