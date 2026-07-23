{{- define "xib.name" -}}xib{{- end }}
{{- define "xib.fullname" -}}{{ printf "%s-xib" .Release.Name | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "xib.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: xib
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end }}
{{- define "xib.image" -}}{{ printf "%s/%s" .Values.xib.imageRegistry .image }}{{- end }}

{{- define "xib.trustedCa.enabled" -}}
{{- if or .Values.global.trustedCa.existingConfigMap (and .Values.global.trustedCa.autoDiscover (.Files.Get "custom-ca/ca.crt")) -}}true{{- end -}}
{{- end }}

{{- define "xib.trustedCa.configMapName" -}}
{{- if .Values.global.trustedCa.existingConfigMap -}}
{{- .Values.global.trustedCa.existingConfigMap -}}
{{- else -}}
{{- printf "%s-environment-ca" (include "xib.fullname" .) -}}
{{- end -}}
{{- end }}

{{- define "xib.trustedCa.initContainer" -}}
{{- if eq (include "xib.trustedCa.enabled" .) "true" }}
initContainers:
  - name: build-trusted-ca-bundle
    image: {{ .Values.global.trustedCa.bundleImage | quote }}
    imagePullPolicy: {{ .Values.global.imagePullPolicy }}
    command: [sh, -c]
    args:
      - cat /etc/ssl/certs/ca-certificates.crt /xib-custom-ca/ca.crt > /xib-trust/ca-bundle.crt
    securityContext:
      runAsNonRoot: true
      runAsUser: 65532
      runAsGroup: 65532
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: {drop: [ALL]}
    volumeMounts:
      - {name: xib-custom-ca, mountPath: /xib-custom-ca, readOnly: true}
      - {name: xib-trust, mountPath: /xib-trust}
{{- end }}
{{- end }}

{{- define "xib.trustedCa.env" -}}
{{- if eq (include "xib.trustedCa.enabled" .) "true" }}
- {name: SSL_CERT_FILE, value: /etc/xib/trust/ca-bundle.crt}
- {name: REQUESTS_CA_BUNDLE, value: /etc/xib/trust/ca-bundle.crt}
{{- end }}
{{- end }}

{{- define "xib.trustedCa.volumeMount" -}}
{{- if eq (include "xib.trustedCa.enabled" .) "true" }}
- {name: xib-trust, mountPath: /etc/xib/trust, readOnly: true}
{{- end }}
{{- end }}

{{- define "xib.trustedCa.volumes" -}}
{{- if eq (include "xib.trustedCa.enabled" .) "true" }}
- name: xib-custom-ca
  configMap:
    name: {{ include "xib.trustedCa.configMapName" . }}
    items:
      - {key: {{ .Values.global.trustedCa.key }}, path: ca.crt}
- {name: xib-trust, emptyDir: {}}
{{- end }}
{{- end }}
{{- define "xib.vmUrl" -}}{{ printf "http://%s-metrics:8428" (include "xib.fullname" .) }}{{- end }}

