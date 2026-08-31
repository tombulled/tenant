# tenant

A Helm chart to represent a tenant of a Kubernetes cluster.

## Installing the Chart

To install the chart with the release name `my-tenant`:

```sh
helm install my-tenant tenant -f path/to/values.yaml
```

## Resource Data

### Bitnami

### SealedSecret

| Name            | Description                       | Example                                        |
| --------------- | --------------------------------- | ---------------------------------------------- |
| `annotations`   | Populates: `metadata.annotations` | `{"is-cool": "true"}`                          |
| `finalizers`    | Populates: `metadata.finalizers`  | `["resources-finalizer.argocd.argoproj.io"]`   |
| `labels`        | Populates: `metadata.labels`      | `{"is-cool": "true"}`                          |
| `name`          | Populates: `metadata.name`        | `"some-name"`                                  |
| `namespace`     | Populates: `metadata.namespace`   | `"some-namespace"`                             |
| `data`          | Populates: `spec.data`            | `"some-data"`                                  |
| `encryptedData` | Populates: `spec.encryptedData`   | `{"password": "Ag..."}`                        |
| `template`      | Populates: `spec.template`        | `{metadata: {annotations: {is-cool: "true"}}}` |

### Core

#### Namespace

| Name          | Description                       | Example                                      |
| ------------- | --------------------------------- | -------------------------------------------- |
| `annotations` | Populates: `metadata.annotations` | `{"is-cool": "true"}`                        |
| `labels`      | Populates: `metadata.labels`      | `{"is-cool": "true"}`                        |
| `name`        | Populates: `metadata.name`        | `"some-name"`                                |
| `finalizers`  | Populates: `spec.finalizers`      | `["resources-finalizer.argocd.argoproj.io"]` |
