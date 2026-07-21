---
name: kubernetes
description: Deploys applications to GKE clusters using Terragrunt and internal Helm charts (helm-templates v0.3.104, helm-system-templates v0.1.17). Use when creating new k8s namespaces, writing terragrunt.hcl configs, configuring sealed secrets, adding network policies, fixing Kyverno policy violations, or troubleshooting deployment issues like secretKeyRef null errors.
---

# Kubernetes Infrastructure Management

Manages Kubernetes cluster deployments using Terragrunt for infrastructure-as-code, custom Helm charts, and GKE-specific configurations.

## Project Structure

```
k8s-clusters/
├── root.hcl                    # Root terragrunt config (state, providers)
├── _global/
│   └── _helm_app_ns.hcl        # Global helm app namespace template
├── _helm_values/
│   ├── helm-templates/         # Application deployment defaults
│   └── helm-system-templates/  # System resource templates
│       ├── network_policies/   # Predefined network policies
│       ├── service_accounts/   # Service account configs
│       └── monitoring/         # Monitoring configs
├── live/
│   └── <cluster-name>/         # e.g., gcp-k8s-xsolla-n8n-prod
│       ├── _cluster.yaml       # Cluster-specific vars
│       └── <namespace>/        # Application namespace
│           ├── _ns.yaml        # Namespace-specific vars
│           ├── terragrunt.hcl  # Terragrunt config
│           ├── values.yaml     # helm-system-templates values (ns-mgmt)
│           └── <app>_values.yaml # helm-templates values (app)
└── scripts/                    # Utility scripts
```

## Cluster Naming Convention

- `gcp-k8s-<project>-<env>` - GKE clusters (e.g., `gcp-k8s-xsolla-n8n-prod`)
- `nl-k8s-<env>` - Netherlands on-prem clusters
- `us-k8s-<env>` - US on-prem clusters

## Creating a New Namespace Deployment

### Step 1: Create Namespace Directory

```bash
mkdir -p live/<cluster-name>/<namespace>
```

### Step 2: Create _ns.yaml (Optional)

```yaml
# live/<cluster>/<namespace>/_ns.yaml
enable_ns_mgmt_release: true
ns_mgmt_release_use_default_values: true
```

### Step 3: Create terragrunt.hcl

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "_helm" {
  path           = "${get_repo_root()}/_global/_helm_app_ns.hcl"
  expose         = true
  merge_strategy = "deep"
}

inputs = {
  releases = {
    ns-mgmt = {
      values = [
        "${get_repo_root()}/_helm_values/helm-system-templates/network_policies/allow_prometheus_operator_monitoring.yaml",
        "${get_repo_root()}/_helm_values/helm-system-templates/network_policies/allow_web.yaml",
        "${get_repo_root()}/_helm_values/helm-system-templates/network_policies/allow_gke_master_subnets.yaml",
        "values.yaml"
      ]
      wait = false
    }
    <app-name> = {
      repository = "oci://registry.srv.local/helm-stable"
      chart      = "helm-templates"
      version    = "0.3.104"
      values = [
        "<app>_values.yaml"
      ]
    }
  }
}
```

### Step 4: Create values.yaml (ns-mgmt release)

```yaml
---
mode: custom
customTemplates:
  - templates.sealedSecrets
  - templates.networkPolicies

networkPolicies:
  allow-<source>:
    name: allow-<source>
    podSelector:
      matchLabels: {}
    ingress:
      <source>-access:
        from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: <source-namespace>

secrets:
  <secretName>:
    name: <k8s-secret-name>
    kind: sealedSecret
    sealedType: "namespace-wide"
    data:
      <key>: <sealed-value>
```

### Step 5: Create Application Values (helm-templates)

```yaml
---
baseDomain: '<cluster>.srv.local'
appName: '<app-name>'
securityContext_enable: true  # REQUIRED for Kyverno compliance
releaseType: current
environment: prod
appVersion: "latest"
appImageName: <registry>/<image>

services:
  http:
    port: "80"
    targetPort: "<app-port>"
    ingress: {}

containers:
  app:
    resources:
      cpu:
        requests: '200m'
        limits: '1000m'
      memory:
        requests: '512M'
        limits: '512M'
    imagePullPolicy: Always
    securityContext:
      runAsNonRoot: true
      runAsUser: 1001
      runAsGroup: 1001
    env:
      - name: '<ENV_VAR>'
        value: '<value>'
      - name: '<SECRET_VAR>'
        valueFrom:
          secretKeyRef:
            name: <secret-name>
            key: <key>
            external_secret: true  # When secret is in ns-mgmt release
    ports:
      - containerPort: '<app-port>'
    livenessProbe:
      httpGet:
        path: /health
        port: '<app-port>'
      initialDelaySeconds: 30
      periodSeconds: 30
    readinessProbe:
      httpGet:
        path: /health
        port: '<app-port>'
      initialDelaySeconds: 5
      periodSeconds: 10
```

## Helm Charts Reference

### helm-templates (Applications)

Chart version: `0.3.104`
Repository: `oci://registry.srv.local/helm-stable`

**Critical flags:**
- `securityContext_enable: true` - REQUIRED to apply runAsUser/runAsGroup
- `external_secret: true` - Use when referencing secrets from different helm release

### helm-system-templates (Namespace Management)

Chart version: `0.1.17`
Repository: `oci://registry.srv.local/helm-stable`

**Templates available:**
- `templates.sealedSecrets` - Sealed secrets management
- `templates.networkPolicies` - Network policy definitions
- `templates.serviceAccounts` - Service account configs
- `templates.configMaps` - ConfigMap management

## Sealed Secrets

### Creating a Sealed Secret

```bash
# Get the public key
kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  > /tmp/sealed-secrets.pem

# Create sealed secret (namespace-wide scope)
echo -n "secret-value" | kubeseal --raw \
  --from-file=/dev/stdin \
  --namespace <namespace> \
  --scope namespace-wide \
  --cert /tmp/sealed-secrets.pem
```

### Using in values.yaml

```yaml
secrets:
  mySecret:
    name: my-secret
    kind: sealedSecret
    sealedType: "namespace-wide"
    data:
      api-key: AgAXkQqg7Jma...  # gitleaks:allow (example sealed value)
```

## Network Policies

### Predefined Policies

Located in `_helm_values/helm-system-templates/network_policies/`:
- `allow_web.yaml` - Allow from ingress-nginx namespaces
- `allow_gke_master_subnets.yaml` - GKE control plane access
- `allow_prometheus_operator_monitoring.yaml` - Prometheus scraping
- `allow_otel_collector.yaml` - OpenTelemetry collector

**CRITICAL:** For namespaces with ingresses, you MUST include `allow_web.yaml` in terragrunt.hcl:
```hcl
ns-mgmt = {
  values = [
    "${get_repo_root()}/_helm_values/helm-system-templates/network_policies/allow_prometheus_operator_monitoring.yaml",
    "${get_repo_root()}/_helm_values/helm-system-templates/network_policies/allow_web.yaml",
    "${get_repo_root()}/_helm_values/helm-system-templates/network_policies/allow_gke_master_subnets.yaml",
    "values.yaml"
  ]
}
```
Without `allow_web.yaml`, the default network policy blocks ALL ingress traffic, causing connection timeouts.

### Custom Network Policy

```yaml
networkPolicies:
  allow-custom:
    name: allow-custom
    podSelector:
      matchLabels: {}
    ingress:
      custom-access:
        from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: source-namespace
```

## Ingress Annotations

### Common Annotations

```yaml
ingresses:
  app_ingress:
    annotations:
      # IP whitelist (comma-separated CIDRs)
      nginx.ingress.kubernetes.io/whitelist-source-range: "185.30.20.0/22,172.16.25.21/32"

      # Permanent redirect (301)
      nginx.ingress.kubernetes.io/permanent-redirect: "https://new-url.example.com"

      # SSL/TLS
      cert-manager.io/issuer: letsencrypt-prod
```

### Cloudflare Tunnel Access

When using Cloudflare Access, external ingress whitelist must include tunnel IPs:
```yaml
nginx.ingress.kubernetes.io/whitelist-source-range: "185.30.20.0/22,172.16.25.21/32,172.16.25.22/32"
```

For internal ingress behind Cloudflare Access (auth handled by CF+Okta), use open whitelist:
```yaml
nginx.ingress.kubernetes.io/whitelist-source-range: "0.0.0.0/0,::/0"
```

## Deployment Commands

### Using Terragrunt (Preferred)

```bash
cd live/<cluster>/<namespace>
terragrunt plan
terragrunt apply
```

### Direct Helm (Workaround for Terraform Provider Bugs)

```bash
# Install
helm install <release> oci://registry.srv.local/helm-stable/helm-templates \
  --version 0.3.104 \
  -f <app>_values.yaml \
  -n <namespace>

# Upgrade
helm upgrade <release> oci://registry.srv.local/helm-stable/helm-templates \
  --version 0.3.104 \
  -f <app>_values.yaml \
  -n <namespace>
```

## Kyverno Policy Requirements

All deployments must satisfy these policies:

### require-run-as-nonroot
```yaml
containers:
  app:
    securityContext:
      runAsNonRoot: true
```

### require-non-root-groups
```yaml
containers:
  app:
    securityContext:
      runAsUser: 1001    # Non-zero
      runAsGroup: 1001   # Non-zero
```

**Important:** Set `securityContext_enable: true` at root level to enable these values.

## Common Issues & Workarounds

### Terraform Helm Provider "Inconsistent Final Plan"

**Cause:** `rolloutEveryDeploy` annotation generates random value on each render.

**Workaround:** Use direct helm commands instead of terragrunt:
```bash
helm upgrade <release> oci://registry.srv.local/helm-stable/helm-templates \
  --version 0.3.104 -f <values>.yaml -n <namespace>
```

### secretKeyRef.name Renders as Null

**Cause:** Secrets defined in ns-mgmt release but referenced from app release.

**Fix:** Add `external_secret: true`:
```yaml
env:
  - name: 'SECRET_VAR'
    valueFrom:
      secretKeyRef:
        name: secret-name
        key: key-name
        external_secret: true
```

### Kyverno Policy Violations (runAsNonRoot/runAsGroup)

**Cause:** Missing `securityContext_enable: true` at root level.

**Fix:**
```yaml
securityContext_enable: true  # Add at root of values file
containers:
  app:
    securityContext:
      runAsNonRoot: true
      runAsUser: 1001
      runAsGroup: 1001
```

### Image Platform Mismatch (arm64 vs amd64)

**Cause:** Image built on M1/M2 Mac defaults to linux/arm64; GKE needs amd64.

**Fix:** Build with explicit platform:
```bash
docker buildx build --platform linux/amd64 -t <image> --push .
```

### Pod Cannot Access Another Namespace

**Cause:** Default network policies block cross-namespace traffic.

**Fix:** Add network policy in values.yaml:
```yaml
networkPolicies:
  allow-<source>:
    name: allow-<source>
    podSelector:
      matchLabels: {}
    ingress:
      <source>-access:
        from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: <source-namespace>
```

### External Ingress Times Out (Connection Timeout)

**Symptom:** TLS handshake succeeds but HTTP request times out.

**Cause:** `default-network-policy` has empty `ingress: {}` rules, blocking nginx ingress traffic.

**Diagnosis:**
```bash
kubectl get networkpolicy default-network-policy -n <namespace> -o yaml
# Check if ingress rules are empty
```

**Fix:** Add `allow_web.yaml` to terragrunt.hcl ns-mgmt values:
```hcl
values = [
  "${get_repo_root()}/_helm_values/helm-system-templates/network_policies/allow_web.yaml",
  ...
]
```

**Quick kubectl fix:**
```bash
kubectl patch networkpolicy default-network-policy -n <namespace> --type=merge \
  -p '{"spec":{"ingress":[{"from":[{"namespaceSelector":{"matchExpressions":[{"key":"namespace","operator":"In","values":["ingress-nginx","ingress-nginx-external"]}]}}]}]}}'
```

## kubectl Quick Reference

```bash
# Switch context
kubectl config use-context <cluster-name>

# Check pods
kubectl get pods -n <namespace>

# View logs
kubectl logs -n <namespace> <pod-name>

# Describe pod (check events)
kubectl describe pod -n <namespace> <pod-name>

# Execute in pod
kubectl exec -n <namespace> <pod-name> -- <command>

# Check service DNS
kubectl exec -n <source-ns> <pod> -- \
  curl http://<service>.<target-ns>.svc.cluster.local:<port>

# List helm releases
helm list -n <namespace>

# Get helm values
helm get values <release> -n <namespace>
```

## GCP Artifact Registry

Images stored in: `us-docker.pkg.dev/<project>/<repo>/<image>`

Example: `us-docker.pkg.dev/xsolla-n8n-prod/n8n-mcp/n8n-mcp:latest`
