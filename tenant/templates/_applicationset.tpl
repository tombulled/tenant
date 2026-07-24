{{- define "tenant.application-set.generators" -}}
  {{- $generators := ternary (.generatorsObject | values) (.generators | default list) (not (empty .generatorsObject)) -}}

  {{- range $generators -}}
    {{- /* Add a match expression to the selector of all generators that filters out disabled applications */ -}}
    {{- include "tenant.application-set.generator.add-selector" . -}}

    {{- /* Replace all x-git generators with the appropriate merge + git generators */ -}}
    {{- include "tenant.application-set.generator.convert-x-git" . -}}
  {{- end -}}

  {{- $generators | toYaml -}}
{{- end -}}

{{- define "tenant.application-set.generator.add-selector" -}}
  {{- $matchExpression := (dict
    "key" "enabled"
    "operator" "NotIn"
    "values" (list "false")
  ) -}}

  {{- $_ := set . "selector" (.selector | default dict) -}}
  {{- $matchExpressions := $matchExpression | append (.selector.matchExpressions | default list) -}}
  {{- $_ := set .selector "matchExpressions" $matchExpressions -}}
{{- end -}}

{{- define "tenant.application-set.generator.convert-x-git" -}}
  {{- $xGitKey := "x-git" -}}

  {{- with get . $xGitKey -}}
    {{- $repoURL := .repoURL | required "repoURL is required" -}}
    {{- $revision := .revision | required "revision is required" -}}
    {{- $path := .path | default "" | trimSuffix "/" -}}
    {{- $valueFiles := .valueFiles | required "valueFiles is required" -}}
    {{- $values := .values | default dict -}}
    {{- $mergeKey := .mergeKey | default "path.path" -}}
    {{- $idKey := .idKey | default "path.basename" -}}

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

    {{- $_ := unset $ $xGitKey -}}
    {{- $_ := set $ $generatorType $generatorData -}}
  {{- end -}}
{{- end -}}
