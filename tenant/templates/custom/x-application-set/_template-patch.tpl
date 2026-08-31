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

  {{- include "tenant.utils.merge" (list
    (include "tenant.resource.get-defaults" (dict
      "context" $.Values
      "key" "application"
    ) | fromYaml)
    $appSet.defaults
  ) -}}
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

  {{- "{{- /* Default the application's name to its ID (if a name hasn't been specified) */ -}}" | printf "%s\n" -}}
  {{- `{{- $_ := set . "name" (.name | default (get . "$id")) -}}` | printf "%s\n\n" -}}

  {{- include "tenant.x-application-set.template-patch.template-self" $ | printf "%s\n\n" }}

  {{- /* Insert the application template */ -}}
  {{- include "tenant.template.application" $ -}}
{{- end -}}
