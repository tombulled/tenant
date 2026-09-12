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
{{- define "tenant.x-application-set.x-git-generator.convert" -}}
  {{- $generators := .generators | default list -}}

  {{- $xGitKey := "x-git" -}}

  {{- $newGenerators := list -}}
  {{- range $generator := $generators -}}
    {{- $generator = $generator | deepCopy -}}
  
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
  
      {{- $_ := set $values "id" (printf "{{ $_ := set . \"$id\" (%s) }}" $id) -}}
  
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

    {{- $newGenerators = append $newGenerators $generator -}}
  {{- end -}}

  {{- $newGenerators | toYaml -}}
{{- end -}}
