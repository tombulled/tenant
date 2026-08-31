# Overview

## What is the Tenant Chart?
The `tenant` chart is a [Helm](https://helm.sh/) chart designed to model a *tenant* of a Kubernetes cluster.

Importantly, this chart is designed to be deployed **per tenant**. This chart also functions as a powerful [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern-alternative).

## Why use the Tenant Chart?

Managing a multi-tenanted Kubernetes cluster can be hard.
The aim of this chart is to keep multi-tenancy as simple as possible.
This chart works best with ArgoCD, and doesn't depend on any additional resource orchestration (Crossplane, kro, etc.).
