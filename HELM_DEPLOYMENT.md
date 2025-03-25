# Helicone Deployment Guide

This guide will help you deploy Helicone to a Kubernetes cluster with all the necessary configurations.

## Prerequisites

- Kubernetes cluster (GKE, EKS, AKS, or any other Kubernetes distribution)
- `kubectl` configured to interact with your cluster
- `helm` installed (v3.x recommended)
- Domain name with ability to configure DNS records

## Step 1: Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true
```

## Step 2: Install cert-manager for TLS

```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

# Apply the ClusterIssuer
kubectl apply -f prod_issuer.yaml
```

## Step 3: Configure Storage Class

For GKE (if you're using a different cloud provider, customize accordingly):

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

## Step 4: Set Up S3 Storage (Required)

Create a secret with your S3 credentials:

```bash
kubectl create secret generic helicone-s3 \
  --from-literal=access_key="YOUR_S3_ACCESS_KEY" \
  --from-literal=secret_key="YOUR_S3_SECRET_KEY" \
  --from-literal=bucket_name="YOUR_S3_BUCKET_NAME" \
  --from-literal=endpoint="https://storage.googleapis.com"  # For GCS, adjust for other providers
```

## Step 5: Deploy Helicone

1. Edit the provided `values.yaml` to customize the deployment:
   - Replace the placeholder domain with your actual domain
   - Adjust the `storageClass` to match your provider if not using GKE
2. Deploy using helm:

```bash
helm upgrade --install helicone ./helicone -f values.yaml
```

## Step 6: Configure DNS

Get the load balancer IP:

```bash
kubectl get ingress
```

Configure DNS A records for:

- `your-domain.com` → [Load Balancer IP]
- `studio.your-domain.com` → [Load Balancer IP]

Wait for DNS propagation before proceeding.

## Step 7: Test the Deployment

After DNS propagation is complete, test with:

```bash
curl -X POST https://your-domain.com/jawn/v1/gateway/oai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_OPENAI_API_KEY" \
  -H "Helicone-Auth: Bearer YOUR_HELICONE_API_KEY" \
  -H "Accept-Encoding: identity" \
  -d '{"model": "gpt-3.5-turbo", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Access Your Helicone Services

- **Web Interface**: `https://your-domain.com`
- **Supabase Studio**: `https://studio.your-domain.com`
- **API Endpoint**: `https://your-domain.com/jawn/v1/gateway/oai/v1/chat/completions`

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
```

### Check DNS Resolution

```bash
kubectl run debug-dns --image=tutum/dnsutils --rm -it --restart=Never -- nslookup helicone-kong
```

## Configuration Reference

The default `values.yaml` includes:

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

5. **Routing**
   - The main ingress routes various endpoints to appropriate services
   - All services accessible through the main domain with path-based routing
