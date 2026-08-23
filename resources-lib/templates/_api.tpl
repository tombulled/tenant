{{- define "resources-lib.registry" -}}
- app-project
- application-set
- application
- sealed-secret
- limit-range
- namespace
- resource-quota
- network-policy
- cluster-role-binding
- cluster-role
- role-binding
- role
{{- end -}}

{{- define "resources-lib.get-template" -}}
  {{- $kind := . -}}

  {{- include (printf "resources-lib.%s.template" (kebabcase $kind) nil) | trim -}}
{{- end -}}

{{- define "resources-lib.execute-template" -}}
  {{- $kind := .kind -}}
  {{- $data := .data -}}

  {{- tpl (include "resources-lib.get-template" $kind) $data -}}
{{- end -}}

{{- define "resources-lib.find" -}}
  {{- $context := .context -}}
  {{- $kind := .kind -}}

  {{- $valuesKey := .kind | include "resources-lib.utils.camel-case" | include "resources-lib.utils.pluralise" -}}
  {{- $defaultsKey := .kind | include "resources-lib.utils.camel-case" | printf "%sDefaults" -}}

  {{- $values := get $context $valuesKey -}}
  {{- $defaults := get $context $defaultsKey -}}
  {{- $defaultsList := list $context.defaults $defaults -}}

  {{- /* Build a list of enabled top-level resource datas */ -}}
  {{- $resources := include "resources-lib.list" (
    dict "values" $values "defaults" $defaultsList) | fromYamlArray -}}

  {{- $resources | toYaml -}}
{{- end -}}

{{- define "resources-lib.init" -}}
  {{- $context := .context -}}

  {{- $templates := dict
    "AppProject" "resources-lib.app-project.template"
    "ApplicationSet" "resources-lib.application-set.template"
    "Application" "resources-lib.application.template"
    "SealedSecret" "resources-lib.sealed-secret.template"
    "LimitRange" "resources-lib.limit-range.template"
    "Namespace" "resources-lib.namespace.template"
    "ResourceQuota" "resources-lib.resource-quota.template"
    "NetworkPolicy" "resources-lib.network-policy.template"
    "ClusterRoleBinding" "resources-lib.cluster-role-binding.template"
    "ClusterRole" "resources-lib.cluster-role.template"
    "RoleBinding" "resources-lib.role-binding.template"
    "Role" "resources-lib.role.template"
  -}}

  {{- $resources := list -}}

  {{- range $kind, $templateName := $templates -}}
    {{- $template := include $templateName nil | trim -}}
    {{- $resourceDatas := include "resources-lib.find" (dict
      "context" $context
      "kind" $kind
    ) | fromYamlArray -}}

    {{- range $resourceData := $resourceDatas -}}
      {{- $resource := tpl $template $resourceData -}}

      {{- $resources = append $resources $resource}}
    {{- end -}}
  {{- end -}}

  {{- range $resources }}
    {{- "---" | nindent 0 }}
    {{- . | nindent 0 }}
  {{- end }}
{{- end -}}
