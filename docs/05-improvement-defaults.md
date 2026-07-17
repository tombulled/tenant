# Improvement - Defaults

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

We should also support configuring defaults for application sets too, which can be achieved in a very similar fashion:

```yaml title="values.yaml"
applicationSetDefaults:
  project: some-project

applicationSets:
  foo: {}
  bar:
    applyNestedSelectors: true
```

To add support for this to our chart, we ...