{{- /*
  Returns a merged dict of application defaults.

  The order of precedence (lowest -> highest) is:
    * `.Values.defaults`
    * `.Values.applicationDefaults`
    * `.Values.applicationSetDefaults.defaults`
    * `.Values.applicationSets.<some-appset-id>.defaults`
*/ -}}
{{- define "tenant.x-application-set.application-defaults" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}

  {{- /* Merge all available application defaults */ -}}
  {{- $commonDefaults := $.Values.defaults | default dict | deepCopy -}}
  {{- $appDefaults := $.Values.applicationDefaults | default dict | deepCopy -}}
  {{- $appSetDefaults := $appSet.defaults | default dict | deepCopy -}}
  {{- $defaults := mustMergeOverwrite (dict) $commonDefaults $appDefaults $appSetDefaults -}}

  {{- /* Output the merged application defaults as YAML */ -}}
  {{- $defaults | toYaml -}}
{{- end -}}

{{- define "tenant.x-application-set.template-patch" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}

  {{- /* Merge together all of the application's defaults */ -}}
  {{- $defaults := include "tenant.x-application-set.application-defaults" (dict "root" $ "appSet" $appSet) | fromYaml -}}

  {{- "{{- /* Apply defaults */ -}}" | printf "%s\n" }}
  {{- printf "{{- $defaults := `%s` | fromJson -}}" ($defaults | toJson) | printf "%s\n" }}
  {{- "{{- $_ := mustMergeOverwrite . $defaults (deepCopy .) -}}" | printf "%s\n\n" }}

  {{- include "tenant.x-application-set.template-patch.template-self" $ | printf "%s\n\n" }}

  {{- /* Insert the application template */ -}}
  {{- include "tenant.template.application" $ -}}
{{- end -}}
