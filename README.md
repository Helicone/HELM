# Helicone Helm Chart

This project is licensed under Apache 2.0 with The Commons Clause.

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
   helm upgrade helicone ./ -f values.example.yaml
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

### Add a new consumer

Add consumer's Google Cloud Service Account to the `Enterprise Consumer` group within the `helicone-416918` project.

The `Enterprise Consumer` group will be scoped to the `Artifact Registry Reader` role.

Or directly add the `Artifact Registry Reader` role to the consumer's service account.

# Secrets

## Create clickhouse secret

If you don't specify, it will create a default user and password.

```bash
kubectl -n default create secret generic helicone-clickhouse \
--from-literal=CLICKHOUSE_USER='default' \
--from-literal=CLICKHOUSE_PASSWORD='default'
```

## Create S3 secret

Create a bucket in your cloud.

For GCP you will have to go into the [interoperability section](https://console.cloud.google.com/storage/settings;tab=interoperability) and create an access key.

For us it was like this...

```bash
kubectl -n default create secret generic helicone-s3 \
--from-literal=access_key='' \
--from-literal=bucket_name='helicone-bucket' \
--from-literal=endpoint='https://storage.googleapis.com' \
--from-literal=secret_key=''
```

```bash
kubectl -n default create secret generic helicone-s3 \
--from-literal=access_key='minio' \
--from-literal=bucket_name='request-response-storage' \
--from-literal=endpoint='http://localhost:9000' \
--from-literal=secret_key='minioadmin'
```

# Additional Ingress & Cert Manager Configuration Steps

values.examples.yaml can be deployed to GKE

1. Install cert-manager

   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update

   helm upgrade --install \
   cert-manager jetstack/cert-manager \
   --namespace cert-manager \
   --create-namespace \
   --set installCRDs=true
   ```

   Apply production issuer

   ```bash
   kubectl apply -f prod_issuer.yaml
   ```

2. Install Ingress Nginx

   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

   helm install nginx ingress-nginx/ingress-nginx --namespace nginx --set rbac.create=true --set controller.publishService.enabled=true
   ```

3. Install the helm chart

   ```bash
   helm upgrade helicone ./ -f values.example.yaml --install
   ```

Note:

- Ensure domain A record is pointing to the load balancer IP
