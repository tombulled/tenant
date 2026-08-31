# Creating Resources

## Understanding Available Fields

Before we can create a resource, we first need to understand which fields are available to us.

For example, this is the template for `Namespace` resources:

```yaml title="templates/core/namespaces.yaml" linenums="3"
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
  finalizers: {{- . | toYaml | nindent 4 }}
{{- end }}
```

In the above template, we can see that we have 4x fields available to us:

1. `annotations` - configures `metadata.annotations`
2. `labels` - configures `metadata.labels`
3. `name` - configures `metadata.name`
4. `finalizers` - configures `spec.finalizers`

## Creating a Single Resource

Once we're aware of the available fields, we can then use this information to construct a resource:

```yaml title="values.yaml"
namespace:
  annotations:
    is-cool: "true"
  labels:
    part-of: some-app
  name: my-awesome-namespace
  finalizers:
    - some-important-finalizer
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    is-cool: "true"
  labels:
    part-of: some-app
  name: my-awesome-namespace
spec:
  finalizers:
    - some-important-finalizer
```

The above example creates a single namespace, however it's also possible to create more than one resource of a specific type.

## Creating Multiple Resources

To create multiple resources of a specific type, use the plural field (in this case, `namespaces`):

```yaml
namespaces:
  a:
    name: a
  b:
    name: b
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: a

---
apiVersion: v1
kind: Namespace
metadata:
  name: b
```

However, to reduce repetition, the `name` fields can be omitted, as these will default to the resource's IDs (their map keys).

For example, the above values are functionally equivelant to:

```yaml
namespaces:
  a: {}
  b: {}
```
