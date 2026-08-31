# Getting Started

!!! tip
    This guide assumes you have a grounding in Kubernetes, Helm & ArgoCD. Please read [understanding the basics](./02-understand-the-basics.md) to learn about these tools.

## Requirements

* A [Kubernetes](https://kubernetes.io/) cluster with [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) installed.
* Installed [kubectl](https://kubernetes.io/docs/reference/kubectl/) command-line tool.
* Have a [kubeconfig](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/) file (default location is `~/.kube/config`).
* Installed [helm](https://helm.sh/docs/intro/install/) command-line tool.
* (Optionally) installed [argocd](https://argo-cd.readthedocs.io/en/stable/cli_installation/) command-line tool.

## Create a Tenant

As a *tenant* is just a logical grouping of resources, you can start configuring the chart using *values* to create the resources of your choosing.

For example:

```sh
helm template . --set-json '{"namespace": {"name": "foo"}}'
```

outputs:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: foo
```

Which could then be installed into a cluster using `helm install`:

```sh
$ helm install tenant-foo . --set-json '{"namespace": {"name": "foo"}}'
NAME: tenant-foo
LAST DEPLOYED: Sat Aug 22 20:18:44 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
```

We can then confirm that the namespace was created successfully:

```sh
$ kubectl get namespace foo
NAME   STATUS   AGE
foo    Active   9s
```

In reality, it would be much better to create an ArgoCD `Application` to deploy the tenant's resources.
