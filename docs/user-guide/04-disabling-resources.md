# Enabling/Disabling Resources

By default, resources are *enabled*. The term "enabled" simply means that the resource will be created. By extension, *disabled* resources won't be created.

To control whether a resource should, or should not be created, we can use the `$enabled` field.

For example:

```yaml title="values.yaml"
namespaces:
  a: {}
  b:
    $enabled: true
  c:
    $enabled: false
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: a

---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: b
```

In the above example, the following happened:

1. The `a` namespace got **created** as it was implicitly enabled (enabled by default)
2. The `b` namespace got **created** as it was explicitly enabled (`$enabled: true`)
3. The `c` namespace got **ignored** as it was explicitly disabled (`$enabled: false`)

## Use In Conjuction With Defaults

[Defaults](03-defaults.md) can also be used to enable/disable resources by default.

For example:

```yaml title="values.yaml"
defaults:
  # Disable all resources by default
  $enabled: false

namespaceDefaults:
  # Enable all namespaces by default
  $enabled: true

namespace:
  name: foo

resourceQuota:
  name: bar

limitRange:
  $enabled: true
  name: baz
```

Which, when templated using `helm template . -f values.yaml` outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo

---
# Source: tenant/templates/core/limit-ranges.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: baz
spec:
  limits: []
```

In the above example, the following happened:

1. The `foo` namespace **was created** as `namespaceDefaults` enabled all namespaces by default, which took precedence over `defaults`
2. The `bar` resource quota **wasn't created** as all resources are disabled by default (`defaults.$enabled: false`)
3. The `baz` limit range **was created** as it explicitly enabled itself, which takes precedence over `defaults`
