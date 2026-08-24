{{- define "tenant.resources.applications" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" .Values.applications "defaults" .Values.applicationDefaults) -}}
{{- end -}}

{{- define "tenant.resources.application-sets" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" .Values.applicationSets "defaults" .Values.applicationSetDefaults) -}}
{{- end -}}

{{- define "tenant.resources.app-projects" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" .Values.projects "defaults" .Values.projectDefaults) -}}
{{- end -}}

{{- define "tenant.resources.cluster-role-bindings" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" .Values.clusterRoleBindings "defaults" .Values.clusterRoleBindingDefaults) -}}
{{- end -}}

{{- define "tenant.resources.cluster-roles" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" .Values.clusterRoles "defaults" .Values.clusterRoleDefaults) -}}
{{- end -}}

{{- define "tenant.resources.limit-ranges" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "limitRanges" "defaults" .Values.limitRangeDefaults) -}}
{{- end -}}

{{- define "tenant.resources.namespaces" -}}
  {{- include "tenant.resource.list" (dict "root" $ "values" .Values.namespaces "defaults" .Values.namespaceDefaults) -}}
{{- end -}}

{{- define "tenant.resources.network-policies" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "networkPolicies" "defaults" .Values.networkPolicyDefaults) -}}
{{- end -}}

{{- define "tenant.resources.resource-quotas" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "resourceQuotas" "defaults" .Values.resourceQuotaDefaults) -}}
{{- end -}}

{{- define "tenant.resources.role-bindings" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "roleBindings" "defaults" .Values.roleBindingDefaults) -}}
{{- end -}}

{{- define "tenant.resources.roles" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "roles" "defaults" .Values.roleDefaults) -}}
{{- end -}}

{{- define "tenant.resources.sealed-secrets" -}}
  {{- include "tenant.resource.list-with-namespaced" (dict "root" $ "key" "sealedSecrets" "defaults" .Values.sealedSecretDefaults) -}}
{{- end -}}
