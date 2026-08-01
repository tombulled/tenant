{{- define "tenant.application.template" -}}
  {{- "{{- /* Apply defaults */ -}}" }}
  {{- printf "{{- $commonDefaults := `%s` | fromJson -}}" ($.Values.defaults | default dict | toJson) | nindent 0 }}
  {{- printf "{{- $appDefaults := `%s` | fromJson -}}" ($.Values.applicationDefaults | default dict | toJson) | nindent 0 }}
  {{- "{{- $_ := mustMergeOverwrite . $commonDefaults $appDefaults (deepCopy .) -}}" | nindent 0 }}
  {{- "" | nindent 0}}

  {{- "{{- /* Default the application's name to its ID (if a name hasn't been specified) */ -}}" | nindent 0 }}
  {{- "{{- $_ := set . \"name\" (.name | default .id) -}}" | nindent 0 }}
  {{- "" | nindent 0 }}

  {{- $.Files.Get "files/application-template.yaml" | trim | nindent 0 }}
{{- end -}}
