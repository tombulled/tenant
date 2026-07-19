# Improvement - Self-Templating

The `tenant` chart is designed to be deployed once per tenant.

!!! note
	That being said, it would absolutely be possible to deploy one `tenant` chart that's responsible for creating resources for multiple tenants... however this **isn't recommended**!

We haven't touched upon orchestrating the deployment of multiple tenants yet, however it's conceivable that some environmental *knowledge* could be passed down to each `tenant` application (and, by extension, the resources it creates).

For example, this information might include:

* Cluster-related information
    * The cluster name/ID, e.g. `some-cluster`
    * The cluster type/category/group, e.g. `dev`
    * The cluster site, e.g. `some-site`
    * The cluster region, e.g. `us-east`
* Tenant-related information
	* The tenant's name/ID, e.g. `some-tenant`
	* The tenant's owner, e.g. `some-team`
* Resource-related information
	* The resource's name or ID, e.g. `some-app`

However, this chart (by design) should make no assumptions about what this information is, as it's likely to vary between users.
We'll refer to this environmental information as **metadata**.

Using YAML anchors we can mimic how this sort of functionality could work:

```yaml title="values.yaml"
_clusterId: &clusterId some-cluster
_clusterType: &clusterType dev
_tenant: &tenant some-tenant

applicationDefaults:
  annotations:
    clusterId: *clusterId
    clusterType: *clusterType
    tenant: *tenant

applications:
  foo: {}
```

Which, once templated using `helm template .`, produces the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
  annotations:
    clusterId: some-cluster
    clusterType: dev
    tenant: some-tenant
spec:
```

Whilst this simple example works, it falls short as soon as the values need to be inserted into something.

For example, let's imagine we've got an application called `foo` to deploy.
The `foo` application has an `envValues` directory which contains environment-specific value files:

```sh
$ tree envValues
envValues
├── base.yaml
├── cluster-1.yaml
├── cluster-2.yaml
├── type-dev.yaml
└── type-ops.yaml

0 directories, 5 files
```

For a theoretical cluster `cluster-1` of type `dev`, we'd want to source the following value files (in ascending order of preference):

* `base.yaml`
* `type-dev.yaml`
* `cluster-1.yaml`

However, as YAML anchors are simple aliases, we can't use them like `*clusterId.yaml`.

Instead, it'd be preferable if we could *template* the values themselves, for example in the following way:

```yaml title="values.yaml" linenums="1"
metadata:
  clusterId: cluster-1
  clusterType: dev

applications:
  foo:
    source:
      repoURL: git@github.com:example/charts.git
      targetRevision: main
      path: foo
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
          - "envValues/base.yaml"
          - "envValues/type-{{.metadata.clusterType}}.yaml"
          - "envValues/{{.metadata.clusterId}}.yaml"
```

However, before we rush ahead and implement that, have you spotted that the application's name gets repeated on line 10 (as `foo` is *also* the name of the application's chart)?

It would be cool if we could access the application's name and use that, for example in the following way:

```yaml title="values.yaml"
applications:
  foo:
    source:
      repoURL: git@github.com:example/charts.git
      targetRevision: main
      path: "{{.name}}"
```

!!! tip

	Resource names default to their IDs (map keys)

However, an important thing to note is that the `.name` is relative to the application's data, whereas `.metadata` was relative to the root of the chart's values.

Instead, we could treat `.metadata` as a user-defined field for them to do with as they please. They could also not define it, or call it something else (such as `.info`) if they wanted.

As it'll get treated as a regular bit of resource data, you could instead implement it in the following way:

```yaml title="values.yaml"
common:
  metadata:
    cluster: some-cluster
    tenant: some-tenant
```

With metadata treated in this way, it'll become available within the data of all resources created by this chart (including applications created by application sets).

To achieve this we'll need to do the following:

1. Self-template all resource's data
1. Self-template all application's data (*spoiler: this isn't as easy as it sounds!*)

## Implementing a Solution

### Self-Templating Resource Data

Helm includes a wonderful [`tpl` function](https://helm.sh/docs/howto/charts_tips_and_tricks/#using-the-tpl-function) which can be used to evaluate a template using a given context.

```diff title="templates/_helpers.tpl"
--- templates/_helpers.tpl
+++ templates/_helpers.tpl
@@ -34,6 +34,9 @@
       {{- $_ := set $data "name" $id -}}
     {{- end -}}

+    {{- /* Template the resource's data using itself */ -}}
+    {{- $data = tpl ($data | toYaml) $data | fromYaml -}}
+
     {{- /* Finally, output the new resource data */ -}}
     {{- $data | toYaml -}}
   {{- end -}}
```

That's it!

Let's test it in action using the following values:

```yaml title="values.yaml"
applications:
  foo:
    annotations:
      my-name-is: "{{.name}}"
```

Templating the chart using `helm template .` should produce the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
  annotations:
    my-name-is: foo
spec:
```

Magic! :mage:

### Self-Templating Application Data

Unfortunately, we can't use the `tpl` function in the `application-template`.

??? info "The long answer why..."

    [Helm](https://helm.sh/) is written in [Go](https://go.dev/), and it makes use of the [text/template](https://pkg.go.dev/text/template) package from Go's standard library for its templating.
    Out of the box, the Go `text/template` package includes a set of [actions](https://pkg.go.dev/text/template#hdr-Actions) (e.g. `if`, `range`, `with`, etc.) and a set of [functions](https://pkg.go.dev/text/template#hdr-Functions) (e.g. `and`, `len`, `printf`, etc.). Although the available set of actions cannot be extended, **Go does support extending the set of available functions** by allowing a [*function map*](https://pkg.go.dev/text/template#Template.Funcs) to be provided for use when executing the template.
    
    This is important as the set of functions available by default in the `text/template` package are **very limited**. Fortunately, an awesome library called [sprig](https://masterminds.github.io/sprig/) exists which provides over 70 template functions for Go's template language. Helm actually uses `sprig` under the hood and exposes its functions for use in Helm templates.
    
    Helm's [*Template Functions and Pipelines*](https://helm.sh/docs/chart_template_guide/functions_and_pipelines/) documentation states the following:
    
    !!! quote
    	Helm has over 60 available functions. Some of them are defined by the Go template language itself. Most of the others are part of the Sprig template library. We'll see many of them as we progress through the examples.
    
        While we talk about the "Helm template language" as if it is Helm-specific, it is actually a combination of the Go template language, some extra functions, and a variety of wrappers to expose certain objects to the templates. Many resources on Go templates may be helpful as you learn about templating.
    
    As the above quote alludes to, Helm also provides their *own* set of functions (e.g. [`tpl`](https://helm.sh/docs/howto/charts_tips_and_tricks/#using-the-tpl-function)) - a (mostly complete) list of all functions available for use in Helm templates can be found here: [Template Function List](https://helm.sh/docs/chart_template_guide/function_list/).
    
    Now, let's circle back to Application Sets. Althout the `tenant` chart *creates* Application Sets, it's actually ArgoCD that's responsible for creating the resulting applications. It does this by generating a set of values using the application set's `generators`, and then executes both the `template` and `templatePatch` templates using these values (as we have `goTemplate` enabled).
    
    This is important because within the `templatePatch` template (where our `application-template` gets inserted) we can only work with the set of templating functions that ArgoCD itself makes available (Helm-specific functions will not be available!). We at least know we're guaranteed at least the built-in ones the standard-library makes available.
    
    Fortunately, like Helm, ArgoCD also makes the `sprig` function library available (except for a select few, e.g. `env`). ArgoCD also provides a small set of custom functions which can be used (incl. `normalize` and `slugify`). ArgoCD's [Go Template](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/) documentation details everything you should need to know, including [available template functions](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/#available-template-functions).
    
    So, to recap, here's a high-level overview of the available set of template functions:
    
    |                           | Helm Templates     | ArgoCD ApplicationSet Templates |
    | ------------------------- | ------------------ | ------------------------------- |
    | `text/template` Built-Ins | :heavy_check_mark: | :heavy_check_mark:              |
    | Sprig                     | :heavy_check_mark: | :heavy_check_mark:              |
    | Helm functions            | :heavy_check_mark: |                                 |
    | ArgoCD functions          |                    | :heavy_check_mark:              |
    
    Unfortunately, as ArgoCD doesn't expose a Helm-like `tpl` function, it's therefore not possible to use it in our `application-template` template.

    (However, there is [a PR open to add it!](https://github.com/argoproj/argo-cd/pull/26614))

To work around this limitation, we need to implement our own Helm-like `tpl` function that only relies on the set of template functions that ArgoCD makes available to us.

Unfortunately, in lieu of a `tpl` function, the best we'll be able to do is a find-and-replace. We could implement a [nested template](https://pkg.go.dev/text/template#hdr-Nested_template_definitions) to achieve this, such as the following example:

```smarty
{{- define "template-test" -}}
  {{- $template := . | toYaml -}}

  {{- $template = replace "{{.test}}" "it-worked" $template -}}

  {{- $template -}}
{{- end -}}
```

However, whilst Helm provides an `include` function to *capture* the output of a nested template, ArgoCD doesn't expose any such function.
The `template` action from the `text/template` standard-library will output contents directly, and this cannot be captured (for example into a variable).
Fortunately, all hope is not yet lost!

Let's make a small tweak to the above `template-test` template:

```smarty hl_lines="1 6"
{{- block "template-test" . -}}
  {{- $template := . | toYaml -}}

  {{- $template = replace "{{.test}}" "it-worked" $template -}}

  {{- $_ := mustMergeOverwrite . ($template | fromYaml) -}}
{{- end -}}
```

The above changes the following things:

1. The `block` action is used instead of `define`. The `block` action allows you to define a template and execute it in place. In this case, we're defining a template called `template-test` and immediately executing it using the current context (`.`)
1. `mustMergeOverwrite` is used to overwrite the current context (the application data) with the output of the find-and-replace.
1. The `template-test` nested template now outputs nothing, and instead modifies the context passed to it in place.

Whilst this is great, it obviously doesn't scale. We can't have our `template-test` template do a find-and-replace for everything in this way. Instead it'd be preferable if it could mimic the `tpl` function by being completely generic, and doing its best to template *anything* it's given.

Instead, we could search the application data for anything matching the regex `{{ *\\..*? *}}` (e.g. `{{.foo}}`, `{{ .foo.bar }}`, etc.). We could then hunt through the application data for the appropriate *value*, and then do a find-and-replace.

A complete implemention of this is shown below:

```jinja
{{- /*
  The below nested-template templates the application data using itself.
  This logic is a workaround for the `tpl` function not being available.
  If https://github.com/argoproj/argo-cd/pull/26614 gets merged, the `tpl` function can be used instead.
*/ -}}
{{- block "self-template" . -}}
  {{- $template := . | toYaml -}}

  {{- /* Find everything that looks like a template, e.g. "{.name}", and loop over each of them */ -}}
  {{- range $match := regexFindAll "{{ *\\..*? *}}" $template -1 -}}
    {{- /* Extract all of the keys from the match, e.g: "{.foo.bar}" -> ["foo", "bar"] */ -}}
    {{- $keys := $match | substr 2 (int (sub (len $match) 2)) | trim | substr 1 -1 | splitList "." -}}

    {{- /* Traverse the application data, using the match's keys. If a value is not found, an empty string is used */ -}}
    {{- /* NOTE: We can't use the sprig `dig` function as it doesn't accept a dynamic list of values */ -}}
    {{- $obj := $ -}}
    {{- range $key := $keys -}}
      {{- /* If the current object isn't a map, abort as we can't traverse any further */ -}}
      {{- if ne (kindOf $obj) "map" -}}
        {{- $obj = "" -}}
        {{- break -}}
      {{- end -}}

      {{- /* Update the object to use the value of the current key. After the last iteration, `$obj` will contain the final value */ -}}
      {{- $obj = get $obj $key -}}
    {{- end -}}

    {{- /* Replace the "match" (e.g. "{{.name}}") in the template with the digged value */ -}}
    {{- $template = replace $match (print $obj) $template -}}
  {{- end -}}

  {{- $_ := mustMergeOverwrite . ($template | fromYaml) -}}
{{- end -}}
```

Hopefully the code comments help break down exactly what this logic is doing!

Let's **paste the above nested-template at the top of the `files/application-template.yaml` file** and then we can check everything's working using the following values:

```yaml title="values.yaml"
common:
  metadata:
    cluster:
      id: "some-cluster"

applicationDefaults:
  annotations:
    cluster-id: "{{.metadata.cluster.id}}"

applicationSets:
  foo:
    template:
      spec:
        project: default
    generators:
      - list:
          elements:
            - name: foo
```

We can then template the chart, and ask ArgoCD to generate us a list of applications using the following command:

```sh
helm template . | argocd appset generate /dev/stdin -o yaml
```

Which should output the following:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    cluster-id: some-cluster
  finalizers:
  - resources-finalizer.argocd.argoproj.io
  name: foo
spec:
  destination: {}
  project: default
```

In the above output, you can see that the value of the `cluster-id` annotation was successfully resolved to the value of `.metadata.cluster.id`.

!!! warning

	Again, to reiterate, the entire `self-template` template is a work around for the `tpl` function not being available.

	**If/when ArgoCD adds support for a `tpl`-like function, this can be used to replace the `self-template` template.**