# Docs

# 1. Introduction

The `tenant` Helm chart is designed to model a single "tenant" of a (optionally multi-tenanted) Kubernetes cluster, where a "tenant" is loosely defined as:

> An owner of one or more namespaces that wishes to deploy their workloads

Importantly, this chart is designed to be deployed **per tenant**. You can think of this chart as a powerful [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern-alternative).

# 2. Prerequisites

In order to follow along with this documentation, please install the following binaries:

* [`helm`](https://helm.sh/docs/intro/install/)
* [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [`yq`](https://github.com/mikefarah/yq/#install)
* [`argocd`](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

# 3. Scaffolding the Chart

First, let's use `helm create` to scaffold us a starter Helm chart:

```sh
$ helm create tenant
Creating tenant
$ cd tenant
```

Next, let's tidy up some of the artifacts we don't need:

```sh
$ rmdir charts
$ rm -r templates/*
$ echo "" > values.yaml
```

Finally, let's update the `Chart.yaml` to accurately reflect this chart:

```sh
$ yq e -i '... comments=""' Chart.yaml # Remove (strip) all comments
$ yq e -i '.description = "Tenant Helm Chart"' Chart.yaml
$ yq e -i 'del(.appVersion)' Chart.yaml
```

Congrats, you've just scaffolded an empty Helm chart!

```sh
$ tree -a
.
├── .helmignore
├── Chart.yaml
├── templates
└── values.yaml

1 directory, 3 files
```

# x. Modelling an Application
ArgoCD uses `Application` custom resources to model an *application* in a cluster, where an application is [defined as](https://argo-cd.readthedocs.io/en/stable/core_concepts/):
> A group of Kubernetes resources as defined by a manifest. This is a Custom Resource Definition (CRD).

!!! info
	See the [Application Specification Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/) for available fields.

Importantly, applications can be created explicitly using an `Application` resource, or they can be automatically generated using an `ApplicationSet`.

One of the goals of this chart is to provide the same API for configuring an application via both the `Application` and `ApplicationSet` resource types.

Using Helm, and cross-referencing the *Application Specification Reference*, we can model an Application using the following template:

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
2. No assumptions are made on whether fields are required or not, this is offloaded to the CRD to define
3. Fields are named identically to how ArgoCD names them, the chart doesn't abstract them in any way.

# x. Using the Application template with both Applications and ApplicationSets

As we want to re-use our application template (as shown above) with **both** `Application` and `ApplicationSet` resources,
it needs to live somewhere *common* that both templates can access it.

We could place the contents in a [helpers file](https://helm.sh/docs/chart_template_guide/named_templates/),
however as our file is itself a template, we would have to escape the templating which would get messy real fast.

Instead, the easiest approach is to store the application template in a standard *file*, and use Helm to load in the contents:

```sh
$ mkdir files
$ # Next, copy the contents of the above application template into: files/application-template.yaml
```

## x. Creating template for Applications

We can now create a super simple template to create a series of `Application` resources:

```py title="templates/applications.yaml"
{{- range .Values.applications -}}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
{{ tpl ($.Files.Get "files/application-template.yaml") . }}
{{- end -}}
```

We can quickly test that our chart is working as expected by templating it using:

```sh
$ helm template . --set-json='{"applications": [{"name": "foo"}, {"name": "bar"}]}'
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

## x. Creating Template for ApplicationSets

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
    {{- $.Files.Get "files/application-template.yaml" | nindent 4 }}
{{- end }}
```

There are a few important things to draw attention to here:

* The templating for `generators` is a little different. This is because `generators` is a required field, so should be set to an empty list if not populated.
* The contents of `files/application-template.yaml` gets inserted under the `templatePatch` field instead of the `template` one. This is because our template isn't valid YAML on its own, and makes use of template blocks such as `with` that only work under `templatePatch`. See the [Template Patch](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Template/#template-patch) docs for further info.
* The `goTemplate` field is hard-coded to `true`. This is because `templatePatch` only works when `goTemplate` is enabled.

We can quicky test our chart is working as expected by templating it using:

```sh
$ helm template . --set-json='{"applicationSets": [{"name": "foo"}, {"name": "bar"}]}'
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