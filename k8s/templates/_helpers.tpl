{{- define "xib.name" -}}xib{{- end }}
{{- define "xib.fullname" -}}{{ printf "%s-xib" .Release.Name | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "xib.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: xib
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end }}
{{- define "xib.image" -}}{{ printf "%s/%s" .Values.xib.imageRegistry .image }}{{- end }}
{{- define "xib.vmUrl" -}}{{ printf "http://%s-metrics:8428" (include "xib.fullname" .) }}{{- end }}

