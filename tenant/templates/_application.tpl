{{- /*
  Returns a merged dict of application defaults.

  The order of precedence (lowest -> highest) is:
    * `.Values.defaults`
    * `.Values.applicationDefaults`
    * `.Values.applicationSetDefaults.defaults`
    * `.Values.applicationSets.<some-appset-id>.defaults`
*/ -}}
{{- define "tenant.application.defaults" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet | default dict -}}

  {{- /* Merge all available application defaults (appset-level defaults will only be used if appset data is provided) */ -}}
  {{- $commonDefaults := $.Values.defaults | default dict | deepCopy -}}
  {{- $appDefaults := $.Values.applicationDefaults | default dict | deepCopy -}}
  {{- $appSetDefaults := $appSet.defaults | default dict | deepCopy -}}
  {{- $defaults := mustMergeOverwrite (dict) $commonDefaults $appDefaults $appSetDefaults -}}

  {{- /* Output the merged application defaults as YAML */ -}}
  {{- $defaults | toYaml -}}
{{- end -}}

{{- /*
  Returns the entire application template.

  This will either be templated as-is in the `Application` resource's template, or will be inserted into the `templatePatch` field of ApplicationSets.
*/ -}}
{{- define "tenant.application.template" -}}
  {{- /* Extract arguments */ -}}
  {{- $ := .root -}}
  {{- $appSet := .appSet -}}

  {{- /* Add additional template logic that's appset-specific */ -}}
  {{- if ne $appSet nil -}}
    {{- /* Merge together all of the application's defaults */ -}}
    {{- $defaults := include "tenant.application.defaults" (dict "root" $ "appSet" $appSet) | fromYaml -}}

    {{- /* Insert some templating logic into the application's template that applies the application's defaults */ -}}
    {{- "{{- /* Apply defaults */ -}}" | printf "%s\n" }}
    {{- printf "{{- $defaults := `%s` | fromJson -}}" ($defaults | toJson) | printf "%s\n" }}
    {{- "{{- $_ := mustMergeOverwrite . $defaults (deepCopy .) -}}" | printf "%s\n" }}
    {{- "\n" }}

    {{- /* Insert the contents of the `files/application-template-appset-header.yaml` file */ -}}
    {{- $.Files.Get "files/application-template-appset-header.yaml" | trim | printf "%s\n" }}
    {{- "\n" }}
  {{- end -}}

  {{- /* Insert the raw application template */ -}}
  {{- include "argocd-templates.application" $ -}}
{{- end -}}
