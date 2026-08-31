# Sub Resources

## Overview

Let's imagine we're modelling a `foo` tenant with two namespaces: `app` and `db`.

Both the `db` and `app` namespaces should have a `ResourceQuota` to restrict how much CPU & memory they can use.

As the `db` namespace is sensitive, we want to add a default `NetworkPolicy` that disables all ingress & egress traffic by default.

We could create these resources in the following way:

```yaml title="values.yaml"
namespaces:
  app: {}
  db: {}

resourceQuotaDefaults:
  name: compute-resources
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
    limits.cpu: "2"
    limits.memory: "2Gi"

resourceQuotas:
  app:
    namespace: app
  db:
    namespace: db

networkPolicies:
  db:
    name: default-deny-all
    namespace: db
    podSelector: {}
    policyTypes:
      - Ingress
      - Egress
```

However this makes things awkward for a few reasons, for example:

1. If we disable one of the namespaces, we also need to separately disable all resources going into it
2. We have to repeat the namespace name multiple times, onto each resource going into it. If we renamed the namespace, we'd have to update this in multiple places.
3. If we want to create common resources between namespaces, this is currently a manual copy-paste exercise.

Fortunately, namespaces support defining *sub-resources* under a `resources` field.

For example, we can refactor our above values to become:

```yaml
namespaceDefaults:
  resources:
    resourceQuota:
      name: compute-resources
      hard:
        requests.cpu: "1"
        requests.memory: "1Gi"
        limits.cpu: "2"
        limits.memory: "2Gi"
    networkPolicy:
      $enabled: false
      name: default-deny-all
      podSelector: {}
      policyTypes:
        - Ingress
        - Egress

namespaces:
  app: {}
  db:
    resources:
      networkPolicy:
        $enabled: true
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app

---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: db

---
# Source: tenant/templates/networking/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: db
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
# Source: tenant/templates/core/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: app
spec:
  hard:
    limits.cpu: "2"
    limits.memory: 2Gi
    requests.cpu: "1"
    requests.memory: 1Gi

---
# Source: tenant/templates/core/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: db
spec:
  hard:
    limits.cpu: "2"
    limits.memory: 2Gi
    requests.cpu: "1"
    requests.memory: 1Gi
```

Also, importantly, if we disable a namespace, no sub-resources will be created for that namespace!

## Defaults

Under the `.resources` field it's also possible to specify *common* and *resource-specific* defaults.

For example, the below is totally valid:

```yaml title="values.yaml"
namespaceDefaults:
  resources:
    defaults:
      annotations:
        part-of-namespace: "{{.namespace}}"

    limitRangeDefaults:
      annotations:
        is-a-limit-range: "true"

    limitRange:
      name: limits

    resourceQuota:
      name: quota

namespaces:
  tenant-a: {}
  tenant-b:
    resources:
      defaults:
        $enabled: false

limitRange:
  name: parent-limits

resourceQuota:
  name: parent-quota
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a

---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-b

---
# Source: tenant/templates/core/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: parent-quota
spec:
  hard: {}

---
# Source: tenant/templates/core/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  annotations:
    part-of-namespace: tenant-a
  name: quota
  namespace: tenant-a
spec:
  hard: {}

---
# Source: tenant/templates/core/limit-ranges.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: parent-limits
spec:
  limits: []

---
# Source: tenant/templates/core/limit-ranges.yaml
apiVersion: v1
kind: LimitRange
metadata:
  annotations:
    is-a-limit-range: "true"
    part-of-namespace: tenant-a
  name: limits
  namespace: tenant-a
spec:
  limits: []
```
