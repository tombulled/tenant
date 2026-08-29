{{- define "tenant.resources.applications" -}}
  {{- include "tenant.resource.list" (dict "root" $ "key" "application") -}}
{{- end -}}

{{- define "tenant.resources.application-sets" -}}
  {{- include "tenant.resource.list" (dict "root" $ "key" "applicationSet") -}}
{{- end -}}

{{- define "tenant.resources.app-projects" -}}
  {{- include "tenant.resource.list" (dict "root" $ "key" "project") -}}
{{- end -}}

{{- define "tenant.resources.cluster-role-bindings" -}}
  {{- include "tenant.resource.list" (dict "root" $ "key" "clusterRoleBinding") -}}
{{- end -}}

{{- define "tenant.resources.cluster-roles" -}}
  {{- include "tenant.resource.list" (dict "root" $ "key" "clusterRole") -}}
{{- end -}}

{{- define "tenant.resources.limit-ranges" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "limitRange") -}}
{{- end -}}

{{- define "tenant.resources.namespaces" -}}
  {{- include "tenant.resource.list" (dict "root" $ "key" "namespace" "templateExclude" (list "resources")) -}}
{{- end -}}

{{- define "tenant.resources.network-policies" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "networkPolicy") -}}
{{- end -}}

{{- define "tenant.resources.resource-quotas" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "resourceQuota") -}}
{{- end -}}

{{- define "tenant.resources.role-bindings" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "roleBinding") -}}
{{- end -}}

{{- define "tenant.resources.roles" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "role") -}}
{{- end -}}

{{- define "tenant.resources.sealed-secrets" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "sealedSecret") -}}
{{- end -}}

{{- define "tenant.resources.extra-resources" -}}
  {{- include "tenant.resource.list" (dict "root" $ "key" "extraResource" "nameField" "metadata.name") -}}
{{- end -}}
