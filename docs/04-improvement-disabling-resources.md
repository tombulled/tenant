# Disabling Resources

## The Problem

Currently all `Application` and `ApplicationSet` resources are **always** created (enabled), and there's no way to *opt-out* of creating them.

For example, consider the case whereby we always wanted a `metrics` application to be created, *except* in one specific case (e.g. for a tenant that doesn't want metrics).

A common way of controlling whether a resource should be created would be to filter out resources with `nil` data.

For example, in the following scenario, the `foo` application **would** get created, whereas the `bar` application **wouldn't** get created:

```yaml title="values.yaml"
applications:
  foo: {}
  bar: ~
```

Whilst this is generally a good approach (and is one that is worth supporting), it doesn't support the ability to define a resource in a base values file, but disable it by default.

For example, the following wouldn't work:

```yaml title="values-base.yaml"
applications:
  # I want to define defaults for `foo`, but also want it disabled.
  # I can't set this to `nil`, as then the defaults can't be set/used!
  foo:
    source:
      repoURL: some-repo
```

To support this use case, we can instead introduce a `.enabled` boolean flag which can control resource creation.

For example, we would be able to do the following:

```yaml title="values-base.yaml"
applications:
  foo:
    enabled: false # <-- The `foo` application is disabled by default, but has some handy defaults
    source:
      repoURL: some-repo
```

```yaml title="values-specific.yaml"
applications:
  foo:
    enabled: true # <-- We opt-in to the `foo` application and inherit the defaults
    source:
      chart: some-chart
```

Which, when templated using `-f values-base.yaml -f values-specific.yaml`, we would expect to create the `foo` application as expected.

## Implementating a Solution

In the `templates/_helpers.tpl` file we currently already define a `tenant.resource.data` named template (helper), which currently defaults resource names to their IDs.
We can modify this helper to output no resource data for resources that are *disabled*.

In the `templates/_helpers.tpl` file, let's change the `tenant.resource.data` helper to become:

```smarty title="templates/_helpers.tpl" hl_lines="6-9 11-13 21"
{{- define "tenant.resource.data" -}}
  {{- /* Extract arguments */ -}}
  {{- $id := .id -}}
  {{- $data := .data -}}

  {{- /* If the resource data is nil, disable this resource (it is considered unwanted) */ -}}
  {{- if eq $data nil -}}
    {{- $data = dict "enabled" false -}}
  {{- end -}}

  {{- /* Only create a resource if it is enabled (defaults to enabled unless told otherwise) */ -}}
  {{- $enabled := ternary $data.enabled true (ne $data.enabled nil) }}
  {{- if $enabled -}}
    {{- /* If unspecified, default the resource's name to the resource's ID */ -}}
    {{- if eq $data.name nil -}}
      {{- $_ := set $data "name" $id -}}
    {{- end -}}

    {{- /* Finally, output the new resource data */ -}}
    {{- $data | toYaml -}}
  {{- end -}}
{{- end -}}
```

!!!tip
	In the above helper, resource data only gets output if the `$enabled` variable is true.

This is actually **the only change that's necessary!**. This is due to the use of a `with` block in the resource templates.

For example, if we take a look at `templates/applications.yaml`:

```yaml title="templates/applications.yaml" hl_lines="2"
{{- range $id, $_ := .Values.applications -}}
{{- with include "tenant.resource.data" (dict "id" $id "data" .) | fromYaml }}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
{{ tpl ($.Files.Get "files/application-template.yaml") . }}
{{- end }}
{{- end -}}
```

You'll see that the resource only ever gets created if `tenant.resource.data` outputs some resource data. Nifty!

## Testing It Works

To test that these changes work as expected, let's template the chart using the following values:

```yaml title="values.yaml"
applications:
  foo: {}
  bar:
    enabled: false
```

We can then template the chart using:

```sh
helm template .
```

Which should produce the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
spec:
```

Here we can see that the `foo` application get created (as it's implicitly enabled), whereas the `bar` application **doesn't get created** as it's explicitly disabled.

This would also work with the following values:

```yaml
applications:
  foo: {}
  bar: ~
```

Both approaches are supported, depending upon your specific use case.
