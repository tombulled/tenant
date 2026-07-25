# Resource Defaults

In the previous guide, we implemented support for `applicationDefaults`, however what if we also wanted to do the same for a group of `ApplicationSet` resources?

For example, all application sets owned by the same tenant might share defaults such as the same `project`.

Similarly to how `applicationDefaults` was implemented, we could add support for `applicationSetDefaults`.

The values for this would conceptually look like:

```yaml title="values.yaml"
applicationSetDefaults:
  project: some-project

applicationSets:
  foo: {}
  bar: {}
```

## Implementing a Solution

### Resource Defaults

As we've already got a `tenant.resource.data` helper, it should be fairly trivial to update this to also apply some defaults to resources.

Each resource template will need to provide the relevant defaults to the helper (similarly to how they currently provide the resource ID & data).

Let's update the `tenant.resource.data` helper in the `templates/_helpers.tpl` file to expect defaults to be provided, and to apply these to the resource's data:

```smarty title="templates/_helpers.tpl" hl_lines="5 12-13" linenums="1"
{{- define "tenant.resource.data" -}}
  {{- /* Extract arguments */ -}}
  {{- $id := .id -}}
  {{- $data := .data -}}
  {{- $defaults := .defaults | default dict -}}

  {{- /* If the resource data is nil, disable this resource (it is considered unwanted) */ -}}
  {{- if eq $data nil -}}
    {{- $data = dict "enabled" false -}}
  {{- end -}}

  {{- /* Apply defaults */ -}}
  {{- $data = mustMergeOverwrite (deepCopy $defaults) (deepCopy $data) }}

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

We now need to update our resource templates to supply their defaults to the `tenant.resource.data` helper:

```diff title="templates/applications.yaml"
--- templates/applications.yaml
+++ templates/applications.yaml
@@ -1,5 +1,5 @@
 {{- range $id, $_ := .Values.applications -}}
-{{- with include "tenant.resource.data" (dict "id" $id "data" .) | fromYaml }}
+{{- with include "tenant.resource.data" (dict "id" $id "data" . "defaults" $.Values.applicationDefaults) | fromYaml }}
 ---
 apiVersion: argoproj.io/v1alpha1
 kind: Application
```

```diff title="templates/applicationsets.yaml"
--- templates/applicationsets.yaml
+++ templates/applicationsets.yaml
@@ -1,5 +1,5 @@
 {{- range $id, $_ := .Values.applicationSets -}}
-{{- with include "tenant.resource.data" (dict "id" $id "data" .) | fromYaml }}
+{{- with include "tenant.resource.data" (dict "id" $id "data" . "defaults" $.Values.applicationSetDefaults) | fromYaml }}
 ---
 apiVersion: argoproj.io/v1alpha1
 kind: ApplicationSet
```

!!! note

	You might've spotted that we updated the `templates/applications.yaml` template to pass its defaults into the `tenant.resource.data` template.

	Whilst this might not appear necessary (as application defaults are applied by the `tenant.application.template` helper), this is being done deliberately.

	For example, imagine the following scenario:

	```yaml title="values.yaml"
	applicationDefaults:
	  enabled: false

	applications:
	  foo: {}
	```

	In the above scenario, it'll be the `tenant.resource.data` helper that catches that the `foo` application shouldn't be created.

	This means that for `Application` resources the defaults will technically get applied twice.

### Common Defaults

It's possible that we may have a set of values that are common between resources created for a tenant.

In the context of `Application` and `ApplicationSet` resources, these could include scenarios such as the following:

1. Control whether resources should be enabled or not by default, e.g. `enabled: false`
1. Common labels/annotations on all resources, e.g. `owned-by: some-tenant`
1. A default namespace for the tenant, e.g. `namespace: some-tenant`

For now, these common defaults will be most applicable to the `metadata` section of resources (as the format is generally standardised), however in the future it'll also unlock some additional functionality of this chart!

We can conceive that common defaults could be configured in the following way:

```yaml title="values.yaml"
defaults:
  enabled: false # Disable all resources by default
  annotations:
    owning-tenant: some-tenant

applications:
  foo: {}

applicationSets:
  foo: {}
```

To support this, we'll need to update **both** the `tenant.application.template` and `tenant.resource.data` helpers to respect the new common `defaults` defaults.

#### Application Template Helper

First, let's update the `tenant.application.template` helper in `templates/_helpers.tpl` to also make use of `defaults` defaults:

```diff title="templates/_helpers.tpl"
--- templates/_helpers.tpl
+++ templates/_helpers.tpl
@@ -1,7 +1,8 @@
 {{- define "tenant.application.template" -}}
   {{- "{{- /* Apply defaults */ -}}" }}
+  {{- printf "{{- $commonDefaults := `%s` | fromJson -}}" ($.Values.defaults | default dict | toJson) | nindent 0 }}
   {{- printf "{{- $appDefaults := `%s` | fromJson -}}" ($.Values.applicationDefaults | default dict | toJson) | nindent 0 }}
-  {{- "{{- $applicationData := mustMergeOverwrite $appDefaults (deepCopy .) -}}" | nindent 0 }}
+  {{- "{{- $applicationData := mustMergeOverwrite $commonDefaults $appDefaults (deepCopy .) -}}" | nindent 0 }}
   {{- "" | nindent 0}}

   {{- "{{- with $applicationData -}}" | nindent 0 }}
```

We can then test that this is working by templating the chart using the following values:

```yaml title="values.yaml"
defaults:
  annotations:
    owning-tenant: some-tenant

applications:
  foo: {}
```

Which we can template using:

```sh
helm template .
```

For which the output should be:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
  annotations:
    owning-tenant: some-tenant
spec:
```

Here we can see that the `foo` application inherited the `annotations` block from the common `defaults` defaults.

#### Resource Data Helper

We also need to update the `tenant.resource.data` helper to make use of the common `defaults` defaults.

We can do that by making the following changes to the `tenant.resource.data` helper in `templates/_helpers.tpl`:

```diff title="templates/_helpers.tpl"
--- templates/_helpers.tpl
+++ templates/_helpers.tpl
@@ -23,7 +23,8 @@
   {{- end -}}

   {{- /* Apply defaults */ -}}
-  {{- $data = mustMergeOverwrite (deepCopy $defaults) (deepCopy $data) }}
+  {{- $commonDefaults := $root.Values.defaults | default dict }}
+  {{- $data = mustMergeOverwrite (deepCopy $commonDefaults) (deepCopy $defaults) (deepCopy $data) }}

   {{- /* Only create a resource if it is enabled (defaults to enabled unless told otherwise) */ -}}
   {{- $enabled := ternary $data.enabled true (ne $data.enabled nil) }}
```

We now need to update our resource templates to also pass in the root context, so that the `tenant.resource.data` helper can get a handle to the common `defaults` defaults:

```diff title="templates/applications.yaml"
--- templates/applications.yaml
+++ templates/applications.yaml
@@ -1,5 +1,5 @@
 {{- range $id, $_ := .Values.applications -}}
-{{- with include "tenant.resource.data" (dict "id" $id "data" . "defaults" $.Values.applicationDefaults) | fromYaml }}
+{{- with include "tenant.resource.data" (dict "root" $ "id" $id "data" . "defaults" $.Values.applicationDefaults) | fromYaml }}
 ---
 apiVersion: argoproj.io/v1alpha1
 kind: Application
```

```diff title="templates/applicationsets.yaml"
--- templates/applicationsets.yaml
+++ templates/applicationsets.yaml
@@ -1,5 +1,5 @@
 {{- range $id, $_ := .Values.applicationSets -}}
-{{- with include "tenant.resource.data" (dict "id" $id "data" . "defaults" $.Values.applicationSetDefaults) | fromYaml }}
+{{- with include "tenant.resource.data" (dict "root" $ "id" $id "data" . "defaults" $.Values.applicationSetDefaults) | fromYaml }}
 ---
 apiVersion: argoproj.io/v1alpha1
 kind: ApplicationSet
```

We can now test that common `defaults` defaults are being applied to all resources as expected.

Let's template the chart using the following values:

```yaml title="values.yaml"
defaults:
  enabled: false # Disable all resources by default
  annotations:
    owning-tenant: some-tenant

applications:
  foo: {}
  bar:
    enabled: true

applicationSets:
  foo: {}
  bar:
    enabled: true
```

And the following command:

```sh
helm template .
```

Which should yield the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bar
  annotations:
    owning-tenant: some-tenant
spec:
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  annotations:
    owning-tenant: some-tenant
  name: bar
spec:
  generators: []
  goTemplate: true
  templatePatch: |
    <truncated>
```

In the above output we can see that the `foo` application & application didn't get created, as they were disabled by default.
Whereas the `bar` application & application set *were* created, and they inherited the default `owning-tenant` annotation.
