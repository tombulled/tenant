{{- if .Values.__test_application_template -}}
{{ include "application-template" $ }}
{{- end -}}
