# tenant

A Helm chart to represent a _tenant_ of a Kubernetes cluster.

## Prerequisites

TODO

## Installing the Chart

To install the chart with the release name `my-tenant`:

```sh
helm install my-tenant .
```

> Note: No resources are configured by default, so the above command **won't actually install any resources**

## Resource Data

### Common Fields

| Name          | Description                                                                                                        | Example             |
| ------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------- |
| `enabled`     | Whether to enable or disable the resource. Allows you to control whether it will get created or not.               | `false`             |
| `id`          | Resource ID. You should almost never need to set this, as the chart will set it for you.                           | `"some-id"`         |
| `name`        | Resource name. Allows you to specify the resource's `metadata.name`. Will default to the resource's `id` if unset. | `"some-name"`       |
| `namespace`   | Resource namespace. Allows you to specify the resource's `metadata.namespace`                                      | `"some-namespace"`  |
| `labels`      | Resource labels. Allows you to specify the resource's `metadata.labels`.                                           | `{is-cool: "true"}` |
| `annotations` | Resource annotations. Allows you to specify the resource's `metadata.annotations`.                                 | `{is-cool: "true"}` |
