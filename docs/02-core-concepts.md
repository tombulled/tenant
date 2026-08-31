# Core Concepts

Below are some core concepts of the `tenant` chart:

* **Tenant** A logical grouping of resources within a Kubernetes cluster
* **Resource** A Kubernetes resource, e.g. `Namespace`, `Pod`, etc.
* **Resource ID** The unique identifier used to refer to a resource
* **Resource Data** The object the `tenant` chart will use to execute the resource's template

## Example

The below example namespace reveals its resource ID, name and data.

```yaml title="example.yaml"
namespaces:
  # <namespace resource>
  gitlab: # <-- resource ID
    name: cool-gitlab # <-- resource name
    annotations:
      resource-id: "{{ $id }}"
      resource-name: "{{ .name }}"
      resource-data: |
        {{- toPrettyJson . | nindent 6 }}
  # </namespace resource>
```

```sh
helm template tenant -f example.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    resource-data: |
      {
        "annotations": {
          "resource-data": "{{- toPrettyJson . | nindent 6 }}\n",
          "resource-id": "{{ $id }}",
          "resource-name": "{{ .name }}"
        },
        "name": "cool-gitlab"
      }
    resource-id: gitlab
    resource-name: cool-gitlab
  name: cool-gitlab
```
