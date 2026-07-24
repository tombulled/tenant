{{- define "tenant.application.template" -}}
  {{- "{{- /* Apply defaults */ -}}" }}
  {{- printf "{{- $commonDefaults := `%s` | fromJson -}}" ($.Values.defaults | default dict | toJson) | nindent 0 }}
  {{- printf "{{- $appDefaults := `%s` | fromJson -}}" ($.Values.applicationDefaults | default dict | toJson) | nindent 0 }}
  {{- "{{- $_ := mustMergeOverwrite . $commonDefaults $appDefaults (deepCopy .) -}}" | nindent 0 }}
  {{- "" | nindent 0}}

  {{- $.Files.Get "files/application-template.yaml" | trim | nindent 0 }}
{{- end -}}

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
  {{- $commonDefaults := $root.Values.defaults | default dict }}
  {{- $data = mustMergeOverwrite (deepCopy $commonDefaults) (deepCopy $defaults) (deepCopy $data) }}

  {{- /* Only create a resource if it is enabled (defaults to enabled unless told otherwise) */ -}}
  {{- $enabled := ternary $data.enabled true (ne $data.enabled nil) }}
  {{- if $enabled -}}
    {{- /* If unspecified, default the resource's name to the resource's ID */ -}}
    {{- if eq $data.name nil -}}
      {{- $_ := set $data "name" $id -}}
    {{- end -}}

    {{- /* Template the resource's data using itself */ -}}
    {{- $data = tpl ($data | toYaml) $data | fromYaml -}}

    {{- /* Finally, output the new resource data */ -}}
    {{- $data | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "tenant.application-set.generator.add-selector" -}}
  {{- $matchExpression := (dict
    "key" "enabled"
    "operator" "NotIn"
    "values" (list "false")
  ) -}}

  {{- with deepCopy . -}}
    {{- $_ := set . "selector" (.selector | default dict) -}}
    {{- $matchExpressions := $matchExpression | append (.selector.matchExpressions | default list) -}}
    {{- $_ := set .selector "matchExpressions" $matchExpressions -}}

    {{- . | toYaml -}}
  {{- end -}}
{{- end -}}

{{- define "tenant.application-set.generator.convert-x-git" -}}
{{- end -}}

{{- define "tenant.application-set.generators" -}}
  {{- $generators := ternary (.generatorsObject | values) (.generators | default list) (not (empty .generatorsObject)) -}}

  {{- /* Add a match expression to the selector of all generators that filters out disabled applications */ -}}
  {{- range $generator := $generators -}}
      {{- $generator = include "tenant.application-set.generator.add-selector" $generator | fromYaml -}}
  {{- end -}}

  {{- /* Replace all x-git generators with the appropriate merge + git generators */ -}}
  {{- $xGitKey := "x-git" -}}
  {{- range $generator := $generators -}}
    {{- $xGit := get $generator $xGitKey -}}

    {{- if eq $xGit nil -}}
      {{- continue -}}
    {{- end -}}

    {{- $repoURL := $xGit.repoURL | required "repoURL is required" -}}
    {{- $revision := $xGit.revision | required "revision is required" -}}
    {{- $path := $xGit.path | default "" | trimSuffix "/" -}}
    {{- $valueFiles := $xGit.valueFiles | required "valueFiles is required" -}}
    {{- $values := $xGit.values | default dict -}}
    {{- $mergeKey := $xGit.mergeKey | default "path.path" -}}
    {{- $idKey := $xGit.idKey | default "path.basename" -}}

    {{- if eq (len $valueFiles) 0 -}}
      {{- fail "Must provide at least one value file" -}}
    {{- end -}}

    {{- $_ := set $values "mergeKey" (printf "{{ $_ := set . \"mergeKey\" .%s }}" $mergeKey) -}}
    {{- $_ := set $values "id" (printf "{{ $_ := set . \"id\" .%s }}" $idKey) -}}

    {{- $gitGenerators := list -}}
    {{- range $valueFile := $valueFiles -}}
      {{- $gitGenerator := (dict
        "git" (dict
          "repoURL" $repoURL
          "revision" $revision
          "files" (list
            (dict
              "path" (printf "%s/%s" $path $valueFile)
            )
          )
          "values" $values
        )
      ) -}}

      {{- $gitGenerators = append $gitGenerators $gitGenerator -}}
    {{- end -}}

    {{- $generatorType := "" -}}
    {{- $generatorData := dict -}}

    {{- if eq (len $gitGenerators) 1 -}}
      {{- $generatorType = "git" -}}
      {{- $generatorData = get (index $gitGenerators 0) "git" -}}
    {{- else -}}
      {{- $generatorType = "merge" -}}
      {{- $generatorData = (dict
        "mergeKeys" (list "mergeKey")
        "generators" $gitGenerators
      ) -}}
    {{- end -}}

    {{- $_ := unset $generator $xGitKey -}}
    {{- $_ := set $generator $generatorType $generatorData -}}
  {{- end -}}

  {{- $generators | toYaml -}}
{{- end -}}
