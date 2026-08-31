# Application Defaults

Consider the scenario whereby we want to apply some defaults to applications. For example, we might want all applications to share the same `project` by default, unless it gets overriden.

We would currently have to do this explicitly:

```yaml title="values.yaml"
applications:
  foo:
    project: some-project
  bar:
    project: some-project
```

However, as we're all big fans of [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself), this approach doesn't quite fly.

We could try and leverage [YAML anchors](https://yaml.org/spec/1.2.2/#anchors-and-aliases) in the following way:

```yaml title="values.yaml"
_applicationDefaults: &applicationDefaults
  project: some-project

applications:
  foo:
    <<: *applicationDefaults
  bar:
    <<: *applicationDefaults
```

Which, when evaluated, using:

```sh
$ yq 'explode(.)' values.yaml
```

becomes:

```yaml
_applicationDefaults:
  project: some-project
applications:
  foo:
    project: some-project
  bar:
    project: some-project
```

Although in theory this has done what we wanted, in practice YAML anchors are not a viable solution for this as demonstrated below:

```yaml title="values.yaml"
_applicationDefaults: &applicationDefaults
  source:
    repoURL: some-repo

applications:
  foo:
    <<: *applicationDefaults
  bar:
    <<: *applicationDefaults
    source:
      targetRevision: 1.2.3
```

When evaluated using:

```sh
yq 'explode(.)' values.yaml
```

becomes:

```yaml
_applicationDefaults:
  source:
    repoURL: some-repo
applications:
  foo:
    source:
      repoURL: some-repo
  bar:
    source:
      targetRevision: 1.2.3
```

Hang on! Where did `source.repoURL` go for the `bar` application??
The short answer is that YAML anchors are not designed for merging values in this way, and are therefore unsuitable to be used as *defaults* in this way.

??? info "The longer answer"
	When the YAML document gets parsed, due to the anchors, it will be treated in the following way:

	```yaml
	_applicationDefaults:
	  source:
	    repoURL: some-repo
	applications:
	  foo:
	    source:
	      repoURL: some-repo
	  bar:
	  	source:
	  	  repoURL: some-repo
	    source:
	      targetRevision: 1.2.3
	```

	As you can see, the `bar` application ends up with two `source` blocks! This is because the contents of the anchor gets **inserted**, not *merged*.

	Having duplicate keys in this way will cause the second `source` object to **overwrite** the first one, hence the `repoURL` "default" never gets set on the `bar` application.

	!!! info
		For more information, see the [Merge Key Language-Independent Type for YAML™ Version 1.1](https://yaml.org/type/merge.html) docs.

## Implementing a Solution

To implement a viable solution, we should avoid YAML anchors. Instead, we can introduce a new `applicationDefaults` object which would enable us to specify application defaults.
Helm can then handle the merge operation itself instead.

Conceptually, values for this would look like the following:

```yaml title="values.yaml"
applicationDefaults:
  source:
    repoURL: some-repo

applications:
  foo: {}
  bar:
    source:
      targetRevision: 1.2.3
```

In the above example, both applications should inherit the `source.repoURL`, and the `bar` application would additionally specify `source.targetRevision`.

To add support for this to our chart, we can update our `tenant.application.template` helper in `templates/_helpers.tpl` to merge our resource values on top of the defaults.

Let's update our `tenant.application.template` helper to become the following:

```smarty title="templates/_helpers.tpl" hl_lines="2-7 9" linenums="1"
{{- define "tenant.application.template" -}}
  {{- "{{- /* Apply defaults */ -}}" }}
  {{- printf "{{- $appDefaults := `%s` | fromJson -}}" ($.Values.applicationDefaults | default dict | toJson) | nindent 0 }}
  {{- "{{- $applicationData := mustMergeOverwrite $appDefaults (deepCopy .) -}}" | nindent 0 }}
  {{- "" | nindent 0}}

  {{- "{{- with $applicationData -}}" | nindent 0 }}
    {{- $.Files.Get "files/application-template.yaml" | trim | nindent 0 }}
  {{- "{{- end -}}" | nindent 0 }}
{{- end -}}
```

!!! warning
	The above template contains two layers of templating, as it's a template that *creates* a template.

	The `tenant.application.template` helper can be tested by creating the following file:

	```smarty title="templates/test/application-template.tpl"
	{{- if .Values.__test -}}
	{{ include "tenant.application.template" $ }}
	{{- end -}}
	```

	Which can then be templated using:

	```sh
	helm template . --show-only templates/test/application-template.tpl --set __test=true --debug 2>/dev/null
	```

	It's **strongly** recommended to test any changes to the `files/application-template.yaml` file or `tenant.application.template` helper in this way.

	Tools such as [helm-unittest](https://github.com/helm-unittest/helm-unittest) exist for unit-testing Helm charts, which may also prove helpful.

	!!! tip
		It's also possible to dump the application template using an application set resource in the following way:

		```sh
		helm template . --set-json '{"applicationSets": {"_": {}}}' | yq .spec.templatePatch
		```

The lines we added to the `tenant.application.template` helper do the following things:

1. Line 2 - Just a comment that gets added to the created template for readability
1. Line 3 - Stores the application defaults in the created template as an `$appDefaults` variable. This is done as we can't merge them upfront in the `tenant.application.template` helper, as (especially in the context of an `ApplicationSet`) we don't actually know our application data yet!
1. Line 4 - Merges the application's data on top of the defaults. The result is stored in an `$applicationData` variable instead of modifying the source.
1. Line 5 - A newline added between the defaults & the application template file for readability
1. Lines 7 & 9 - As the true application data is now stored in an `$applicationData` variable, we encapsulate the application template in a `with` block, to ensure it will get templated in the correct context.

We can check that our defaults are working by templating the chart using the following values:

```yaml title="values.yaml"
applicationDefaults:
  project: some-project

applications:
  foo: {}
  bar:
    project: bar-project
```

And the following command:

```sh
helm template .
```

Which yields the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bar
spec:
  project: bar-project
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
spec:
  project: some-project
```

In the above output, we can see:

1. The `foo` application inherited the default `project` from `applicationDefaults`
1. The `bar` application overode the default `project` with its own `bar-project`

!!! note
	Importantly, these application defaults will also be applied to applications created by application sets.
