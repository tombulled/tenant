{{- define "resources.app-projects" -}}
  {{- include "resources.list" (dict "root" $ "kind" "AppProject") -}}
{{- end -}}

{{- define "resources.application-sets" -}}
  {{- include "resources.list" (dict "root" $ "kind" "ApplicationSet") -}}
{{- end -}}

{{- define "resources.applications" -}}
  {{- include "resources.list" (dict "root" $ "kind" "Application") -}}
{{- end -}}

{{- define "resources.sealed-secrets" -}}
  {{- include "resources.list" (dict "root" $ "kind" "SealedSecret") -}}
{{- end -}}

{{- define "resources.limit-ranges" -}}
  {{- include "resources.list" (dict "root" $ "kind" "LimitRange") -}}
{{- end -}}

{{- define "resources.namespaces" -}}
  {{- include "resources.list" (dict "root" $ "kind" "Namespace" "includeNamespaced" false) -}}
{{- end -}}

{{- define "resources.resource-quotas" -}}
  {{- include "resources.list" (dict "root" $ "kind" "ResourceQuota") -}}
{{- end -}}

{{- define "resources.network-policies" -}}
  {{- include "resources.list" (dict "root" $ "kind" "NetworkPolicy") -}}
{{- end -}}

{{- define "resources.cluster-role-bindings" -}}
  {{- include "resources.list" (dict "root" $ "kind" "ClusterRoleBinding") -}}
{{- end -}}

{{- define "resources.cluster-roles" -}}
  {{- include "resources.list" (dict "root" $ "kind" "ClusterRole") -}}
{{- end -}}

{{- define "resources.role-bindings" -}}
  {{- include "resources.list" (dict "root" $ "kind" "RoleBinding") -}}
{{- end -}}

{{- define "resources.roles" -}}
  {{- include "resources.list" (dict "root" $ "kind" "Role") -}}
{{- end -}}
