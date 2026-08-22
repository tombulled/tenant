# Supported Resources

The `tenant` chart supports deploying the following resource types:

* [`Application`](#) - Foo
* [`ApplicationSet`](#) - Foo
* [`AppProject`](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/) - Provide a logical grouping of applications, which is useful when Argo CD is used by multiple teams.
* [`ClusterRoleBinding`](#) - Foo
* [`ClusterRole`](#) - Foo
* [`LimitRange`](https://kubernetes.io/docs/concepts/policy/limit-range/) - A policy to constrain the resource allocations (limits and requests) that you can specify for each applicable object kind (such as Pod or PersistentVolumeClaim) in a namespace.
* [`Namespace`](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) - Provide a mechanism for isolating groups of resources within a single cluster.
* [`NetworkPolicy`](https://kubernetes.io/docs/concepts/services-networking/network-policies/) - Provide a mechanism to control traffic flow at the IP address or port level (OSI layer 3 or 4), NetworkPolicies allow you to specify rules for traffic flow within your cluster, and also between Pods and the outside world.
* [`ResourceQuota`](https://kubernetes.io/docs/concepts/policy/resource-quotas/) - Provide constraints that limit aggregate resource consumption per namespace.
* [`RoleBinding`](#) - Foo
* [`Role`](#) - Foo
* [`SealedSecret`](#) - Foo
* (extra resources)
