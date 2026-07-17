# Improvements - Objects over Lists

So far this chart provides the ability to specify resource-specific defaults (e.g. `applicationDefaults`) or even common defaults (via `common`).

As Helm is being used, it's also possible to merge overrides from multiple values files.

Whilst this all sounds great, in practice it currently gets a bit fiddly. For example, consider the following values:

```yaml title="values.yaml"
applicationDefaults:
  sources:
    - repoURL: some-main-source

applications:
  foo:
    sources:
      - repoURL: some-additional-source
```

When templated, this currently produces the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
spec:
  sources:
    - repoURL: some-additional-source
```

Here you can see that the `foo` application wasn't able to add its own additional source. This is due to `sources` being a list instead of an object.

Instead it would be preferable if sources could be configured using an object, for example in the following way:

```yaml title="values.yaml"
applicationDefaults:
  sourcesObject:
    main:
      repoURL: some-main-source

applications:
  foo:
    sourcesObject:
      additional:
        repoURL: some-additional-source
```

This way, Helm would be able to merge the `sourcesObject` and maintain both the `main` and `additional` source.

However, this isn't an isolated problem. Below are a few examples of fields that use lists (making them hard to merge!):

* `application.spec.info` (`<[]Object>`)
* `application.spec.sources` (`<[]Object>`)
* `application.spec.syncPolicy.syncOptions` (`<[]string>`)
* `applicationset.spec.generators` (`<[]Object>`)
* `applicationset.spec.goTemplateOptions` (`<[]string>`)

The plan is to add *additional* "object" fields, so that merging can be used:

* `info` -> `infoObject`
* `sources` -> `sourcesObject`
* `syncOptions` -> `syncOptionsObject`
* `generators` -> `generatorsObject`
* `goTemplateOptions` -> `goTemplateOptionsObject`

The reasons for tackling the problem this way are:

* We don't break backward-compatability with the native application specification (the original fields will continue to work just fine)
* Users can opt-in to the new fields, enabling better support for merging

## Implementing a Solution

### Application - Info

We can make the following change to the `files/application-template.yaml` file:

```diff title="files/application-template.yaml"
--- files/application-template.yaml
+++ files/application-template.yaml
@@ -19,8 +19,14 @@ spec:
   {{- with .ignoreDifferences }}
   ignoreDifferences: {{- . | toYaml | nindent 4 }}
   {{- end }}
-  {{- with .info }}
-  info: {{- . | toYaml | nindent 4 }}
+  {{- if .infoObject }}
+  info:
+    {{- range $key, $val := .infoObject }}
+    - name: {{ $key | snakecase | replace "_" " " | title }}
+      value: {{ $val }}
+    {{- end }}
+  {{- else if .info }}
+  info: {{- .info | toYaml | nindent 4 }}
   {{- end }}
   {{- with .project }}
   project: {{ . }}
```

In the above diff, we've added the following logic:

1. If `.infoObject` has a value, it will be used and `.info` will be ignored
1. The map keys are transformed into title case (e.g. `fooBar` -> `Foo Bar`) and used as the info entry's "name"
1. The map values are used (unchanged) as the info entry's "value"

To test it's working, we can template the chart using the following values:

```yaml title="values.yaml"
applicationDefaults:
  infoObject:
    supportLink: https://mattermost.corp/some-team

applications:
  foo:
    infoObject:
      repoUrl: https://git.corp/some-repo
```

Which should output the following:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
spec:
  info:
    - name: Repo Url
      value: https://git.corp/some-repo
    - name: Support Link
      value: https://mattermost.corp/some-team
```

### Application - Sources

We can make the following change to the `files/application-template.yaml` file:

```diff title="files/application-template.yaml"
--- files/application-template.yaml
+++ files/application-template.yaml
@@ -40,8 +40,15 @@ spec:
   {{- with .sourceHydrator }}
   sourceHydrator: {{- . | toYaml | nindent 4}}
   {{- end }}
-  {{- with .sources }}
-  sources: {{- . | toYaml | nindent 4 }}
+  {{- if .sourcesObject }}
+  sources:
+    {{- range $sourceId, $_ := .sourcesObject }}
+    {{- $_ := set . "ref" (.ref | default $sourceId) }}
+    {{- $_ := set . "name" (.name | default $sourceId) }}
+    - {{ . | toYaml | nindent 6 | trim }}
+    {{- end }}
+  {{- else if .sources }}
+  sources: {{- .sources | toYaml | nindent 4 }}
   {{- end }}
   {{- with .syncPolicy }}
   syncPolicy: {{- . | toYaml | nindent 4 }}
```

In the above diff, we've added the following logic:

1. If `.sourcesObject` has a value, it will be used and `.sources` will be ignored
1. Unless set, the source's ID (map key) will be used as the `ref` and `name`

To test it's working, we can template the chart using the following values:

```yaml title="values.yaml"
applicationDefaults:
  sourcesObject:
    main:
      repoURL: main-repo

applications:
  foo:
    sourcesObject:
      extra:
        repoURL: extra-repo
```

Which should output the following:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
spec:
  sources:
    - name: extra
      ref: extra
      repoURL: extra-repo
    - name: main
      ref: main
      repoURL: main-repo
```

### Application - Sync Options

We can make the following change to the `files/application-template.yaml` file:

```diff title="files/application-template.yaml"
--- files/application-template.yaml
+++ files/application-template.yaml
@@ -51,5 +51,12 @@ spec:
   sources: {{- .sources | toYaml | nindent 4 }}
   {{- end }}
   {{- with .syncPolicy }}
+    {{- with .syncOptionsObject }}
+      {{- $syncOptions := list }}
+      {{- range $key, $val := . }}
+        {{- $syncOptions = append $syncOptions (printf "%s=%s" (title $key) (toString $val)) }}
+      {{- end }}
+      {{- $_ := set $.syncPolicy "syncOptions" $syncOptions }}
+    {{- end }}
   syncPolicy: {{- . | toYaml | nindent 4 }}
   {{- end }}
```

In the above diff, we've added the following logic:

1. If `.syncPolicy.syncOptionsObject` has a value, it will be used and `.syncPolicy.syncOptions` will be ignored
2. The sync option's key (map key) will be converted to title case (e.g. `serverSideApply` -> `ServerSideApply`)
3. The sync option's value (map value) will be converted to a string (e.g. `true` -> `"true"`)
4. The transformed key & value are added to the list of sync options in the format `{key}={value}`

To test it's working, we can template the chart using the following values:

```yaml title="values.yaml"
applicationDefaults:
  syncPolicy:
    syncOptionsObject:
      serverSideApply: true

applications:
  foo:
    syncPolicy:
      syncOptionsObject:
        validate: false
```

Which should output the following:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
spec:
  syncPolicy:
    syncOptionsObject:
      serverSideApply: true
      validate: false
```

### ApplicationSet - Generators

We can make the following change to the `files/application-template.yaml` file:

```diff title="files/application-template.yaml"

```

In the above diff, we've added the following logic:

1. Foo

To test it's working, we can template the chart using the following values:

```yaml title="values.yaml"

```

Which should output the following:

```yaml

```

### ApplicationSet - Go Template Options

We can make the following change to the `files/application-template.yaml` file:

```diff title="files/application-template.yaml"

```

In the above diff, we've added the following logic:

1. Foo

To test it's working, we can template the chart using the following values:

```yaml title="values.yaml"

```

Which should output the following:

```yaml

```
