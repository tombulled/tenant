{{- define "tenant.x-application-set.generators" -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}

  {{- $generatorTemplates := (list "convert-x-git" "wrap-with-matrix" "add-selector") -}}

  {{- with $appSet -}}
    {{- $generators := ternary (.generatorsObject | values) (.generators | default list) (not (empty .generatorsObject)) -}}

    {{- $newGenerators := list -}}
    {{- range $generator := $generators -}}
      {{- range $generatorTemplate := $generatorTemplates -}}
        {{- $generatorTemplateName := printf "tenant.x-application-set.generator.%s" $generatorTemplate -}}
        {{- $generator = include $generatorTemplateName (dict "root" $ "appSet" $appSet "generator" $generator) | fromYaml -}}
      {{- end -}}

      {{- $newGenerators = append $newGenerators $generator -}}
    {{- end -}}

    {{- $newGenerators | toYaml -}}
  {{- end -}}
{{- end -}}

{{- /* Add a match expression to the selector of all generators that filters out disabled applications */ -}}
{{- define "tenant.x-application-set.generator.add-selector" -}}
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

{{- /* Wrap each generator in a 'matrix' generator to set necessary defaults upfront (e.g. $enabled) */ -}}
{{- define "tenant.x-application-set.generator.wrap-with-matrix" -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}
  {{- $generator := .generator -}}

  {{- $defaults := include "tenant.x-application-set.application-defaults" (dict "root" $ "appSet" $appSet) | fromYaml -}}
  {{- $defaultEnabled := ne (index $defaults "$enabled") false -}}

  {{- with $generator -}}
    {{- $newGenerator := (dict
      "matrix" (dict
        "generators" (list
          .
          (dict
            "list" (dict
              "elements" (list
                (dict
                  "enabled" (printf "{{ ternary (index . \"$enabled\") %t (hasKey . \"$enabled\") }}" $defaultEnabled)
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

{{- /*
  Replace all x-git generators with the appropriate merge + git generators.

  The pseudo x-git generator accepts the following fields:
    x-git:
      repoURL: git@github.com:example/apps.git
      revision: HEAD
      directories:
        - path: "*"
      valueFiles:
        - values.yaml
        - values-type-dev.yaml
        - values-foo.yaml
      values:
        basename: "{{.path.basename}}"
      pathParamPrefix: some-prefix
      requeueAfterSeconds: 30
      template:
        metadata:
          annotations:
            some-annotation: some-val
      mergeKey: path.path
      id: .path.basename
*/ -}}
{{- define "tenant.x-application-set.generator.convert-x-git" -}}
  {{- $xGitKey := "x-git" -}}
  {{- $generator := .generator | deepCopy -}}

  {{- with get $generator $xGitKey -}}
    {{- /* Git generator fields */ -}}
    {{- $directories := .directories | required "Must provide at least one directory" -}}
    {{- $pathParamPrefix := .pathParamPrefix -}}
    {{- $repoURL := .repoURL -}}
    {{- $requeueAfterSeconds := .requeueAfterSeconds -}}
    {{- $revision := .revision -}}
    {{- $values := .values | default dict -}}

    {{- /* Merge generator fields */ -}}
    {{- $mergeKeys := .mergeKeys | default (list "path.path") -}}

    {{- /* Common (between git & merge) generator fields */ -}}
    {{- $template := .template -}}

    {{- /* X-Git generator fields */ -}}
    {{- $valueFiles := .valueFiles | required "Must provide at least one value file" -}}
    {{- $id := .id | default ".path.basename" -}}

    {{- $isMerge := gt (len $valueFiles) 1 }}

    {{- $mergeKeyMap := dict -}}
    {{- range $index := until (len $mergeKeys) -}}
      {{- $mergeKey := index $mergeKeys $index -}}
      {{- $mergeKeyAlias := printf "mergeKey%s" (ternary "" (toString $index) (eq $index 0)) -}}
      {{- $_ := set $mergeKeyMap $mergeKeyAlias $mergeKey -}}
    {{- end -}}

    {{- if $isMerge -}}
      {{- range $mergeKeyAlias, $mergeKey := $mergeKeyMap -}}
        {{- $mergeKeyValue := printf "{{ $_ := set . \"%s\" .%s }}" $mergeKeyAlias $mergeKey }}
        {{- $_ := set $values $mergeKeyAlias $mergeKeyValue -}}
      {{- end -}}
    {{- end -}}

    {{- $_ := set $values "id" (printf "{{ $_ := set . \"$id\" %s }}" $id) -}}

    {{- $gitGenerators := list -}}
    {{- range $valueFile := $valueFiles -}}
      {{- $files := list -}}
      {{- range $directory := $directories -}}
        {{- $file := deepCopy $directory -}}
        {{- $path := $file.path | trimSuffix "/" -}}
        {{- $sep := ternary "" "/" (empty $path) -}}
        {{- $_ := set $file "path" (printf "%s%s%s" $path $sep $valueFile) -}}
        {{- $files = append $files $file -}}
      {{- end -}}

      {{- $gitGenerator := (dict
        "files" $files
        "pathParamPrefix" $pathParamPrefix
        "repoURL" $repoURL
        "requeueAfterSeconds" $requeueAfterSeconds
        "revision" $revision
        "values" $values
      ) -}}

      {{- range $key, $val := $gitGenerator -}}
        {{- if eq $val nil -}}
          {{- $_ := unset $gitGenerator $key -}}
        {{- end -}}
      {{- end -}}

      {{- $gitGenerators = append $gitGenerators (dict "git" $gitGenerator) -}}
    {{- end -}}

    {{- $generatorType := "" -}}
    {{- $generatorData := dict -}}

    {{- if $isMerge -}}
      {{- $generatorType = "merge" -}}
      {{- $generatorData = (dict
        "mergeKeys" (keys $mergeKeyMap)
        "generators" $gitGenerators
      ) -}}
    {{- else -}}
      {{- $generatorType = "git" -}}
      {{- $generatorData = get (index $gitGenerators 0) "git" -}}
    {{- end -}}

    {{- if ne $template nil -}}
      {{- $_ := set $generatorData "template" $template -}}
    {{- end -}}

    {{- $_ := unset $generator $xGitKey -}}
    {{- $_ := set $generator $generatorType $generatorData -}}
  {{- end -}}

  {{- $generator | toYaml -}}
{{- end -}}
