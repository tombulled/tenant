# Improvement - Custom Git-Merge Generator

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

```yaml title="values.yaml"
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

Ok. There's a lot to unpack there, so let's dive in.
