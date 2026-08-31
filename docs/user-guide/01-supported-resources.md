# Supported Resources

The `tenant` chart supports deploying the following resource types:

* [`Application`](https://argo-cd.readthedocs.io/en/stable/core_concepts/) - A group of Kubernetes resources as defined by a manifest.
* [`ApplicationSet`](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/) - ApplicationSets add Application automation and seeks to improve multi-cluster support and cluster multitenant support within Argo CD. Argo CD Applications may be templated from multiple different sources, including from Git or Argo CD's own defined cluster list.
* [`AppProject`](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/) - Provide a logical grouping of applications, which is useful when Argo CD is used by multiple teams.
* [`ClusterRoleBinding`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#clusterrolebinding-example) - A role binding grants the permissions defined in a role to a user or set of users. It holds a list of subjects (users, groups, or service accounts), and a reference to the role being granted. A ClusterRoleBinding grants access cluster-wide.
* [`ClusterRole`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#clusterrole-example) - An RBAC ClusterRole contains rules that represent a set of permissions. Permissions are purely additive (there are no "deny" rules). ClusterRole is a non-namespaced resource, allowying you to define cluster-wide roles.
* [`LimitRange`](https://kubernetes.io/docs/concepts/policy/limit-range/) - A policy to constrain the resource allocations (limits and requests) that you can specify for each applicable object kind (such as Pod or PersistentVolumeClaim) in a namespace.
* [`Namespace`](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) - Provide a mechanism for isolating groups of resources within a single cluster.
* [`NetworkPolicy`](https://kubernetes.io/docs/concepts/services-networking/network-policies/) - Provide a mechanism to control traffic flow at the IP address or port level (OSI layer 3 or 4), NetworkPolicies allow you to specify rules for traffic flow within your cluster, and also between Pods and the outside world.
* [`ResourceQuota`](https://kubernetes.io/docs/concepts/policy/resource-quotas/) - Provide constraints that limit aggregate resource consumption per namespace.
* [`RoleBinding`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-example) - A role binding grants the permissions defined in a role to a user or set of users. It holds a list of subjects (users, groups, or service accounts), and a reference to the role being granted. A RoleBinding grants permissions within a specific namespace.
* [`Role`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-example) - An RBAC Role contains rules that represent a set of permissions. Permissions are purely additive (there are no "deny" rules). A Role always sets permissions within a particular namespace; when you create a Role, you have to specify the namespace it belongs in.
* [`SealedSecret`](#) - A safe-to-store (even inside public repositories) Secret, which can only be decrypted by the controller running in the target cluster.
* Any additional resources, via *Extra Resources*.
