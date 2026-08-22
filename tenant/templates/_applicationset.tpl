{{- define "tenant.application-set.generators" -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}

  {{- $generatorTemplates := (list "convert-x-git" "wrap-with-matrix" "add-selector") -}}

  {{- with $appSet -}}
    {{- $generators := ternary (.generatorsObject | values) (.generators | default list) (not (empty .generatorsObject)) -}}

    {{- $newGenerators := list -}}
    {{- range $generator := $generators -}}
      {{- range $generatorTemplate := $generatorTemplates -}}
        {{- $generatorTemplateName := printf "tenant.application-set.generator.%s" $generatorTemplate -}}
        {{- $generator = include $generatorTemplateName (dict "root" $ "appSet" $appSet "generator" $generator) | fromYaml -}}
      {{- end -}}

      {{- $newGenerators = append $newGenerators $generator -}}
    {{- end -}}

    {{- $newGenerators | toYaml -}}
  {{- end -}}
{{- end -}}

{{- /* Add a match expression to the selector of all generators that filters out disabled applications */ -}}
{{- define "tenant.application-set.generator.add-selector" -}}
  {{- $matchExpression := (dict
    "key" "enabled"
    "operator" "NotIn"
    "values" (list "false")
  ) -}}

  {{- with .generator | deepCopy -}}
    {{- $_ := set . "selector" (.selector | default dict) -}}
    {{- $matchExpressions := $matchExpression | append (.selector.matchExpressions | default list) -}}
    {{- $_ := set .selector "matchExpressions" $matchExpressions -}}
    {{- . | toYaml -}}
  {{- end -}}
{{- end -}}

{{- /* Wrap each generator in a 'matrix' generator to set necessary defaults upfront (e.g. .enabled) */ -}}
{{- define "tenant.application-set.generator.wrap-with-matrix" -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}
  {{- $generator := .generator -}}

  {{- $defaults := include "tenant.application.defaults" (dict "root" $ "appSet" $appSet) | fromYaml -}}
  {{- $defaultEnabled := $defaults.enabled -}}

  {{- with $generator -}}
    {{- if ne $defaultEnabled false -}}
      {{- . | toYaml -}}
    {{- else -}}
      {{- $newGenerator := (dict
        "matrix" (dict
          "generators" (list
            .
            (dict
              "list" (dict
                "elements" (list
                  (dict
                    "enabled" $defaultEnabled
                  )
                )
              )
            )
          )
        )
      ) -}}

      {{- $newGenerator | toYaml -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /*
  Replace all x-git generators with the appropriate merge + git generators.

  The pseudo x-git generator accepts the following fields:
    x-git:
      repoURL: git@github.com:example/apps.git # required
      revision: HEAD # required
      path: "*" # optional, defaults to ""
      valueFiles: # required
        - values.yaml
        - values-type-dev.yaml
        - values-foo.yaml
      values: # optional
        basename: "{{.path.basename}}"
      mergeKey: path.path # optional, defaults to "path.path"
      idKey: path.basename # optional, defaults to "path.basename"
*/ -}}
{{- define "tenant.application-set.generator.convert-x-git" -}}
  {{- $xGitKey := "x-git" -}}
  {{- $generator := .generator | deepCopy -}}

  {{- with get $generator $xGitKey -}}
    {{- $repoURL := .repoURL | required "repoURL is required" -}}
    {{- $revision := .revision | required "revision is required" -}}
    {{- $path := .path | default "" | trimSuffix "/" -}}
    {{- $valueFiles := .valueFiles | required "valueFiles is required" -}}
    {{- $values := .values | default dict -}}
    {{- $mergeKey := .mergeKey | default "path.path" -}}
    {{- $idKey := .idKey | default "path.basename" -}}

    {{- if $path -}}
      {{- $path = printf "%s/" $path -}}
    {{- end -}}

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
              "path" (printf "%s%s" $path $valueFile)
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

  {{- $generator | toYaml -}}
{{- end -}}
