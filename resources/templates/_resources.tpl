{{- define "resources.app-projects" -}}
  {{- include "resources.list" (dict "root" $ "values" .Values.appProjects "defaults" .Values.appProjectDefaults) -}}
{{- end -}}

{{- define "resources.applications" -}}
  {{- include "resources.list" (dict "root" $ "values" .Values.applications "defaults" .Values.applicationDefaults) -}}
{{- end -}}

{{- define "resources.application-sets" -}}
  {{- include "resources.list" (dict "root" $ "values" .Values.applicationSets "defaults" .Values.applicationSetDefaults) -}}
{{- end -}}

{{- define "resources.sealed-secrets" -}}
  {{- include "resources.list-with-namespaced" (dict "root" $ "key" "sealedSecrets" "defaults" .Values.sealedSecretDefaults) -}}
{{- end -}}

{{- define "resources.namespaces" -}}
  {{- include "resources.list" (dict "root" $ "values" .Values.namespaces "defaults" .Values.namespaceDefaults) -}}
{{- end -}}
