# Helicone Helm Chart Documentation

This documentation provides comprehensive guidance for deploying and configuring Helicone using Kubernetes and Helm.

## Overview

The Helicone Helm chart deploys a complete Helicone stack including:

- Web interface for monitoring and analytics
- API service for programmatic access
- OpenAI proxy for request interception and logging
- Supabase Studio for database management
- Supporting services (Clickhouse, PostgreSQL, Kong, etc.)

This project is licensed under Apache 2.0 with The Commons Clause.

## Prerequisites

Before deploying Helicone, ensure you have:

- Kubernetes cluster (GKE, EKS, AKS, or any other Kubernetes distribution)
- `kubectl` configured to interact with your cluster
- `helm` (v3.x recommended) installed locally
- Domain name with ability to configure DNS records
- S3-compatible storage (GCS, AWS S3, MinIO, etc.) for request/response body storage

## Deployment Process

### Step 1: Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true
```

### Step 2: Install cert-manager for TLS

```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Apply the production ClusterIssuer
kubectl apply -f prod_issuer.yaml
```

### Step 3: Configure Storage Class

For GKE (customize for your cloud provider):

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-rwo
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: none
volumeBindingMode: WaitForFirstConsumer
EOF
```

### Step 4: Set Up S3 Storage

Create a bucket in your cloud provider and configure CORS (use the provided `bucketCorsConfig.json` file).

For Google Cloud Storage:

1. Go to the [interoperability section](https://console.cloud.google.com/storage/settings;tab=interoperability)
2. Create access keys
3. Create the required Kubernetes secret:

```bash
kubectl create secret generic helicone-s3 \
  --from-literal=access_key="YOUR_S3_ACCESS_KEY" \
  --from-literal=secret_key="YOUR_S3_SECRET_KEY" \
  --from-literal=bucket_name="YOUR_S3_BUCKET_NAME" \
  --from-literal=endpoint="https://storage.googleapis.com"
```

For AWS S3:

```bash
kubectl create secret generic helicone-s3 \
  --from-literal=access_key="YOUR_AWS_ACCESS_KEY" \
  --from-literal=secret_key="YOUR_AWS_SECRET_KEY" \
  --from-literal=bucket_name="YOUR_S3_BUCKET_NAME" \
  --from-literal=endpoint="https://s3.amazonaws.com"
```

For MinIO:

```bash
kubectl create secret generic helicone-s3 \
  --from-literal=access_key="minio" \
  --from-literal=bucket_name="request-response-storage" \
  --from-literal=endpoint="http://localhost:9000" \
  --from-literal=secret_key="minioadmin"
```

### Step 5: Configure ClickHouse (Optional)

If you want to customize ClickHouse credentials (defaults will be used if not specified):

```bash
kubectl create secret generic helicone-clickhouse \
  --from-literal=user="default" \
  --from-literal=password="your-secure-password"
```

### Step 6: Configure Values File

1. Copy the provided `values-ready.yaml` to your own `values.yaml`:

   ```bash
   cp values-ready.yaml values.yaml
   ```

2. Customize the values file:
   - Replace all instances of `yourdomain.com` with your actual domain
   - Adjust storage class settings based on your cloud provider
   - Review and adjust resource limits if needed
   - Set `S3_ENABLED: "true"` in the globalEnvVars section

### Step 7: Deploy Helicone

```bash
helm upgrade --install helicone ./helicone -f values.yaml
```

### Step 8: Configure DNS

Get the load balancer IP:

```bash
kubectl get ingress
```

Configure DNS A records:

- `yourdomain.com` → [Load Balancer IP]
- `studio.yourdomain.com` → [Load Balancer IP]

Wait for DNS propagation before proceeding (may take 5 minutes to several hours depending on your DNS provider).

### Step 9: Test the Deployment

After DNS propagation completes, test with:

```bash
curl -X POST https://yourdomain.com/jawn/v1/gateway/oai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_OPENAI_API_KEY" \
  -H "Helicone-Auth: Bearer YOUR_HELICONE_API_KEY" \
  -H "Accept-Encoding: identity" \
  -d '{"model": "gpt-3.5-turbo", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Configuration Details

### Understanding the Routing Strategy

All Helicone services are accessed through a single domain with different path prefixes:

- Web UI: `https://yourdomain.com/`
- Jawn Gateway: `https://yourdomain.com/jawn/v1/gateway/oai/v1/chat/completions`
- OpenAI Proxy: `https://yourdomain.com/oai/v1/chat/completions`
- API: `https://yourdomain.com/api2/v1/...`
- Supabase: `https://yourdomain.com/supabase/`

This routing is configured in the `extraObjects` section of the values file. Individual service ingress configurations are disabled by default as they're not needed.

### Supabase Studio Configuration

Supabase Studio can be accessed in two ways:

1. Through the main domain at `/supabase`
2. Through a dedicated subdomain `studio.yourdomain.com` (configured in the values.yaml)

## Troubleshooting

### Check Pods Status

```bash
kubectl get pods
```

### View Service Logs

```bash
# Web service
kubectl logs $(kubectl get pod -l app.kubernetes.io/name=helicone-web -o name | head -1)

# Jawn service (gateway)
kubectl logs $(kubectl get pod -l app.kubernetes.io/name=helicone-jawn -o name | head -1)

# OpenAI proxy
kubectl logs $(kubectl get pod -l app.kubernetes.io/name=helicone-oai -o name | head -1)
```

### Test DNS Resolution

```bash
kubectl run debug-dns --image=tutum/dnsutils --rm -it --restart=Never -- nslookup helicone-kong
```

### Check Ingress Configuration

```bash
kubectl get ingress -o yaml
```

### Check Service Endpoints

```bash
kubectl get endpoints
```

## Maintenance

### Upgrading Helicone

To update your deployment with new settings:

```bash
helm upgrade helicone ./helicone -f values.yaml
```

### Uninstalling Helicone

```bash
helm uninstall helicone
```

## Advanced Topics

### Release Process for Chart Maintainers

If you are maintaining and releasing the Helicone Helm chart, follow these steps:

1. Update the `Chart.yaml` file with the new version number
2. Package the chart:
   ```bash
   helm package .
   ```
3. Authenticate with your registry:
   ```bash
   gcloud auth print-access-token | helm registry login -u oauth2accesstoken \
   --password-stdin https://us-central1-docker.pkg.dev
   ```
4. Push the chart:
   ```bash
   helm push helicone-[VERSION].tgz oci://us-central1-docker.pkg.dev/helicone-416918/helicone-helm
   ```

### Consumer Instructions for OCI Registry

For users installing from the OCI registry:

1. Authenticate with Google Cloud:

   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

2. Configure Helm authentication:

   ```bash
   gcloud auth print-access-token | helm registry login -u oauth2accesstoken \
   --password-stdin https://us-central1-docker.pkg.dev
   ```

3. Pull the chart locally:

   ```bash
   helm pull oci://us-central1-docker.pkg.dev/helicone-416918/helicone-helm/helicone \
   --version [VERSION] \
   --untar
   ```

4. Install directly from OCI registry:
   ```bash
   helm install helicone oci://us-central1-docker.pkg.dev/helicone-416918/helicone-helm/helicone \
   --version [VERSION]
   ```

## Appendix: Chart Structure

The Helicone Helm chart includes the following main components:

1. **Global Settings**

   - Storage class configuration
   - S3 storage enablement

2. **Web Frontend**

   - Public URL configuration
   - Ingress setup with TLS

3. **API Services**

   - OpenAI proxy (oai)
   - Helicone API
   - Jawn gateway service

4. **Database Components**

   - Clickhouse for analytics
   - PostgreSQL via Supabase
   - Studio interface for database management

5. **Ingress**
   - Main ingress with path-based routing
   - Optional separate ingress for Studio
