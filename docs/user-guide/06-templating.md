# Templating

## Core Concepts

Let's first define some important templating terminology:

1. **Template** - A string containing a Go [`text/template`](https://pkg.go.dev/text/template) template.
    * For example: `"Hello, {{.name}}!"`
1. **Data** - The input data object used when executing the template
    * For example: `{"name": "Bob"}`
    * This may also be referred to as the *input*
1. **Execute** - Executing a template is when the template gets applied to a data object, resulting in an output string.
    * For example, executing `"Hello, {{.name}}!"` with data `{"name": "Bob"}`, would output `"Hello, Bob!"`
    * This may also be referred to as *evaluating* or *templating* the template
    * See [`Template.Execute`](https://pkg.go.dev/text/template#Template.Execute) for more information.
1. **Output** The string output produced by executing a template
    * For example, `"Hello, Bob!"` would be the output produced by executing `"Hello, {{.name}}!"` with data `{"name": "Bob"}`
1. **Context**
    * **Root Context**
        * > When execution begins, `$` is set to the data argument passed to `Execute`, that is, to the starting value of dot." ([ref](https://pkg.go.dev/text/template#hdr-Variables))
        * This may also be referred to as the *root scope* or *top scope*
        * `$` is an *unnamed variable*, which does not (typically) change during template execution.
    * **Current Context**
        * > Execution of the template walks the structure and sets the cursor, represented by a period '.' and called "dot", to the value at the current location in the structure as execution proceeds. ([ref](https://pkg.go.dev/text/template#pkg-overview))
        * Dot (`.`) refers to the current context, which can be changed by entering the scope of a control structure (e.g. `with`, `range`)
        * For example: `{{with .policy}} T1 {{end}}` - if `.policy` is non-empty, dot (`.`) gets set to the value of `.policy`, and T1 gets executed within the new context.
1. **Scope**
    * The top level of the template is referred to as the "global" scope
    * Control structures (e.g. `if`, `with`, and `range`) have their own scope which extends to their end (`{{end}}`)
    * Variables are only accessible inside the scope within which they were declared
1. **Variable**
    * For example: `{{$name := "Bob"}}`
    * Variables have a (possibly empty) alphanumeric name preceded by a dollar sign (e.g. `$foo`)
    * Variables defined at the top level of the template are "globally" scoped
    * Variables defined within a control structure (e.g. `with` or `range`) are scoped to the block within which they are declared
    * > A variable's scope extends to the "end" action of the control structure ("if", "with", or "range") in which it is declared, or to the end of the template if there is no such control structure. A template invocation does not inherit variables from the point of its invocation. 
    * See [Variables](https://pkg.go.dev/text/template#hdr-Variables) for more information.

## Resource Data Self-Templating

Resource data gets *self-templated* - this means that the resource data gets converted into a YAML string template, and executed with itself.

Below is a simple example of this in action:

```yaml title="values.yaml"
namespace:
  name: cool-namespace
  annotations:
    my-name-is: "{{.name}}"
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    my-name-is: cool-namespace
  name: cool-namespace
```

### Accessing the Root Context

The root context is accessible via the `$` variable.

For example:

```yaml title="values.yaml"
namespace:
  annotations:
    release-name: "{{ $.Release.Name }}"
  name: test
```

Which, when templated using `helm template some-release-name . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    release-name: some-release-name
  name: test
```

!!! tip
    Having access to the root context lets you do some pretty powerful things, for example:

    ```yaml title="values.yaml"
    namespaces:
      a: {}
      b: {}
      c:
        $enabled: false

    application:
      name: tenant-metrics
      source:
        repoURL: some.registry
        chart: some-metrics-app
        targetRevision: 1.2.3
        helm:
          values: |
            {{- with include "tenant.resources.namespaces" $ | fromYamlArray }}
            namespaces:
              {{- range . }}
              - {{ .name | quote }}
              {{- end }}
            {{- end }}
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

    ---
    # Source: tenant/templates/argoproj/applications.yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: tenant-metrics
    spec:
      source:
        chart: some-metrics-app
        helm:
          values: |
            namespaces:
              - "a"
              - "b"
        repoURL: some.registry
        targetRevision: 1.2.3
    ```

### Template Variables

Template variables can be defined within the resource data using a `$` prefix, for example:

```yaml title="values.yaml"
namespace:
  $food: pizza
  name: "i-like-eating-{{$food}}"
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: i-like-eating-pizza
```

You might wonder why you should use template variable fields, when you could have just as easily done:

```yaml title="values.yaml"
namespace:
  food: pizza
  name: "i-like-eating-{{.food}}"
```

However, **there are a few important distinctions**:

1. Variable fields (those prefixed with a `$`) get **removed** from the resource data.
    * This means that they do not get passed to the underlying template (e.g. `templates/core/namespaces.yaml`)
    * They do not pollute the set of fields in the resource data, which is especially important for *Extra Resources*
2. Variable fields **do not get self-templated**
    * For example, `$releaseName: {{ $.Release.Name }}` will define a variable named `releaseName` with a **literal value** of `"{{ $.Release.Name }}"`
3. Variable fields get exposed during self-templating as variables.

#### Reserved Variables

The following variables have special meaning:

##### `$enabled`

The chart will use this to decide whether to create the resource.

For example:

```yaml
namespaces:
  a: {}             # implicitly enabled
  b:
    $enabled: true  # explicitly enabled
  c:
    $enabled: false # explicitly disabled
```

See *[Disabling Resources](04-disabling-resources.md)* for more information.

##### `$id`

When you define a map of resources (e.g. `namespaces` or `applications`), the `$id` variable will be assigned the value of the map key.

For example:

```yaml
namespaces:
  foo: {} # <-- $id is set to "foo"
```

### Resource Name Templated First

As the resource name is commonly depended on, it gets to "jump the queue" and gets templated first.

For example, consider the following example:

```yaml title="values.yaml"
defaults:
  $tenant: "foo"

projectDefaults:
  annotations:
    my-name-is: "{{.name}}"
  name: "{{$tenant}}-{{$id}}"

namespaces:
  foo: {}
```

If the name wasn't templated first, templating the chart using `helm template . -f values.yaml` would output:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    my-name-is: '{{$tenant}}-{{$id}}'
  name: foo-config
```

However, since the name does get templated first, the actual output is:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    my-name-is: foo-config
  name: foo-config
```

### Beware of Transitive Dependencies

Self-templating is a helpful feature to have available, however there is one main sharp corner to be aware of... transitive dependencies!

As a general rule of thumb, if you "template" a field, you need to make sure that the value you're templating it with isn't itself templated.

For example, consider the below example:

```yaml
resourceQuota:
  annotations:
    my-namespace-is: "{{.namespace}}"
  name: example
  namespace: "{{ $.Release.Namespace }}"
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  annotations:
    my-namespace-is: '{{ $.Release.Namespace }}'
  name: example
  namespace: default
spec:
  hard: {}
```

As you can see, the `metadata.namespace` gets set correctly, however `metadata.annotations.my-namespace-is` doesn't, as it has a transitive dependency.

It's important not to confuse templating with [*Dependency Injection*](https://en.wikipedia.org/wiki/Dependency_injection)!

### Accessing Namespace Data Within Sub-Resources

[Sub Resources](05-sub-resources.md) allow you to define sub-resources of a namespace.

The `.namespace` field gets automatically set to the value of the namespace's name.

For example:

```yaml title="values.yaml"
namespace:
  name: foo

  resources:
    resourceQuota:
      annotations:
        my-namespace-is: "{{.namespace}}"
      name: compute-resources
```

Which, when templated using `helm template . -f values.yaml`, outputs:

```yaml
---
# Source: tenant/templates/core/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo

---
# Source: tenant/templates/core/resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  annotations:
    my-namespace-is: foo
  name: compute-resources
  namespace: foo
spec:
  hard: {}
```

However, **the entire parent namespace's data also gets exposed as a `$namespace` variable**, allowing you to extract any data of your choosing.

For example, the above example is equivelant to:

```yaml
namespace:
  name: foo

  resources:
    resourceQuota:
      annotations:
        my-namespace-is: "{{$namespace.name}}"
      name: compute-resources
```
