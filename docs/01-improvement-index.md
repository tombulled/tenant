# Improvement x - Maps of Resources

Currently our `tenant` Helm chart supports configuring `Application` and `ApplicationSet` resources from *lists*.

An example [values file](https://helm.sh/docs/chart_template_guide/values_files/) would look something like this:

```yaml title="values.yaml"
applications:
  - name: foo
  - name: bar

applicationSets:
  - name: foo
  - name: bar
```

However, due to the way Helm merges values, working with lists makes it impossible to override values of specific applications & applicationsets.

A common mitigation for this is to instead use maps. The above `values.yaml` could be re-written to become:

```yaml title="values.yaml"
applications:
  foo:
    name: foo
  bar:
    name: bar

applicationSets:
  foo:
    name: foo
  bar:
    name: bar
```

With the above change, the Helm chart will still template out our resources as expected:

```sh
$ helm template .
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bar
<truncated>
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
<truncated>
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: bar
<truncated>
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: foo
<truncated>
```

However, if you're also a fan of the [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) principle, you'll have noticed that we're specifying resource names twice which feels undesirable.

Instead, the map keys could be considered resource *IDs*, instead of resource *names*.
This would enable you to freely change the application name without needing to update all occurences of the application's ID,
and would allow you to **default the application name to its ID**.

# x. Update Templates

The `templates/applications.yaml` template can be updated in the following way:

```diff title="templates/applications.yaml"
- {{- range .Values.applications -}}
+ {{- range $id, $_ := .Values.applications -}}
+ {{- if eq .name nil }}
+   {{- set . "name" $id }}
+ {{- end }}
```

The `templates/applicationsets.yaml` template can be updated in the following way:

```diff title="templates/applicationsets.yaml"
- {{- range .Values.applicationSets -}}
+ {{- range $id, $_ := .Values.applicationSets -}}
+ {{- if eq .name nil }}
+   {{- set . "name" $id }}
+ {{- end }}
```

We can then update our values to omit the explicit resource names (as these will be inferred from the resource IDs):

```yaml title="values.yaml"
applications:
  foo: {}
  bar: {}

applicationSets:
  foo: {}
  bar: {}
```

With the above changes, our `helm template` command should yield the same output as before:

```sh
$ helm template .
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bar
<truncated>
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
<truncated>
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: bar
<truncated>
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: foo
<truncated>
```

With these changes in place, we can now:

1. Easily merge in overrides (e.g. from another values file)
2. Not repeat the application name, as it's inferred from the ID!

However... if you're still a fan of the DRY principle, you'll have noticed that we made the exact same change to both of our templates - yuck!

Fortunately, Helm makes it easy to reduce repetition by storing re-usable blocks of logic such as this in [Named Templates](https://helm.sh/docs/chart_template_guide/named_templates/).

# x. Using a Named Template to reduce repetition

We can introduce the following new file:

```yaml title="templates/_helpers.tpl"
{{- define "build-resource-data" -}}
  {{- /* Extract arguments */ -}}
  {{- $id := .id -}}
  {{- $data := .data -}}

  {{- /* If unspecified, default the resource's name to the resource's ID */ -}}
  {{- if eq $data.name nil -}}
    {{- $_ := set $data "name" $id -}}
  {{- end -}}

  {{- /* Finally, output the new resource data */ -}}
  {{- $data | toYaml -}}
{{- end -}}
```

We can then update our application & applicationset templates again to make use of this *helper*:

```diff title="templates/applications.yaml"
 {{- range $id, $_ := .Values.applications -}}
-{{- if eq .name nil }}
-  {{- set . "name" $id }}
-{{- end }}
+{{- with include "build-resource-data" (dict "id" $id "data" .) | fromYaml }}
 ---
 apiVersion: argoproj.io/v1alpha1
 kind: Application
 {{ tpl ($.Files.Get "files/application-template.yaml") . }}
+{{- end }}
 {{- end -}}
```

```diff title="templates/applicationsets.yaml"
@@ -1,7 +1,5 @@
 {{- range $id, $_ := .Values.applicationSets -}}
-{{- if eq .name nil }}
-  {{- set . "name" $id }}
-{{- end }}
+{{- with include "build-resource-data" (dict "id" $id "data" .) | fromYaml }}
 ---
 apiVersion: argoproj.io/v1alpha1
 kind: ApplicationSet
@@ -43,3 +41,4 @@ spec:
   templatePatch: |
     {{- $.Files.Get "files/application-template.yaml" | nindent 4 }}
 {{- end }}
+{{- end }}
```

Now we can use `helm template` again to confirm that the chart is still working as expected.

... and yes, I realise the irony in reducing repetition by adding an indentical line to each template,
however sometimes small amounts of repetition are ok to keep things readable. [Too much abstraction can be a bad thing!](https://grugbrain.dev/#grug-on-factring-your-code)
