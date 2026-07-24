# Custom Git-Merge Generator

Let's imagine that we want to deploy a set of applications. For this example we'll use `cert-manager` and `traefik`.

Let's focus on `cert-manager` to begin with. Using the `tenant` chart we could simply deploy it like this:

```yaml title="values.yaml"
applications:
  cert-manager:
    destination:
      name: in-cluster
      namespace: cert-manager
    project: default
    source:
      repoURL: quay.io/jetstack/charts
      chart: cert-manager
      targetRevision: v1.19.1
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
```

However, we'll almost certainly want to specify our own values. Let's add support for our own values files:

```yaml title="values.yaml" hl_lines="7-16"
applications:
  cert-manager:
    destination:
      name: in-cluster
      namespace: cert-manager
    project: default
    sources:
      - repoURL: quay.io/jetstack/charts
        chart: cert-manager
        targetRevision: v1.19.1
        helm:
          valueFiles:
            - $values/cert-manager/values.yaml
      - repoURL: git@github.com:example/values.git
        targetRevision: main
        ref: values
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
```

!!! tip
	In the above example, we're creating a [multi-source application](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/), that sources a Helm chart from the `quay.io` registry, and Helm values from a private GitHub repository.

To see what gets created, we can template the chart using `helm template .`, which should output the following:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
spec:
  destination:
    name: in-cluster
    namespace: cert-manager
  project: default
  sources:
    - chart: cert-manager
      helm:
        valueFiles:
        - $values/cert-manager/values.yaml
      repoURL: quay.io/jetstack/charts
      targetRevision: v1.19.1
    - ref: values
      repoURL: git@github.com:example/values.git
      targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

!!! note
	You should notice that the above application resource doesn't look too different from how we configured it in our `values.yaml`. This is deliberate! The `tenant` chart tries to stay out of your way as much as possible.

Now, let's update our values to also install `traefik` in the same way:

```yaml title="values.yaml" hl_lines="21-39"
applications:
  cert-manager:
    destination:
      name: in-cluster
      namespace: cert-manager
    project: default
    sources:
      - repoURL: quay.io/jetstack/charts
        chart: cert-manager
        targetRevision: v1.19.1
        helm:
          valueFiles:
            - $values/cert-manager/values.yaml
      - repoURL: git@github.com:example/values.git
        targetRevision: main
        ref: values
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
  traefik:
    destination:
      name: in-cluster
      namespace: traefik
    project: default
    sources:
      - repoURL: https://traefik.github.io/charts
        chart: traefik
        targetRevision: 41.0.0
        helm:
          valueFiles:
            - $values/traefik/values.yaml
      - repoURL: git@github.com:example/values.git
        targetRevision: main
        ref: values
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
```

Crikey, we're only deploying two applications and things are already getting a bit noisy!

However... you may notice that there are actually **quite a few similarities between both applications**. Namely, they're both:

1. Being deployed into the same cluster as ArgoCD (`destination.name: in-cluster`)
1. Being deployed into a namespace with the same name as the application (`destination.name: <application name>`)
1. Using the `default` project
1. Sourcing a Helm chart from a registry, where the chart name is the same as the application's name (`sources[0].chart: <application name>`)
1. Sourcing a value file called `values.yaml` from the `$values` source, inside a directory with the same name as the application (.`sources[0].helm.valueFiles[0]: $values/<application name>/values.yaml`)
1. Sourcing external Helm values from the `main` branch of a `git@github.com:example/values.git` repository (`sources[1]`)
1. Automatically syncing changes, with pruning and self-healing enabled (`syncPolicy`)

Fortunately, the `tenant` chart supports application defaults and self-templating, so we can dramatically simplify the above down to just:

```yaml title="values.yaml"
applicationDefaults:
  destination:
    name: in-cluster
    namespace: "{{.name}}"
  project: default
  sourcesObject:
    main:
      chart: "{{.name}}"
      helm:
        valueFiles:
          - $values/{{.name}}/values.yaml
    values:
      repoURL: git@github.com:example/values.git
      targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

applications:
  cert-manager:
    sourcesObject:
      main:
        repoURL: quay.io/jetstack/charts
        targetRevision: v1.19.1
  traefik:
    sourcesObject:
      main:
        repoURL: https://traefik.github.io/charts
        targetRevision: 41.0.0
```

Isn't that beautiful!

Imagine how simple it is now to just stamp out even more applications!

However, let's imagine that we actually have separate `dev`, `ref` and `ops` clusters, and we now need to deploy our `cert-manager` and `traefik` applications into each of them.
Not only that, but they each need their own cluster-specific value files :dizzy_face:

Well, fortunately that's not that hard either! Let's update our values to cater for this:

```yaml title="values.yaml" hl_lines="10 13"
applicationDefaults:
  destination:
    name: in-cluster
    namespace: "{{.name}}"
  project: default
  sourcesObject:
    main:
      chart: "{{.name}}"
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
          - $values/{{.name}}/values.yaml
          - $values/{{.name}}/values-{{.metadata.cluster}}.yaml
    values:
      repoURL: git@github.com:example/values.git
      targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

applications:
  cert-manager:
    sourcesObject:
      main:
        repoURL: quay.io/jetstack/charts
        targetRevision: v1.19.1
  traefik:
    sourcesObject:
      main:
        repoURL: https://traefik.github.io/charts
        targetRevision: 41.0.0
```

!!! tip
	`ignoreMissingValueFiles` is used to tell ArgoCD to safely ignore any missing value files.
	In this example, that means that if we don't need any cluster-specific values for an application, the file doesn't need to exist.

That's it! :slightly_smiling_face:

We can test its working by templating the chart using the following command:

```sh
helm template . --set defaults.metadata.cluster=dev
```

!!! note
	In the above command we're specifying which cluster the applications are destined for.

Which should output the following:

```yaml hl_lines="15 18 45 48"
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
spec:
  destination:
    name: in-cluster
    namespace: cert-manager
  project: default
  sources:
    - chart: cert-manager
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
        - $values/cert-manager/values.yaml
        - $values/cert-manager/values-dev.yaml
      name: main
      ref: main
      repoURL: quay.io/jetstack/charts
      targetRevision: v1.19.1
    - name: values
      ref: values
      repoURL: git@github.com:example/values.git
      targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
spec:
  destination:
    name: in-cluster
    namespace: traefik
  project: default
  sources:
    - chart: traefik
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
        - $values/traefik/values.yaml
        - $values/traefik/values-dev.yaml
      name: main
      ref: main
      repoURL: https://traefik.github.io/charts
      targetRevision: 41.0.0
    - name: values
      ref: values
      repoURL: git@github.com:example/values.git
      targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Now, you might've seen the title of this page and wondered where I'm going with all this...

Essentially, adding cluster-specific overrides for application *values* is pretty easy (as demonstrated above), however adding cluster-specific overrides for application *definitions* isn't *necessarily* so easy.

This ultimately comes down to the way applications get deployed. For now, let's assume that we're running single-tenant clusters and we want to use a single `ApplicationSet` per cluster to create applications using a `git` generator.

We can use the `tenant` chart to build such an `ApplicationSet`:

```yaml title="values.yaml"
applicationSets:
  root:
    template:
      spec:
        project: default
    generators:
      - git:
          repoURL: git@github.com:example/apps.git
          revision: main
          files:
            - path: "*.yaml"
```

We could convert the above example to use cluster-specific application definitions in the following way:


```yaml title="values.yaml"
applicationSets:
  root:
    template:
      spec:
        project: default
    generators:
      - git:
          repoURL: git@github.com:example/apps.git
          revision: main
          files:
            - path: "{{.metadata.cluster}}/*.yaml"
```

However that now means that if we wanted to deploy cluster-specific `cert-manager` and `traefik` apps into each of our clusters, we'd have to copy-paste the application definitions under cluster-specific directories.
There's got to be a better way!

What would be preferable instead, would be to mimic how Helm allows you to template a chart using multiple value files, where there's a specific order of precedence.
This would allow us to have some *base* values for the application manifest that all clusters inherit, and then they can *optionally* override them if needed.

It turns out that ArgoCD application sets can absolutely be configured to behave in this way, when the `git` generator gets paired with the `merge` generator.

Let's tweak our application set to also make use of the `merge` generator:

```yaml title="values.yaml" linenums="1" hl_lines="7-24"
applicationSets:
  root:
    template:
      spec:
        project: default
    generators:
      - merge:
          generators:
            - git:
                 repoURL: git@github.com:example/apps.git
                 revision: main
                 files:
                   - path: "*/values.yaml"
                 values:
                   mergeKey: '{{ `{{ $_ := set . "mergeKey" .path.path }}` }}'
            - git:
                repoURL: git@github.com:example/apps.git
                revision: main
                files:
                  - path: "*/values-{{.metadata.cluster}}.yaml"
                values:
                  mergeKey: '{{ `{{ $_ := set . "mergeKey" .path.path }}` }}'
          mergeKeys:
            - mergeKey
```

Ok, there's a lot to unpack there, so let's dive in. These are the main things that have changed:

1. We're now using a [merge generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Merge/) which contains two [git generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)
1. Override precedence is bottom-to-top: the values from a matching parameter set produced by generator 2 will take precedence over the values from the corresponding parameter set produced by generator 1. In this example, cluster-specific values will override the base values.
1. Merging on nested values (e.g. `.path.path`) while using `goTemplate: true` is currently not supported, therefore a top-level (non-nested) `mergeKey` field gets added to the context with the value of `.path.path`.

For this example, we'd then have a directory per application, with values files contained within, like this:

```sh
$ tree apps
apps
├── cert-manager
│   ├── values-dev.yaml
│   ├── values-ops.yaml
│   ├── values-ref.yaml
│   └── values.yaml
└── traefik
    ├── values-dev.yaml
    ├── values-ops.yaml
    ├── values-ref.yaml
    └── values.yaml

2 directories, 8 files
```

Looks very Helm-like doesn't it!

We can also go one step further and propagate the directory name as the application's ID, then application names can be automatically inferred!

Let's update out `ApplicationSet` to propagate the directory name as the application ID:

```yaml title="values.yaml" linenums="1" hl_lines="16 24"
applicationSets:
  root:
    template:
      spec:
        project: default
    generators:
      - merge:
          generators:
            - git:
                 repoURL: git@github.com:example/apps.git
                 revision: main
                 files:
                   - path: "*/values.yaml"
                 values:
                   mergeKey: '{{ `{{ $_ := set . "mergeKey" .path.path }}` }}'
                   id: '{{ $_ := set . "id" .path.basename }}'
            - git:
                repoURL: git@github.com:example/apps.git
                revision: main
                files:
                  - path: "*/values-{{.metadata.cluster}}.yaml"
                values:
                  mergeKey: '{{ `{{ $_ := set . "mergeKey" .path.path }}` }}'
                  id: '{{ $_ := set . "id" .path.basename }}'
          mergeKeys:
            - mergeKey
```

Now, althouth this works really well, you'll notice that this is currently configured in the chart's *values*, making it hard to re-use. There's also a lot of repetition between each of the `git` generators in the `merge` generator.

What would be preferable would be for us to be able to be able to provide a mechanism for users to use a git-merge generator such as this, whilst abstracting the complexity of it.

Fundamentally, all a user really needs to specify is:

1. A `repoURL`
1. A `revision`
1. An optional base path
1. A list of file paths
1. An optional merge key (defaults to `.path.path`)
1. An optional ID key (defaults to `.path.basename`)

As such, we could imagine our custom generator git-merge might accept config a bit like this:

```yaml
repoURL: git@github.com:example/apps.git
revision: main
path: "*"
valueFiles:
  - "values.yaml"
  - "values-{{.metadata.cluster}}.yaml"
```

It would conceivably possible to extend this to support sourcing files from different repositories, for example like this:

```yaml
repoURL: git@github.com:example/apps.git
revision: main
path: "*"
valueFiles:
  - "$common/values.yaml"
  - "values.yaml"
  - "values-{{.metadata.cluster}}.yaml"
extraSources:
  common:
    repoURL: git@github.com:example/common.git
    revision: main
```

However, implementation of this is likely best saved until a use case demands it.

## Implementing a Solution

Let's give our custom git-merge generator an ID of `x-git`, where the `x-` prefix highlights that this is *custom*, and not one offered by ArgoCD itself.

For this solution, we're going to need to iterate through the configured list of `generators` and convert any of type `x-git` to a generator made up of types offered by ArgoCD (`git` & `merge` in this case).

Let's first modify the application set template to make use of a new `tenant.application-set.generators` nested-template that will supply a list of generators:

```yaml title="templates/applicationsets.yaml" linenums="17" hl_lines="5-8"
spec:
  {{- if ne .applyNestedSelectors nil }}
  applyNestedSelectors: {{ .applyNestedSelectors }}
  {{- end }}
  {{- with include "tenant.application-set.generators" . | fromYamlArray }}
  generators: {{- . | toYaml | nindent 4 }}
  {{- else }}
  generators: []
```

This means that the application set template now no longer needs to concern itself with *how* the list of generators get created, just that they will exist.

However, as we've removed the post-selector logic in the process, we should first re-add it. Let's create the new `tenant.application-set.generators` nested-template, and get it to delegate to a separate `tenant.application-set.generator.add-selector` nested-template.

We'll add these new nested templates in a new `_applicationset.tpl` file:

```smarty title="templates/_applicationset.tpl"
{{- define "tenant.application-set.generators" -}}
  {{- $generators := ternary (.generatorsObject | values) (.generators | default list) (not (empty .generatorsObject)) -}}

  {{- range $generators -}}
    {{- /* Add a match expression to the selector of all generators that filters out disabled applications */ -}}
    {{- include "tenant.application-set.generator.add-selector" . -}}
  {{- end -}}

  {{- $generators | toYaml -}}
{{- end -}}

{{- define "tenant.application-set.generator.add-selector" -}}
  {{- $matchExpression := (dict
    "key" "enabled"
    "operator" "NotIn"
    "values" (list "false")
  ) -}}

  {{- $_ := set . "selector" (.selector | default dict) -}}
  {{- $matchExpressions := $matchExpression | append (.selector.matchExpressions | default list) -}}
  {{- $_ := set .selector "matchExpressions" $matchExpressions -}}
{{- end -}}
```

Ok, now we should be back to where we were before, just with some logic shifted around a bit.

With this small refactor completed, it should now be easier to slot in a new `tenant.application-set.convert-x-git` nested-template to convert any `x-git` generators.

Let's first update the `tenant.application-set.generators` nested-template to delegate to the new `tenant.application-set.convert-x-git` nested-template:

```smarty title="templates/_applicationset.tpl" hl_lines="8-9"
{{- define "tenant.application-set.generators" -}}
  {{- $generators := ternary (.generatorsObject | values) (.generators | default list) (not (empty .generatorsObject)) -}}

  {{- range $generators -}}
    {{- /* Add a match expression to the selector of all generators that filters out disabled applications */ -}}
    {{- include "tenant.application-set.generator.add-selector" . -}}

    {{- /* Replace all x-git generators with the appropriate merge + git generators */ -}}
    {{- include "tenant.application-set.generator.convert-x-git" . -}}
  {{- end -}}

  {{- $generators | toYaml -}}
{{- end -}}
```

We can then go ahead and create the new `tenant.application-set.generator.convert-x-git` nested-template:

```smarty title="templates/_applicationset.tpl" linenums="1"
{{- define "tenant.application-set.generator.convert-x-git" -}}
  {{- $xGitKey := "x-git" -}}

  {{- with get . $xGitKey -}}
    {{- $repoURL := .repoURL | required "repoURL is required" -}}
    {{- $revision := .revision | required "revision is required" -}}
    {{- $path := .path | default "" | trimSuffix "/" -}}
    {{- $valueFiles := .valueFiles | required "valueFiles is required" -}}
    {{- $values := .values | default dict -}}
    {{- $mergeKey := .mergeKey | default "path.path" -}}
    {{- $idKey := .idKey | default "path.basename" -}}

    {{- if $path -}}
      {{- $path = printf "%s/" $path -}}
    {{- end -}}

    {{- if eq (len $valueFiles) 0 -}}
      {{- fail "Must provide at least one value file" -}}
    {{- end -}}

    {{- $_ := set $values "mergeKey" (printf "{{ $_ := set . \"mergeKey\" .%s }}" $mergeKey) -}}
    {{- $_ := set $values "id" (printf "{{ $_ := set . \"id\" .%s }}" $idKey) -}}

    {{- $gitGenerators := list -}}
    {{- range $valueFile := $valueFiles -}}
      {{- $gitGenerator := (dict
        "git" (dict
          "repoURL" $repoURL
          "revision" $revision
          "files" (list
            (dict
              "path" (printf "%s%s" $path $valueFile)
            )
          )
          "values" $values
        )
      ) -}}

      {{- $gitGenerators = append $gitGenerators $gitGenerator -}}
    {{- end -}}

    {{- $generatorType := "" -}}
    {{- $generatorData := dict -}}

    {{- if eq (len $gitGenerators) 1 -}}
      {{- $generatorType = "git" -}}
      {{- $generatorData = get (index $gitGenerators 0) "git" -}}
    {{- else -}}
      {{- $generatorType = "merge" -}}
      {{- $generatorData = (dict
        "mergeKeys" (list "mergeKey")
        "generators" $gitGenerators
      ) -}}
    {{- end -}}

    {{- $_ := unset $ $xGitKey -}}
    {{- $_ := set $ $generatorType $generatorData -}}
  {{- end -}}
{{- end -}}
```

Ok, that template is a bit intimidating, so let's break it down:

1. On line 2 we create a variable to store our custom generator's key (`x-git` in this case)
1. On line 4 we extract the contents of the `x-git` key of the current context (which is the generator passed to this template). If there was a value, the rest of the template executes (as it's all nested inside this `with` block), otherwise the template does nothing.
1. On lines 5-19 we extract the contents of our custom `x-git` generator and apply necessary defaulting & validation.
1. On lines 21 & 22 we add two additional entries to the generator's `values` object:
	1. `mergeKey` which uses a template to set the `mergeKey` field on the context to the *value* of whichever field was configured via the `x-git` generator's `mergeKey` field.
	1. `idKey` which uses a template to set the `id` field on the context to the *value* of whichever field was configured via the `x-git` generator's `idKey` field.
1. On lines 24-40 we build a list of `git` generators. Each one gets a single file path configured, which will be the path to the value file.
1. On lines 42-54 we decide whether to use either a single `git` generator or a `merge` generator containing multiple `git` generators.
	1. If a single values file was configured, a single `git` generator will be used
	1. If multiple values files were configured, a `merge` generator will be used that contains a `git` generator per values file.
1. On lines 56 & 57 we patch the generator passed to the nested-template to replace the `x-git` field with the new `git`/`merge` field.

Now for the fun part - let's see it in action!

Let's first configure an `x-git` generator with a single values file:

```yaml title="values.yaml"
applicationSets:
  foo:
    generators:
      - x-git:
          repoURL: git@github.com:example/apps.git
          revision: main
          path: "*"
          valueFiles:
            - values.yaml
```

We can then template the chart using the following command:

```sh
helm template . | yq e '.spec.templatePatch = "<truncated>"'
```

Which should output the following:

```yaml
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: foo
spec:
  generators:
    - git:
        files:
          - path: '*/values.yaml'
        repoURL: git@github.com:example/apps.git
        revision: main
        values:
          id: '{{ $_ := set . "id" .path.basename }}'
          mergeKey: '{{ $_ := set . "mergeKey" .path.path }}'
      selector:
        matchExpressions:
          - key: enabled
            operator: NotIn
            values:
              - "false"
  goTemplate: true
  templatePatch: |-
    <truncated>
```

Here we can see the following:

1. The `x-git` generator got replaced by a new standard `git` generator
1. The `id` and `mergeKey` variables have both been added to the `git` generator (although only the `id` one is relevant here)
1. The `selector` (post-selector) is still present

Let's now configure an `x-git` generator with multiple values files:

```yaml title="values.yaml"
applicationSets:
  foo:
    generators:
      - x-git:
          repoURL: git@github.com:example/apps.git
          revision: main
          path: "*"
          valueFiles:
            - values.yaml
            - values-{{.metadata.cluster}}.yaml
```

We can then template the chart using the following command:

```sh
helm template . --set defaults.metadata.cluster=dev | yq e '.spec.templatePatch = "<truncated>"'
```

Which should output the following:

```yaml linenums="1" hl_lines="9-34"
---
# Source: tenant/templates/applicationsets.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: foo
spec:
  generators:
    - merge:
        generators:
          - git:
              files:
                - path: '*/values.yaml'
              repoURL: git@github.com:example/apps.git
              revision: main
              values:
                id: '{{ $_ := set . "id" .path.basename }}'
                mergeKey: '{{ $_ := set . "mergeKey" .path.path }}'
          - git:
              files:
                - path: '*/values-dev.yaml'
              repoURL: git@github.com:example/apps.git
              revision: main
              values:
                id: '{{ $_ := set . "id" .path.basename }}'
                mergeKey: '{{ $_ := set . "mergeKey" .path.path }}'
        mergeKeys:
          - mergeKey
      selector:
        matchExpressions:
          - key: enabled
            operator: NotIn
            values:
              - "false"
  goTemplate: true
  templatePatch: |-
    <truncated>
```

By only adding one line to our `values.yaml` file, the application set's generators have completely changed. Specifically:

1. The `x-git` generator now transformed into a `merge` generator that contains two `git` child generators (one per values file)
1. The `merge` generator has been configured to use the `mergeKey` field as its merge key
1. The `selector` (post-selector) is still present

Going back to the `cert-manager` and `traefik` applications we were originally trying to deploy, let's create *application definition* files for each of them:

```sh
$ tree
.
└── apps
    ├── cert-manager
    │   └── values.yaml
    └── traefik
        └── values.yaml

3 directories, 2 files

$ cat apps/cert-manager/values.yaml
sourcesObject:
  main:
    repoURL: quay.io/jetstack/charts
    targetRevision: v1.19.1

$ cat apps/traefik/values.yaml
sourcesObject:
  main:
    repoURL: https://traefik.github.io/charts
    targetRevision: 41.0.0
```

Let's then update our `values.yaml` file to call reach out to our `apps` repository (using the necessary defaults of course):

```yaml title="values.yaml"
applicationDefaults:
  destination:
    name: in-cluster
    namespace: "{{.name}}"
  project: default
  sourcesObject:
    main:
      chart: "{{.name}}"
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
          - $values/{{.name}}/values.yaml
          - $values/{{.name}}/values-{{.metadata.cluster}}.yaml
    values:
      repoURL: git@github.com:example/values.git
      targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

applicationSets:
  apps:
    generators:
      - x-git:
          repoURL: git@github.com:example/apps.git
          revision: main
          path: "*"
          valueFiles:
            - values.yaml
            - values-{{.metadata.cluster}}.yaml
```

We can then generate the list of applications using this command:

```sh
helm template . --set defaults.metadata.cluster=dev | argocd appset generate /dev/stdin -o yaml
```

Which should output the following:

```yaml
- apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    finalizers:
    - resources-finalizer.argocd.argoproj.io
    name: <no value>
  spec:
    destination:
      name: in-cluster
      namespace: <no value>
    project: default
    sources:
    - chart: <no value>
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
        - $values//values.yaml
        - $values//values-dev.yaml
      name: main
      ref: main
      repoURL: https://traefik.github.io/charts
      targetRevision: 41.0.0
    - name: values
      ref: values
      repoURL: git@github.com:example/values.git
      targetRevision: main
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
- apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    finalizers:
    - resources-finalizer.argocd.argoproj.io
    name: <no value>
  spec:
    destination:
      name: in-cluster
      namespace: <no value>
    project: default
    sources:
    - chart: <no value>
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
        - $values//values.yaml
        - $values//values-dev.yaml
      name: main
      ref: main
      repoURL: quay.io/jetstack/charts
      targetRevision: v1.19.1
    - name: values
      ref: values
      repoURL: git@github.com:example/values.git
      targetRevision: main
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
```

You might notice that the above output doesn't look quite right :cry:

Both applications had no idea what their `name` was!

There's a small piece of gluework missing to default application name's to their ID when they get created by an application set.
