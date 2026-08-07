{{- define "tenant.application.defaults" -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet | default dict -}}

  {{- $commonDefaults := $.Values.defaults | default dict | deepCopy -}}
  {{- $appDefaults := $.Values.applicationDefaults | default dict | deepCopy -}}
  {{- $appSetDefaults := $appSet.defaults | default dict | deepCopy -}}
  {{- $defaults := mustMergeOverwrite (dict) $commonDefaults $appDefaults $appSetDefaults -}}

  {{- $defaults | toYaml -}}
{{- end -}}

{{- define "tenant.application.template" -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}

  {{- if $appSet -}}
    {{- $defaults := include "tenant.application.defaults" (dict "root" $ "appSet" $appSet) | fromYaml -}}

    {{- "{{- /* Apply defaults */ -}}" }}
    {{- printf "{{- $defaults := `%s` | fromJson -}}" ($defaults | toJson) | nindent 0 }}
    {{- "{{- $_ := mustMergeOverwrite . $defaults (deepCopy .) -}}" | nindent 0 }}
    {{- "" | nindent 0}}

    {{- "{{- /* Default the application's name to its ID (if a name hasn't been specified) */ -}}" | nindent 0 }}
    {{- "{{- $_ := set . \"name\" (.name | default .id) -}}" | nindent 0 }}
    {{- "" | nindent 0 }}
  {{- end -}}

  {{- $.Files.Get "files/application-template.yaml" | trim | nindent 0 }}
{{- end -}}
