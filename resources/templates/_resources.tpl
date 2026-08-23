{{- define "resources.app-projects" -}}
  {{- include "resources.list" (dict "root" $ "values" .Values.appProjects "defaults" .Values.appProjectDefaults) -}}
{{- end -}}
