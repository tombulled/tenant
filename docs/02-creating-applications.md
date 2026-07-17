# Creating Applications

ArgoCD uses `Application` custom resources to model an *application* in a cluster, where an application is [defined as](https://argo-cd.readthedocs.io/en/stable/core_concepts/):
> A group of Kubernetes resources as defined by a manifest. This is a Custom Resource Definition (CRD).

!!! info
	See the [Application Specification Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/) for available fields.

Importantly, applications can be created explicitly using an `Application` resource, or they can be automatically generated using an `ApplicationSet`.

One of the goals of this chart is to provide the same API for configuring an application via both the `Application` and `ApplicationSet` resource types.

## Modelling an Application

Using Helm, and cross-referencing the *Application Specification Reference*, we can model a standard Application using the following template:

```yaml
metadata:
  name: {{ .name }}
  {{- with .namespace }}
  namespace: {{ . }}
  {{- end -}}
  {{- with .finalizers }}
  finalizers: {{ . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .annotations }}
  annotations: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .labels }}
  labels: {{- . | toYaml | nindent 4 }}
  {{- end }}
spec:
  {{- with .destination }}
  destination: {{- . | toYaml | nindent 4 }}
  {{- end -}}
  {{- with .ignoreDifferences }}
  ignoreDifferences: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .info }}
  info: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .project }}
  project: {{ . }}
  {{- end -}}
  {{- if ne .revisionHistoryLimit nil }}
  revisionHistoryLimit: {{ .revisionHistoryLimit }}
  {{- end }}
  {{- with .source }}
  source: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .sourceHydrator }}
  sourceHydrator: {{- . | toYaml | nindent 4}}
  {{- end }}
  {{- with .sources }}
  sources: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .syncPolicy }}
  syncPolicy: {{- . | toYaml | nindent 4 }}
  {{- end }}
```

There are a few important things to note here:

1. Values for the `metadata` and `spec` sections have been blended into one
2. No assumptions are made on whether fields are required or not, this is offloaded to the CRD (and any webhooks) to define & validate
3. Fields are named identically to how ArgoCD names them, they aren't being abstracted in any way.

## Using the Application template with both Applications and ApplicationSets

As we want to re-use our application template (as shown above) with **both** `Application` and `ApplicationSet` resources,
it needs to live somewhere *common* that both templates can access it.

We could place the contents in a [helpers file](https://helm.sh/docs/chart_template_guide/named_templates/),
however as our file is itself a template, we would have to escape the templating which can get a bit untidy.

Instead, the easiest approach is often to store the application template in a standard *file*, and use Helm to load in the contents:

```sh
$ mkdir files
$ # Next, copy the contents of the above application template into: files/application-template.yaml
```

We can then create a helper to load in the contents of this file:

```smarty title="templates/_helpers.tpl"
{{- define "application-template" -}}
  {{- $.Files.Get "files/application-template.yaml" | trim | nindent 0 }}
{{- end -}}
```

??? info
	We pipe the contents of the file to `trim | nindent 0` for the following reasons:

	1. `trim` trims any leading/trailing whitespace from the file (e.g. a trailing newline)
	1. `nindent 0` allows us to have the line indented inside the named template, to improve readability

	R.e. (2.), the following named template would also be absolutely valid: (note the indentation has been omitted)

	```smarty title="templates/_helpers.tpl"
	{{- define "application-template" -}}
	{{ $.Files.Get "files/application-template.yaml" | trim }}
	{{- end -}}
	```

### Creating template for Applications

We can now create a super simple template to create a series of `Application` resources:

```py title="templates/applications.yaml"
{{- range .Values.applications -}}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
{{ tpl (include "application-template" $) . }}
{{- end -}}
```

!!! note
	Importantly, we use the `tpl` function to immediately template the application template using the current context (the application's values).

We can quickly test that our chart is working as expected by templating it using the following command:

```sh
helm template . --set-json='{"applications": [{"name": "foo"}, {"name": "bar"}]}'
```

Which should yield the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
spec:
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bar
spec:
```

There are a few things to note from the above output:

* Two application resources were created (importantly separated by [document markers](https://www.yaml.info/learn/document.html))
* The `Application` resources are not *valid*, as they're missing fields required by the CRD (the chart makes no assumptions on this)

### Creating Template for ApplicationSets

Using a combination of the [ApplicationSet Specification Reference](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/applicationset-specification/)
and `kubectl explain`, we can create the following template to create a series of `ApplicationSet` resources:

```yaml title="templates/applicationsets.yaml"
{{- range .Values.applicationSets }}
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
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
spec:
  {{- if ne .applyNestedSelectors nil }}
  applyNestedSelectors: {{ .applyNestedSelectors }}
  {{- end }}
  generators: {{ ternary "[]" (.generators | toYaml | nindent 4) (empty .generators) }}
  goTemplate: true
  {{- with .goTemplateOptions }}
  goTemplateOptions: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .ignoreApplicationDifferences }}
  ignoreApplicationDifferences: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .preservedFields }}
  preservedFields: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .strategy }}
  strategy: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .syncPolicy }}
  syncPolicy: {{- . | toYaml | nindent 4 }}
  {{- end }}
  {{- with .template }}
  template: {{- . | toYaml | nindent 4 }}
  {{- end }}
  templatePatch: |
    {{- include "application-template" $ | nindent 4 }}
{{- end }}
```

There are a few important things to draw attention to here:

* The templating for `generators` is a little different. This is because `generators` is a required field, so should be set to an empty list if not populated.
* The contents of `files/application-template.yaml` gets inserted under the `templatePatch` field instead of the `template` one. This is because our template isn't valid YAML on its own, and makes use of template blocks such as `with` that only work under `templatePatch`. See the [Template Patch](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Template/#template-patch) docs for further info.
* The `goTemplate` field is hard-coded to `true`. This is because `templatePatch` only works when `goTemplate` is enabled.

We can quicky test our chart is working as expected by templating it using the following command:

```sh
helm template . --set-json='{"applicationSets": [{"name": "foo"}, {"name": "bar"}]}'
```

Which should yield the following output:

```yaml
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: foo
spec:
  generators: []
  goTemplate: true
  templatePatch: |
    metadata:
      <truncated>
    spec:
      <truncated>
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: bar
spec:
  generators: []
  goTemplate: true
  templatePatch: |
    metadata:
      <truncated>
    spec:
      <truncated>
```