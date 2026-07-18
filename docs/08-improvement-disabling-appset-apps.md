# Improvement - Disabling ApplicationSet Applications

The `tenant` chart currently supports disabling *resources*, for example as shown below:

```sh
$ helm template . --set-json '{"applications": {"foo": {"enabled": false}}}'
```

The above command should output nothing, as the `foo` application is disabled.

Whilst this works perfectly for all *resources* created by this chart (currently `Application` and `ApplicationSet` resources), this unfortunately **doesn't extend to applications created by application sets**.

We can easily demonstrate this by using a simple `list` generator. Let's use the following values:

```yaml title="values.yaml"
applicationSets:
  foo:
    template:
      spec:
        project: default
    generators:
      - list:
          elements:
            - name: foo
              enabled: true
            - name: bar
              enabled: false
```

We can then template the chart and drive ArgoCD to generate the applications using the following command:

```sh
helm template . | argocd appset generate /dev/stdin -o yaml
```

Which should output the following:

```yaml
- apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    finalizers:
    - resources-finalizer.argocd.argoproj.io
    name: foo
  spec:
    destination: {}
    project: default
- apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    finalizers:
    - resources-finalizer.argocd.argoproj.io
    name: bar
  spec:
    destination: {}
    project: default
```

Here you can see that both applications get created, even though the `bar` application was disabled :cry:

Fortunately, a mechanism exists to filter which applications should get created!

Application set generators support a [post selector](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Post-Selector/), which allows you to post-filter the results of the generator.

Let's update our values to implement this *post selector*:

```yaml title="values.yaml" hl_lines="13-18" linenums="1"
applicationSets:
  foo:
    template:
      spec:
        project: default
    generators:
      - list:
          elements:
            - name: foo
              enabled: true
            - name: bar
              enabled: false
        selector:
          matchExpressions:
            - key: enabled
              operator: NotIn
              values:
                - "false"
```

Let's now now re-generate the list of applications using the updated values:

```sh
helm template . | argocd appset generate /dev/stdin -o yaml
```

Which should now output:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  finalizers:
  - resources-finalizer.argocd.argoproj.io
  name: foo
spec:
  destination: {}
  project: default
```

Success! :partying_face:

As enabling/disabling applications is core functionality of this chart, we should pull this solution into the chart.

## Implementing a Solution

As this chart controls templating the application set's generators, we can trivially add the post-selector to each generator automatically.

Let's update the application set template in the following way:

```diff title="templates/applicationsets.yaml"
--- templates/applicationsets.yaml
+++ templates/applicationsets.yaml
@@ -18,10 +18,25 @@ spec:
   {{- if ne .applyNestedSelectors nil }}
   applyNestedSelectors: {{ .applyNestedSelectors }}
   {{- end }}
-  {{- if .generatorsObject }}
-  generators: {{- .generatorsObject | values | toYaml | nindent 4 }}
-  {{- else if .generators }}
-  generators: {{- .generators | toYaml | nindent 4 }}
+  {{- $generators := .generators }}
+  {{- with .generatorsObject }}
+    {{- $generators = . | values }}
+  {{- end }}
+  {{- if $generators }}
+  generators:
+    {{- range $generators }}
+    {{- /* Add a match expression to the selector of all generators that filters out disabled applications */}}
+    {{- $_ := set . "selector" (.selector | default dict) }}
+    {{- $matchExpressions := .selector.matchExpressions | default list }}
+    {{- $matchExpression := (dict
+      "key" "enabled"
+      "operator" "NotIn"
+      "values" (list "false")
+    ) }}
+    {{- $matchExpressions = append $matchExpressions $matchExpression }}
+    {{- $_ := set .selector "matchExpressions" $matchExpressions }}
+    - {{ . | toYaml | indent 6 | trim }}
+    {{- end }}
   {{- else }}
   generators: []
   {{- end }}
```

The above diff changes the following things:

1. Similarly to before, if `.generatorsObject` exists its values will be used, otherwise `.generators` will be used
1. Each generator will automatically get a post-selector automatically added that filters out all applications with `enabled=false` set

To test that our change works, let's once again use the following values:

```yaml title="values.yaml"
applicationSets:
  foo:
    template:
      spec:
        project: default
    generators:
      - list:
          elements:
            - name: foo
              enabled: true
            - name: bar
              enabled: false
```

We can then generate the applications using the following command:


```sh
helm template . | argocd appset generate /dev/stdin -o yaml
```

Which should once again output:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  finalizers:
  - resources-finalizer.argocd.argoproj.io
  name: foo
spec:
  destination: {}
  project: default
```
