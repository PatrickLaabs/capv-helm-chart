{{/*
Expand the name of the chart.
*/}}
{{- define "capv-helm-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "capv-helm-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "capv-helm-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common Annotations
*/}}
{{- define "capv-helm-chart.annotations" -}}
{{- if .Values.commonAnnotations }}
{{- toYaml .Values.commonAnnotations }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "capv-helm-chart.labels" -}}
helm.sh/chart: {{ include "capv-helm-chart.chart" . }}
{{ include "capv-helm-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "capv-helm-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "capv-helm-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "capv-helm-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "capv-helm-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the chart kubeadm cluster configuration
*/}}
{{- define "capv-helm-chart.chart.kubeadm.clusterConfiguration" -}}
apiServer:
  certSANs:
    {{- if (.Values.kubernetes.kubeadm.controlPlane.clusterConfiguration.apiServer).certSANs }}
    {{- toYaml .Values.kubernetes.kubeadm.controlPlane.clusterConfiguration.apiServer.certSANs | nindent 4 }}
    {{- end }}
    - {{ .Values.cluster.controlPlaneEndpoint.host }}
  extraArgs:
    cloud-provider: external
    {{- if .Values.kubernetes.additionnalClientCaFile }}
    client-ca-file: /etc/kubernetes/pki/client_ca_full.pem
    {{- end }}
controllerManager:
  extraArgs:
    cloud-provider: external
{{- end }}

{{/*
Create the kubeadm cluster configuration
*/}}
{{- define "capv-helm-chart.kubeadm.clusterConfiguration" -}}
{{- $overrides := fromYaml (include "capv-helm-chart.chart.kubeadm.clusterConfiguration" .) | default (dict ) -}}
{{- toYaml (mergeOverwrite .Values.kubernetes.kubeadm.controlPlane.clusterConfiguration $overrides) -}}
{{- end }}

{{/*
Template for cluster name
*/}}
{{- define "capv-helm-chart.clusterName" -}}
{{- default .Release.Name .Values.cluster.name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Template for a VSphereMachineTemplate
*/}}
{{- define "capv-helm-chart.VSphereMachineTemplate" -}}
template:
  metadata:
    {{- if or (.templateValues.annotations) (include "capv-helm-chart.annotations" .) }}
    annotations:
      {{- if .templateValues.annotations }}
      {{- toYaml .templateValues.annotations | nindent 6 }}
      {{- end }}
      {{- if include "capv-helm-chart.annotations" . }}
      {{- include "capv-helm-chart.annotations" . | nindent 6 }}
      {{- end }}
    {{- end }}
    {{- if .Values.commonLabels }}
    labels: {{ toYaml .Values.commonLabels | nindent 6 }}
    {{- end }}
  spec:
    cloneMode: linkedClone
    datacenter: {{ .Values.vsphere.dataCenter }}
    datastore: {{ .templateValues.dataStore }}
    diskGiB: {{ .templateValues.diskSizeGiB }}
    folder: {{ .templateValues.folder }}
    memoryMiB: {{ .templateValues.memorySizeMiB }}
    network:
      devices:
      - networkName: {{ .Values.vsphere.network }}
        dhcp4: {{ .Values.machines.dhcp4 }}
        {{- if .Values.machines.addressesFromPools.enabled }}
        addressesFromPools: {{ toYaml .Values.machines.addressesFromPools.providers | nindent 8 }}
        {{- end }}
        {{- if .templateValues.ipAddrs }}
          {{- if ne (len .templateValues.ipAddrs) 0 }}
        ipAddrs: {{ toYaml .templateValues.ipAddrs | nindent 8 }}
          {{- end }}
        {{- end }}
        {{- if ne (len .Values.machines.searchDomains) 0 }}
        searchDomains: {{ toYaml .Values.machines.searchDomains | nindent 8 }}
        {{- end }}
        {{- if .Values.machines.gateway }}
        gateway4: {{ .Values.machines.gateway }}
        {{- end }}
        {{- if  ne (len .Values.machines.nameServers) 0 }}
        nameservers: {{ toYaml .Values.machines.nameServers | nindent 8 }}
        {{- end }}
    numCPUs: {{ .templateValues.cpuCount }}
    resourcePool: {{ .templateValues.resourcePool }}
    server: {{ .Values.vsphere.server }}
    storagePolicyName: {{ .templateValues.storagePolicy }}
    template: {{ .templateValues.template }}
    thumbprint: '{{ .Values.vsphere.tlsThumbprint }}'
{{- end }}

{{/*
Create VSphereMachineControlPlaneTemplate name with sha256.
*/}}
{{- define "capv-helm-chart.VSphereMachineTemplateName" -}}
{{- (printf "%s-%s" .templatePrefix (include "capv-helm-chart.VSphereMachineTemplate" . | sha256sum)) | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Template for a KubeadmConfigTemplate
*/}}
{{- define "capv-helm-chart.KubeadmConfigTemplate" -}}
  template:
    spec:
      files:
    {{- if .Values.kubernetes.kubeadm.workers.files }}
      {{- toYaml .Values.kubernetes.kubeadm.workers.files | nindent 6 }}
    {{- end }}
    {{- if .templateValues.files }}
      {{- toYaml .templateValues.files | nindent 6 }}
    {{- end }}
      joinConfiguration:
        nodeRegistration:
          criSocket: {{ .templateValues.criSocket }}
          kubeletExtraArgs:
            cloud-provider: external
            {{- if .Values.kubernetes.kubeadm.commonKubeletExtraArgs }}
            {{- toYaml .Values.kubernetes.kubeadm.commonKubeletExtraArgs | nindent 12 }}
            {{- end }}
            {{- if .templateValues.kubeletExtraArgs }}
            {{- toYaml .templateValues.kubeletExtraArgs | nindent 12 }}
            {{- end }}
          name: '{{`{{ ds.meta_data.hostname }}`}}'
      preKubeadmCommands:
      - hostname "{{`{{ ds.meta_data.hostname }}`}}"
      - echo "::1         ipv6-localhost ipv6-loopback" >/etc/hosts
      - echo "127.0.0.1   localhost" >>/etc/hosts
      - echo "127.0.0.1   {{`{{ ds.meta_data.hostname }}`}}" >>/etc/hosts
      - echo "{{`{{ ds.meta_data.hostname }}`}}" >/etc/hostname
    {{- if .Values.kubernetes.kubeadm.workers.preKubeadmAdditionalCommands }}
      {{- toYaml .Values.kubernetes.kubeadm.workers.preKubeadmAdditionalCommands | nindent 6 }}
    {{- end }}
    {{- if .templateValues.preKubeadmAdditionalCommands }}
      {{- toYaml .templateValues.preKubeadmAdditionalCommands | nindent 6 }}
    {{- end }}
    {{- if or .Values.kubernetes.kubeadm.workers.postKubeadmAdditionalCommands .templateValues.postKubeadmAdditionalCommands }}
      postKubeadmCommands:
      {{- if .Values.kubernetes.kubeadm.workers.postKubeadmAdditionalCommands }}
      {{- toYaml .Values.kubernetes.kubeadm.workers.postKubeadmAdditionalCommands | nindent 6 }}
      {{- end }}
      {{- if .templateValues.postKubeadmAdditionalCommands }}
      {{- toYaml .templateValues.postKubeadmAdditionalCommands | nindent 6 }}
      {{- end }}
    {{- end }}
    {{- if .Values.machines.users }}
      users:
      {{- toYaml .Values.machines.users | nindent 6 }}
    {{- end }}
{{- end }}

{{/*
Create VSphereMachineControlPlaneTemplate name with sha256.
*/}}
{{- define "capv-helm-chart.KubeadmConfigTemplateName" -}}
{{- (printf "%s-%s" .templatePrefix (include "capv-helm-chart.KubeadmConfigTemplate" . | sha256sum)) | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}