{{- $xGitKey := "x-git" -}}

{{- range $generator := (.generators | default list) -}}
  {{- $xGit := get $generator $xGitKey -}}

  {{- if not $xGit -}}
    {{- continue -}}
  {{- end -}}

  {{- $values := $xGit.values | default dict -}}
  {{- $_ := set $values "mergeKey" (printf "{{ $_ := set . \"mergeKey\" .%s }}" ($xGit.mergeKey | default "path.path")) -}}
  {{- $_ := set $values "id" (printf "{{ $_ := set . \"id\" .%s }}" ($xGit.idKey | default "path.basename")) -}}

  {{- $gitGenerators := list -}}

  {{- range $valueFile := $xGit.valueFiles | default list -}}
    {{- $gitGenerator := (dict
      "git" (dict
        "repoURL" $xGit.repoURL
        "revision" $xGit.revision
        "files" (list
          (dict
            "path" (printf "%s/%s" $xGit.path $valueFile)
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
