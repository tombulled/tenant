# Additional Resources

Up to now the `tenant` chart is only capable of creating `Application` and `ApplicationSet` resources, which is great for a regular app-of-apps.

However, in a typical scenario, it's likely that a tenant will actually need many other types of resources, such as:

* [`AppProject`](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/) - Provide a logical grouping of applications, which is useful when Argo CD is used by multiple teams.
* [`LimitRange`](https://kubernetes.io/docs/concepts/policy/limit-range/) - A policy to constrain the resource allocations (limits and requests) that you can specify for each applicable object kind (such as Pod or PersistentVolumeClaim) in a namespace.
* [`Namespace`](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) - Provide a mechanism for isolating groups of resources within a single cluster.
* [`NetworkPolicy`](https://kubernetes.io/docs/concepts/services-networking/network-policies/) - Provide a mechanism to control traffic flow at the IP address or port level (OSI layer 3 or 4), NetworkPolicies allow you to specify rules for traffic flow within your cluster, and also between Pods and the outside world.
* [`ResourceQuota`](https://kubernetes.io/docs/concepts/policy/resource-quotas/) - Provide constraints that limit aggregate resource consumption per namespace.
* And more!

Fortunately, as these are just additional *resources*, all we really need to do is create a template for them and make use of the existing `tenant.resource.data` helper!

## Implementing a Solution

### Per-Tenant Resources

#### AppProject

By using a combination of ArgoCD's [Project Specification Reference](https://argo-cd.readthedocs.io/en/stable/operator-manual/project-specification/) and `kubectl explain appproject`, we can create the following template for a project:

```yaml title="templates/appprojects.yaml"
{{- range $id, $_ := .Values.projects }}
{{- with include "tenant.resource.data" (dict "root" $ "id" $id "data" . "defaults" $.Values.projectDefaults) | fromYaml }}
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
  name: {{ .name }}
  {{- with .namespace }}
  namespace: {{ . }}
  {{- end }}
  {{- with .finalizers }}
  finalizers: {{- . | toYaml | nindent 4 }}
  {{- end }}
spec:
  {{- if ne .permitOnlyProjectScopedClusters nil }}
  permitOnlyProjectScopedClusters: {{ .permitOnlyProjectScopedClusters }}
  {{- end }}
  {{- with .description }}
  description: {{ . | quote }}
  {{- end }}
  {{- with .sourceRepos }}
  sourceRepos: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .destinations }}
  destinations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .clusterResourceWhitelist }}
  clusterResourceWhitelist: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .clusterResourceBlacklist }}
  clusterResourceBlacklist: {{- .| toYaml | nindent 4 }}
  {{- end }}
  {{- with .namespaceResourceBlacklist }}
  namespaceResourceBlacklist: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .namespaceResourceWhitelist }}
  namespaceResourceWhitelist: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .orphanedResources }}
  orphanedResources: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .roles }}
  roles: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .syncWindows }}
  syncWindows: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .signatureKeys }}
  signatureKeys: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .sourceNamespaces }}
  sourceNamespaces: {{- . | toYaml | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

We can then test that the templating is working using the following values:

```yaml title="values.yaml"
projectDefaults:
  annotations:
    is-cool: "true"

projects:
  foo: {}
  bar:
    annotations:
      is-cool: "false"
```

Templating the chart using `helm template .` should yield the following output:

```yaml
---
# Source: tenant/templates/appprojects.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  annotations:
    is-cool: "false"
  name: bar
spec:
---
# Source: tenant/templates/appprojects.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  annotations:
    is-cool: "true"
  name: foo
spec:
```

#### Namespace

Using a combination of the [Kubernetes Namespace Reference](https://kubernetes.io/docs/reference/kubernetes-api/core/namespace-v1/) and `kubectl explain namespace` we can create the following template for namespaces:

```yaml title="templates/namespaces.yaml"
{{- range $id, $_ := .Values.namespaces }}
{{- with include "tenant.resource.data" (dict "root" $ "id" $id "data" . "defaults" $.Values.namespaceDefaults) | fromYaml }}
---
apiVersion: v1
kind: Namespace
metadata:
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
  name: {{ .name }}
{{- with .finalizers }}
spec:
  finalizers: {{ . | toYaml | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
```

We can then test that the templating is working using the following values:

```yaml title="values.yaml"
namespaceDefaults:
  annotations:
    is-cool: "true"

namespaces:
  foo: {}
  bar:
    annotations:
      is-cool: "false"
```

Templating the chart using `helm template .` should yield the following output:

```yaml
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    is-cool: "false"
  name: bar
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    is-cool: "true"
  name: foo
```

#### Extra Resources

We can use the following template to allow extra resources per tenant:

```smarty title="templates/extra-resources.yaml"
{{- range $id, $_ := .Values.extraResources }}
---
{{ tpl (. | toYaml) $.Values.defaults }}
{{- end }}
```

!!! warning
	Extra resources are only templated using `defaults`, there are no `extraResourceDefaults`

We can then test that the templating is working using the following values:

```yaml title="values.yaml"
defaults:
  metadata:
    tenant: wibble

extraResources:
  foo:
    apiVersion: v1
    kind: Namespace
    metadata:
      name: "{{.metadata.tenant}}-foo"
  bar:
    apiVersion: v1
    kind: Namespace
    metadata:
      name: "{{.metadata.tenant}}-bar"
```

Templating the chart using `helm template .` should yield the following output:

```yaml
---
# Source: tenant/templates/extra-resources.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: 'wibble-bar'
---
# Source: tenant/templates/extra-resources.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: 'wibble-foo'
```

### Per-Namespace Resources

As one tenant may own *multiple* namespaces, it's likely that they'll want to add resources to specific namespaces (or even all of them). For example, they might have a default `NetworkPolicy` that they want to put into all of their namespaces.

Each namespaced resource should only be created if the tenant has also enabled that namespace.

Let's create a helper to build a list of enabled resources:

```smarty title="templates/_helpers.tpl"
{{- define "tenant.resource.list" -}}
  {{- $ := .root -}}
  {{- $values := .values | default dict -}}
  {{- $defaults := .defaults | default dict -}}

  {{- $resourceDatas := list -}}

  {{- /* Iterate over each configured resource */ -}}
  {{- range $id, $_ := $values -}}
    {{- /* Build the resource's data */ -}}
    {{- $data := include "tenant.resource.data" (dict "root" $ "id" $id "data" . "defaults" $defaults) | fromYaml -}}

    {{- /* If the resource is enabled, append it to the list of enabled resources */ -}}
    {{- if $data -}}
      {{- $resourceDatas = append $resourceDatas $data -}}
    {{- end -}}
  {{- end -}}

  {{- /* Output the resource data of the enabled resources as a YAML list */ -}}
  {{- $resourceDatas | toYaml -}}
{{- end -}}
```

We can then refactor our `Namespace` template to make use of this:

```yaml title="templates/namespaces.yaml"
{{- range include "tenant.resource.list" (dict "root" $ "values" .Values.namespaces "defaults" .Values.namespaceDefaults) | fromYamlArray }}
---
apiVersion: v1
kind: Namespace
metadata:
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
  name: {{ .name }}
{{- with .finalizers }}
spec:
  finalizers: {{ . | toYaml | nindent 2 }}
{{- end }}
{{- end }}
```

We can now make use of this helper when we create our namespaced resources :slightly_smiling_face:

#### LimitRange

By using a combination of the [Kubernetes LimitRange Reference](https://kubernetes.io/docs/reference/kubernetes-api/core/limit-range-v1/) and `kubectl explain limitrange`, we can create the following template:

```yaml title="templates/limit-ranges.yaml"
{{- range $namespace := include "tenant.resource.list" (dict "root" $ "values" $.Values.namespaces "defaults" $.Values.namespaceDefaults) | fromYamlArray }}
{{- range include "tenant.resource.list" (dict "root" $ "values" $namespace.limitRanges "defaults" $.Values.limitRangeDefaults) | fromYamlArray }}
---
apiVersion: v1
kind: LimitRange
metadata:
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .finalizers }}
  finalizers: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
  name: {{ .name }}
  namespace: {{ $namespace.name }}
spec:
  {{- with .limits }}
  limits: {{- . | toYaml | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

!!! warning
	It's important to note that our `LimitRange` **will only get created if the `Namespace` is also enabled**

We can then test that the templating is working using the following values:

```yaml title="values.yaml"
namespaceDefaults:
  limitRanges:
    cpu-resource-constraint:
        limits:
        - default:
            cpu: 500m
          defaultRequest:
            cpu: 500m
          max:
            cpu: "1"
          min:
            cpu: 100m
          type: Container

namespaces:
  foo: {}
  bar:
    limitRanges:
      cpu-resource-constraint:
        enabled: false
  baz:
    enabled: false
```

Templating the chart using `helm template .` should yield the following output:

```yaml
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bar
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo
---
# Source: tenant/templates/limit-ranges.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-resource-constraint
  namespace: foo
spec:
  limits:
    - default:
        cpu: 500m
      defaultRequest:
        cpu: 500m
      max:
        cpu: "1"
      min:
        cpu: 100m
      type: Container
```

#### NetworkPolicy

By using a combination of the [Kubernetes NetworkPolicy Reference](https://kubernetes.io/docs/reference/kubernetes-api/networking/network-policy-v1/) and `kubectl explain networkpolicy`, we can create the following template:

```yaml title="templates/network-policies.yaml"
{{- range $namespace := include "tenant.resource.list" (dict "root" $ "values" $.Values.namespaces "defaults" $.Values.namespaceDefaults) | fromYamlArray }}
{{- range include "tenant.resource.list" (dict "root" $ "values" $namespace.networkPolicies "defaults" $.Values.networkPolicyDefaults) | fromYamlArray }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .finalizers }}
  finalizers: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
  name: {{ .name }}
  namespace: {{ $namespace.name }}
spec:
  {{- with .egress }}
  egress: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .ingress }}
  ingress: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- if ne .podSelector nil }}
  podSelector: {{ ternary "{}" (.podSelector | toYaml | nindent 4) (empty .podSelector) }}
  {{- end }}
  {{- with .policyTypes }}
  policyTypes: {{- . | toYaml | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

!!! warning
	It's important to note that our `NetworkPolicy` **will only get created if the `Namespace` is also enabled**

We can then test that the templating is working using the following values:

```yaml title="values.yaml"
namespaceDefaults:
  networkPolicies:
    default-deny-all:
      podSelector: {}
      policyTypes:
        - Ingress
        - Egress

namespaces:
  foo: {}
  bar:
    networkPolicies:
      default-deny-all:
        enabled: false
```

Templating the chart using `helm template .` should yield the following output:

```yaml
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bar
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo
---
# Source: tenant/templates/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: foo
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

#### ResourceQuota

By using a combination of the [Kubernetes ResourceQuota Reference](https://kubernetes.io/docs/reference/kubernetes-api/core/resource-quota-v1/) and `kubectl explain resourcequota`, we can create the following template:

```yaml title="templates/resource-quotas.yaml"
{{- range $namespace := include "tenant.resource.list" (dict "root" $ "values" $.Values.namespaces "defaults" $.Values.namespaceDefaults) | fromYamlArray }}
{{- range include "tenant.resource.list" (dict "root" $ "values" $namespace.resourceQuotas "defaults" $.Values.resourceQuotaDefaults) | fromYamlArray }}
---
apiVersion: v1
kind: ResourceQuota
metadata:
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .finalizers }}
  finalizers: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
  name: {{ .name }}
  namespace: {{ $namespace.name }}
spec:
  {{- with .hard }}
  hard: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .scopeSelector }}
  scopeSelector: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .scopes }}
  scopes: {{- . | toYaml | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

!!! warning
	It's important to note that our `ResourceQuota` **will only get created if the `Namespace` is also enabled**

We can then test that the templating is working using the following values:

```yaml title="values.yaml"
namespaceDefaults:
  resourceQuotas:
    compute-resources:
      hard:
        requests.cpu: "1"
        requests.memory: "1Gi"
        limits.cpu: "2"
        limits.memory: "2Gi"

namespaces:
  foo: {}
  bar:
    resourceQuotas:
      compute-resources:
        enabled: false
```

Templating the chart using `helm template .` should yield the following output:

```yaml
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bar
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo
---
# Source: tenant/templates/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: foo
spec:
  hard:
    limits.cpu: "2"
    limits.memory: 2Gi
    requests.cpu: "1"
    requests.memory: 1Gi
```

#### Extra Resources

Let's update our existing `templates/extra-resources.yaml` template to also cater for namespace-specific extra resources:

```smarty title="templates/extra-resources.yaml" hl_lines="6-13"
{{- range $id, $_ := .Values.extraResources }}
---
{{ tpl (. | toYaml) $.Values.defaults }}
{{- end -}}

{{- range $namespace := include "tenant.resource.list" (dict "root" $ "values" $.Values.namespaces "defaults" $.Values.namespaceDefaults) | fromYamlArray }}
{{- range $id, $_ := $namespace.extraResources }}
{{- $data := tpl (. | toYaml) $.Values.defaults | fromYaml }}
{{- $_ := mustMergeOverwrite $data (dict "metadata" (dict "namespace" $namespace.name)) }}
---
{{ $data | toYaml }}
{{- end }}
{{- end -}}

```

We can then test that the templating is working using the following values:

```yaml title="values.yaml"
namespaces:
  foo:
    extraResources:
      default-network-policy:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: default-deny-all
        spec:
          podSelector: {}
          policyTypes:
            - Ingress
            - Egress
```

Templating the chart using `helm template .` should yield the following output:

```yaml
---
# Source: tenant/templates/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo
---
# Source: tenant/templates/extra-resources.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: foo
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```
