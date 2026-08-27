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

  {{- /* Insert some templating logic into the application's template that applies the application's defaults */ -}}
  {{- "{{- /* Apply defaults */ -}}" | printf "%s\n" }}
  {{- printf "{{- $defaults := `%s` | fromJson -}}" ($defaults | toJson) | printf "%s\n" }}
  {{- "{{- $_ := mustMergeOverwrite . $defaults (deepCopy .) -}}" | printf "%s\n" }}
  {{- "\n" }}

  {{- /* Insert the applicationset-specific app header */ -}}
  {{- include "tenant.application-set.app-header" $ | printf "%s\n" }}
  {{- "\n" }}

  {{- /* Insert the raw application template */ -}}
  {{- include "tenant.template.application" $ -}}
{{- end -}}
