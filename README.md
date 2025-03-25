# Helicone Helm Chart

This project is licensed under Apache 2.0 with The Commons Clause.

## Getting Started

The Helicone Helm chart deploys a complete Helicone stack including web interface, API, OpenAI proxy, and supporting services.

### Important Notes for Installation

1. **Use values.example.yaml as your starting point**

   - Copy `values.example.yaml` to `values.yaml` to create your configuration
   - The example file is configured with a standard setup that routes all services through a single domain
   - Customize the domain and other settings to match your environment

2. **Ingress Configuration**

   - The main ingress configuration is in the `extraObjects` section at the bottom of the values file
   - This creates a single ingress that routes to different services based on path:
     - `/` - Web interface
     - `/jawn(/|$)(.*)` - Jawn service
     - `/oai(/|$)(.*)` - OpenAI proxy
     - `/api2(/|$)(.*)` - API service
     - `/supabase(/|$)(.*)` - Supabase/Kong
   - You should only need to change the `host` value to your domain

3. **Accessing the Web Interface**

   - Once deployed, the web interface will be accessible at your configured domain
   - No port-forwarding is needed when ingress is properly configured

4. **Understanding the Routing Strategy**

   - All Helicone services are accessed through a single domain with different path prefixes
   - Example URLs for a domain `helicone.example.com`:
     - Web UI: `https://helicone.example.com/`
     - OpenAI Proxy: `https://helicone.example.com/oai/v1/chat/completions`
     - API: `https://helicone.example.com/api2/v1/...`
     - Supabase: `https://helicone.example.com/supabase/`
     - Jawn: `https://helicone.example.com/jawn/`
   - This routing is configured in the `extraObjects` section of the values file
   - Individual service ingress configurations are disabled by default as they're not needed

5. **Supabase Studio Configuration**

   - Supabase Studio can be accessed through the main domain at `/supabase`
   - If you prefer a separate domain for Supabase Studio, you can enable its dedicated ingress:
     ```yaml
     supabase:
       studio:
         ingress:
           enabled: true
           hostname: "studio-your-domain.com"
           annotations:
             kubernetes.io/ingress.class: nginx
             cert-manager.io/cluster-issuer: letsencrypt-prod
           tls: true
     ```
   - This configuration has been tested and works well with cert-manager and TLS

6. **S3 Configuration**

   - Create a bucket in your cloud
   - For GCP you will have to go into the [interoperability section](https://console.cloud.google.com/storage/settings;tab=interoperability) and create an access key
   - Create the required secret:

     ```bash
     # For GCP
     kubectl -n default create secret generic helicone-s3 \
     --from-literal=access_key='' \
     --from-literal=bucket_name='helicone-bucket' \
     --from-literal=endpoint='https://storage.googleapis.com' \
     --from-literal=secret_key=''
     ```

     ```bash
     # For MinIO (example)
     kubectl -n default create secret generic helicone-s3 \
     --from-literal=access_key='minio' \
     --from-literal=bucket_name='request-response-storage' \
     --from-literal=endpoint='http://localhost:9000' \
     --from-literal=secret_key='minioadmin'
     ```

   - Configure CORS for your bucket using the provided `bucketCorsConfig.json` file

## Storage Class Configuration

By default, the Helm chart uses your cluster's default StorageClass for both ClickHouse and PostgreSQL (managed by Supabase). You can override this behavior by specifying storage classes in your values file:

```yaml
# For ClickHouse storage
helicone:
  clickhouse:
    persistence:
      storageClass: "your-clickhouse-storage-class"

# For PostgreSQL (Supabase) storage
supabase:
  postgresql:
    primary:
      persistence:
        storageClass: "your-postgres-storage-class"
  storage:
    persistence:
      storageClass: "your-storage-storage-class"
```

This allows you to use specific storage classes optimized for database workloads or to meet specific requirements for your environment.

## Release Process

Google Cloud's Artifact Registry is used to store the helm chart. The following steps are to be followed to release a new version of the chart. [Google's Documentation](https://cloud.google.com/artifact-registry/docs/helm/store-helm-charts)

### Test the chart

#### Auth

```bash
gcloud auth application-default login
gcloud container clusters get-credentials helicone --location us-west1-b
```

#### If cluster does not exist

1. Create a new GKE cluster with the following command

   ```bash
   gcloud container clusters create helicone \
   --enable-stackdriver-kubernetes \
   --subnetwork default \
   --num-nodes 1 \
   --machine-type e2-standard-8 \
   --zone us-west1-b
   ```

2. Install the chart with the following command

   ```bash
   helm install helicone ./
   ```

3. Connect via K9s and verify the pods are running.

   ```bash
   k9s -n default
   ```

4. Port forward to the following services:

   - web
   - oai
   - api

5. Send a request to oai and api services and verify they are showing in the web.

6. If everything is working as expected, delete the cluster with the following command

   Important: As this is expensive, please remember to delete the cluster after testing.

   ```bash
   gcloud container clusters delete helicone
   ```

#### If cluster exists

1. Increase number of nodes in the cluster

   ```bash
   gcloud container clusters resize helicone --node-pool default-pool --num-nodes [NUM_NODES]
   ```

2. Upgrade the helm chart

   ```bash
   helm upgrade helicone ./ -f values.yaml
   ```

### When done testing

1. Decrease the number of nodes in the cluster

   ```bash
   gcloud container clusters resize helicone --node-pool default-pool --num-nodes 0
   ```

### Release the chart

1. Update the `Chart.yaml` file with the new version number.
2. Package the chart with

   ```bash
   helm package .
   ```

3. Authenticate

   ```bash
   gcloud auth print-access-token | helm registry login -u oauth2accesstoken \
   --password-stdin https://us-central1-docker.pkg.dev
   ```

4. Push the chart to the repository with

   ```bash
   helm push helicone-[VERSION].tgz oci://us-central1-docker.pkg.dev/helicone-416918/helicone-helm
   ```

5. Notify the consumers of the new version.

### Consumer Instructions

1. Auth with gcloud docker

   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

2. Configure helm auth

   ```bash
   gcloud auth application-default print-access-token | helm registry login -u oauth2accesstoken \
   --password-stdin https://us-central1-docker.pkg.dev
   ```

3. Or to impersonate a service account

   ```bash
   gcloud auth application-default print-access-token \
   --impersonate-service-account=SERVICE_ACCOUNT | helm registry login -u oauth2accesstoken \
   --password-stdin https://us-central1-docker.pkg.dev
   ```

4. Pull the chart locally

   ```bash
   helm pull oci://us-central1-docker.pkg.dev/helicone-416918/helicone-helm/helicone \
   --version [VERSION] \
   --untar
   ```

5. To install directly from OCI registry

   ```bash
   helm install helicone oci://us-central1-docker.pkg.dev/helicone-416918/helicone-helm/helicone \
   --version [VERSION]
   ```

6. Add cors for the s3 bucket

   ```bash
   gcloud storage buckets update gs://<BUCKET_NAME> --cors-file=bucketCorsConfig.json
   ```

## Additional GKE Deployment Configuration Steps

The following steps will help you deploy Helicone on Google Kubernetes Engine (GKE):

### 1. Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install \
cert-manager jetstack/cert-manager \
--namespace cert-manager \
--create-namespace \
--set installCRDs=true
```

### 2. Apply production issuer

Create a file named `prod_issuer.yaml` with the following content:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: your-email@example.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
      - http01:
          ingress:
            class: nginx
```

Then apply it:

```bash
kubectl apply -f prod_issuer.yaml
```

### 3. Install Ingress Nginx

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install nginx ingress-nginx/ingress-nginx \
--namespace nginx \
--set rbac.create=true \
--set controller.publishService.enabled=true
```

### 4. Install the Helicone chart

```bash
helm upgrade helicone ./ -f values.yaml --install
```

**Important Note**: Ensure your domain's A record is pointing to the load balancer IP address that is assigned to your ingress.

## Example API Usage

Once your Helicone instance is deployed and accessible, you can use it to proxy and log LLM API calls. Here are example requests:

### Direct OpenAI Proxy

```bash
curl -k -H "Accept: application/json" \
-H "Accept-Encoding: identity" \
-H "Authorization: Bearer YOUR_OPENAI_API_KEY" \
-H "Helicone-Auth: Bearer YOUR_HELICONE_API_KEY" \
-H "Content-Type: application/json" \
https://your-domain.com/oai/v1/chat/completions \
-d '{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "Hello, tell me a short joke"}]
}'
```

### Using Jawn Gateway

Helicone also provides a gateway for more advanced routing and experimentation:

```bash
curl -k -H "Accept: application/json" \
-H "Accept-Encoding: identity" \
-H "Authorization: Bearer YOUR_OPENAI_API_KEY" \
-H "Helicone-Auth: Bearer YOUR_HELICONE_API_KEY" \
-H "Content-Type: application/json" \
https://your-domain.com/jawn/v1/gateway/oai/v1/chat/completions \
-d '{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "Hello, tell me a short joke about programming"}]
}'
```

Key points for making API requests:

- Use the `/jawn/v1/gateway` path prefix for requests through the gateway
- Add `Accept-Encoding: identity` header to prevent binary/compressed responses
