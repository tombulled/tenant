# Improvement - Self-Templating

The `tenant` chart is designed to be deployed once per tenant.


!!! note
	That being said, it would absolutely be possible to deploy one `tenant` chart that's responsible for creating resources for multiple tenants... however this **isn't recommended**!

We haven't touched upon orchestrating the deployment of multiple tenants yet, however it's conceivable that some environmental *knowledge* could be passed down to each `tenant` application (and, by extension, the resources it creates).

For example, this information might include:

* Cluster-related information
    * The cluster name/ID, e.g. `some-cluster`
    * The cluster type/category/group, e.g. `dev`
    * The cluster site, e.g. `some-site`
    * The cluster region, e.g. `us-east`
* Tenant-related information
	* The tenant's name/ID, e.g. `some-tenant`
	* The tenant's owner, e.g. `some-team`
* Resource-related information
	* The resource's name or ID, e.g. `some-app`

However, this chart (by design) should make no assumptions about what this information is, as it's likely to vary between users.
We'll refer to this environmental information as **metadata**.

Using YAML anchors we can mimic how this sort of functionality could work:

```yaml title="values.yaml"
_clusterId: &clusterId some-cluster
_clusterType: &clusterType dev
_tenant: &tenant some-tenant

applicationDefaults:
  annotations:
    clusterId: *clusterId
    clusterType: *clusterType
    tenant: *tenant

applications:
  foo: {}
```

Which, once templated using `helm template .`, produces the following output:

```yaml
---
# Source: tenant/templates/applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: foo
  annotations:
    clusterId: some-cluster
    clusterType: dev
    tenant: some-tenant
spec:
```

Whilst this simple example works, it falls short as soon as the values need to be inserted into something.

For example, let's imagine we've got an application called `foo` to deploy.
The `foo` application has an `envValues` directory which contains environment-specific value files:

```sh
$ tree envValues
envValues
├── base.yaml
├── cluster-1.yaml
├── cluster-2.yaml
├── type-dev.yaml
└── type-ops.yaml

0 directories, 5 files
```

For a theoretical cluster `cluster-1` of type `dev`, we'd want to source the following value files (in ascending order of preference):

* `base.yaml`
* `type-dev.yaml`
* `cluster-1.yaml`

However, as YAML anchors are simple aliases, we can't use them like `*clusterId.yaml`.

Instead, it'd be preferable if we could *template* the values themselves, for example in the following way:

```yaml title="values.yaml" linenums="1"
metadata:
  clusterId: cluster-1
  clusterType: dev

applications:
  foo:
    source:
      repoURL: git@github.com:example/charts.git
      targetRevision: main
      path: foo
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
          - "envValues/base.yaml"
          - "envValues/type-{{.metadata.clusterType}}.yaml"
          - "envValues/{{.metadata.clusterId}}.yaml"
```

However, before we rush ahead and implement that, have you spotted that the application's name gets repeated on line 10 (as `foo` is *also* the name of the application's chart)?

It would be cool if we could access the application's name/ID and use that, for example in the following way:

```yaml title="values.yaml"
applications:
  foo:
    source:
      repoURL: git@github.com:example/charts.git
      targetRevision: main
      path: "{{.id}}"
```

However, an important thing to note is that the `.id` is relative to the application's data, whereas `.metadata` was relative to the root of the chart's values.

Instead, we could treat `.metadata` as a user-defined field for them to do with as they please. They could also not define it, or call it something else (such as `.info`) if they wanted.

As it'll get treated as a regular bit of resource data, you could instead implement it in the following way:

```yaml title="values.yaml"
common:
  metadata:
    cluster: some-cluster
    tenant: some-tenant
```

With metadata treated in this way, it'll become available within the data of all resources created by this chart (including applications created by application sets).

To achieve this we'll need to do the following:

1. Propagate resource IDs into the resource data, so that it can be used during self-templating (as `{{.id}}`)
1. Self-template all resource's data
1. Self-template all application's data (*spoiler: this isn't as easy as it sounds!*)

## Implementing a Solution

### Propagating Resource IDs

### Self-Templating Resource Data

### Self-Templating Application Data