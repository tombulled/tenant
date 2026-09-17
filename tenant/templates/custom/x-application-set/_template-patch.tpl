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
    (dict "name" "{{$id}}")
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

  {{- printf "{{- $defaults := `\n%s\n` | fromYaml -}}" ($defaults | toYaml) | printf "%s\n\n" }}

  {{- "{{- /* Apply defaults */ -}}" | printf "%s\n" }}
  {{- "{{- $data := mustMergeOverwrite (dict) $defaults (deepCopy .) -}}" | printf "%s\n\n" }}

  {{- "{{- /* Template name */ -}}" | printf "%s\n" }}
  {{- `{{- $_ := set $data "name" (tpl $data.name $data) -}}` | printf "%s\n\n" }}

  {{- "{{- /* Template self */ -}}" | printf "%s\n" }}
  {{- "{{- $data = tpl (toYaml $data) $data | fromYaml -}}" | printf "%s\n\n" }}

  {{- "{{- with $data -}}" | printf "%s\n" }}

  {{- /* Insert the application template */ -}}
  {{- include "tenant.application.template" $ | printf "%s\n" }}

  {{- "{{- end -}}" -}}
{{- end -}}
