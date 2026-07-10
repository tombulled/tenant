# Docs

# 1. Introduction
TODO

# x. Prerequisites
Install `helm` and `yq`

# 2. Scaffolding the Chart

First, let's use `helm create` to scaffold us a starter Helm chart

```sh
$ helm create tenant
Creating tenant
$ cd tenant
```

We're going to 

```sh
$ rmdir charts
$ rm -r templates/*
$ echo "" > values.yaml
```

```sh
$ yq e -i '... comments=""' Chart.yaml # Remove (strip) all comments
$ yq e -i '.description = "Tenant Helm Chart"' Chart.yaml
$ yq e -i 'del(.appVersion)' Chart.yaml
```

Let's scaffold a Helm chart:

**1. Creating the Chart Directory**
Let's create, and enter, a directory for the `tenant` chart.
```sh
$ mkdir tenant
$ cd tenant
```

!!! info
	The directory is called `tenant` as it's good practice for the *directory* name to match the *chart* name (specified in the `Chart.yaml` file).

```sh
$ touch values.yaml
$ mkdir templates
$ cat <<EOF >> Chart.yaml
apiVersion: v2
name: tenant
description: Tenant Helm Chart
type: application
version: 0.1.0
EOF
$ cat <<EOF >> .helmignore
# Patterns to ignore when building packages.
# This supports shell glob matching, relative path matching, and
# negation (prefixed with !). Only one pattern per line.
.DS_Store
# Common VCS dirs
.git/
.gitignore
.bzr/
.bzrignore
.hg/
.hgignore
.svn/
# Common backup files
*.swp
*.bak
*.tmp
*.orig
*~
# Various IDEs
.project
.idea/
*.tmproj
.vscode/
EOF
```

```sh
$ tree -a
.
├── .helmignore
├── Chart.yaml
├── templates
└── values.yaml

1 directory, 3 files
```
