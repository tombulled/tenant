# Defaults

## Resource-Specific Defaults

Let's imagine we want to create the following set of resources:

```yaml title="values.yaml"
namespaces:
  argocd:
    annotations:
      argocd.argoproj.io/sync-options: Delete=confirm,Prune=confirm
  cilium:
    annotations:
      argocd.argoproj.io/sync-options: Delete=confirm,Prune=confirm
  sealed-secrets:
    annotations:
      argocd.argoproj.io/sync-options: Delete=confirm,Prune=confirm
```

As you can tell, there's commonality between each of these namespaces (they all have an identical annotation).

Fortunately, this can be applied as a *resource-specific* default:

```yaml title="values.yaml"
namespaceDefaults:
  annotations:
    argocd.argoproj.io/sync-options: Delete=confirm,Prune=confirm

namespaces:
  argocd: {}
  cilium: {}
  sealed-secrets: {}
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Delete=confirm,Prune=confirm
  name: argocd

---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Delete=confirm,Prune=confirm
  name: cilium

---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Delete=confirm,Prune=confirm
  name: sealed-secrets
```

## Common Defaults

Let's imagine we're creating resources for a `foo` tenant, and we want them to have their own `Namespace`, `ResourceQuota` and `LimitRange`.

We also want them to have an annotation indicating which tenant owns them:

```yaml hl_lines="3-4 8-9 19-20"
namespace:
  name: foo
  annotations:
    owning-tenant: foo

resourceQuota:
  name: compute-resources
  annotations:
    owning-tenant: foo
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
    limits.cpu: "2"
    limits.memory: "2Gi"
    requests.nvidia.com/gpu: 4

limitRange:
  name: cpu-resource-constraint
  annotations:
    owning-tenant: foo
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

As you can tell, there's commonality between each of these resources (they all have an identical annotation).

As these resources are of different *types*, we can't use resource-specific defaults to set the annotation across all of them, however we can use *common* defaults:

```yaml title="values.yaml" hl_lines="1-3"
defaults:
  annotations:
    owning-tenant: foo

namespace:
  name: foo

resourceQuota:
  name: compute-resources
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
    limits.cpu: "2"
    limits.memory: "2Gi"
    requests.nvidia.com/gpu: 4

limitRange:
  name: cpu-resource-constraint
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

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml hl_lines="6-7 15-16 31-32"
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    owning-tenant: foo
  name: foo

---
# Source: tenant/templates/core/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  annotations:
    owning-tenant: foo
  name: compute-resources
spec:
  hard:
    limits.cpu: "2"
    limits.memory: 2Gi
    requests.cpu: "1"
    requests.memory: 1Gi
    requests.nvidia.com/gpu: 4

---
# Source: tenant/templates/core/limit-ranges.yaml
apiVersion: v1
kind: LimitRange
metadata:
  annotations:
    owning-tenant: foo
  name: cpu-resource-constraint
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

## Order of Precedence

The following order of precedence is observed (lowest -> highest):

1. Common defaults (`defaults`)
2. Resource-specific defaults (e.g. `namespaceDefaults`)
3. Resource data (e.g. `namespace` or `namespaces.<id>`)

The below example shows the order of precedence in action:

```yaml title="values.yaml"
defaults:
  annotations:
    food: pizza
    size: large
    type: pepperoni

namespaceDefaults:
  annotations:
    size: medium
    type: cheese

namespace:
  annotations:
    type: meat-feast
  name: example
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    food: pizza
    size: medium
    type: meat-feast
  name: example
```