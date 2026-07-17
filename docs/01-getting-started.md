# Getting Started

## Introduction

The `tenant` Helm chart is designed to model a single "tenant" of a (optionally multi-tenanted) Kubernetes cluster, where a "tenant" is loosely defined as:

> An owner of one or more namespaces that wishes to deploy their workloads

Importantly, this chart is designed to be deployed **per tenant**. This chart also functions as a powerful [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern-alternative).

## Prerequisites

In order to follow along with this documentation, please ensure you have the following binaries installed:

* [`helm`](https://helm.sh/docs/intro/install/)
* [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [`yq`](https://github.com/mikefarah/yq/#install)
* [`argocd`](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

## Scaffolding the Chart

First, let's use `helm create` to scaffold us a starter Helm chart:

```sh
helm create tenant
cd tenant
```

Next, let's tidy up some of the artifacts we don't need:

```sh
rmdir charts
rm -rf templates/*
echo "" > values.yaml
```

Finally, let's update the `Chart.yaml` to accurately reflect this chart:

```sh
yq e -i '... comments=""' Chart.yaml # Remove (strip) all comments
yq e -i '.description = "Tenant Helm Chart"' Chart.yaml
yq e -i 'del(.appVersion)' Chart.yaml
```

You should now have a file structure that looks like this:

```sh
$ tree -a
.
├── .helmignore
├── Chart.yaml
├── templates
└── values.yaml

1 directory, 3 files
```

Congrats, you've just scaffolded an empty `tenant` Helm chart! :partying_face:
