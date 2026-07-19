{{- with .deletion -}}
  {{- if .cascade -}}
    {{- $finalizers := $.finalizers | default list -}}
    {{- $propagationPolicy := .propagationPolicy | default "foreground" -}}

    {{- with $propagationPolicy -}}
      {{- if eq . "foreground" -}}
        {{- $finalizers = append $finalizers "resources-finalizer.argocd.argoproj.io" -}}
      {{- else if eq . "background" -}}
        {{- $finalizers = append $finalizers "resources-finalizer.argocd.argoproj.io/background" -}}
      {{- else -}}
        {{- fail (printf "Unrecognised deletion propagation policy: '%s'" .) -}}
      {{- end -}}
    {{- end -}}

    {{- $_ := set $ "finalizers" $finalizers -}}
  {{- end -}}
{{- end -}}
