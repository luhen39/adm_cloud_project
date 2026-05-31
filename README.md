# Project Dropbox - Cloud File Storage API

**Cloud file storage system with RESTful API**, authentication, rate limiting, object storage (MinIO), and observability stack, fully provisioned on Kubernetes (GKE) using Terraform.

## 1. Prerequisites

* Google Cloud SDK (`gcloud`) installed and authenticated

```bash
gcloud auth login
gcloud config set project <PROJECT_ID>
```

* Terraform ≥ 1.5
* `kubectl` installed
* Docker (to build the API image, generate authentication files, and for local development)
* OpenSSL (for TLS certificates)
* `htpasswd` (for Basic Auth) — can be used via Docker:

```bash
docker run --rm httpd:alpine htpasswd -nb <user> <pass>
```

## 2. Repository Structure

```text
project-dropbox/
├── api/                   # API source code (FastAPI + boto3)
├── k8s/                   # Kubernetes manifests (Deployments, Services, …)
├── terraform/             # Terraform code (network, cluster, iam, … modules)
├── observability/         # Prometheus, Grafana, Loki, Fluent Bit configurations
├── tests/                 # Load testing script (k6)
├── nginx/                 # NGINX configuration, TLS certificates, htpasswd
├── docs/                  # Report and additional documentation
├── docker-compose.yml     # Local Development Environment (Docker Compose)
└── README.md
```

## 3. Initial Setup

### 3.1 Create remote Terraform state bucket

```bash
gsutil mb -l europe-west1 gs://<PROJECT_ID>-tfstate
```

### 3.2 Prepare authentication and TLS files

```bash
# htpasswd (replace USER and PASS)
docker run --rm httpd:alpine htpasswd -nb admin admin123 > nginx/auth/.htpasswd

# Self-signed certificate
openssl req -x509 -newkey rsa:2048 -nodes -keyout nginx/ssl/tls.key -out nginx/ssl/tls.crt -days 365 -subj "/CN=localhost"
```

### 3.3 Create `terraform.tfvars` file

Copy the example and fill in your values:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

**Minimum content of `terraform.tfvars`:**

```hcl
project_id          = "<PROJECT_ID>"
region              = "europe-west1"
zone                = "europe-west1-b"
minio_root_user     = "minioadmin"
minio_root_password = "<STRONG_PASSWORD>"
minio_api_user      = "apiuser"
minio_api_password  = "<STRONG_PASSWORD>"
jwt_secret          = "<JWT_SECRET>"
auth_users          = "admin:admin123,user1:password1,user2:password2"
# OAuth2-Proxy (optional)
oauth_client_id     = "<GOOGLE_CLIENT_ID>"
oauth_client_secret = "<GOOGLE_CLIENT_SECRET>"
oauth_cookie_secret = "<COOKIE_SECRET>"
```

> **Note:** Credentials should never be committed to the repository. The `terraform.tfvars` file is listed in `.gitignore`.

## 4. Deployment with Terraform

The deployment is done in three phases to resolve resource dependencies.

### 4.1 Initialize Terraform

```bash
cd terraform
terraform init
```

### 4.2 Phase 1 — Base infrastructure + Secrets

```bash
terraform apply -target=module.network \
  -target=module.cluster \
  -target=module.iam \
  -target=module.storage \
  -target=kubernetes_secret.minio_secrets \
  -target=kubernetes_secret.api_secrets \
  -target=kubernetes_secret.nginx_htpasswd \
  -target=kubernetes_secret.nginx_tls \
  -target=kubernetes_secret.oauth_secrets \
  -auto-approve
```

Get cluster credentials:

```bash
gcloud container clusters get-credentials project-dropbox-cluster --zone europe-west1-b
```

### 4.3 Phase 2 — MinIO and Initialization Job

```bash
terraform apply \
  -target=kubernetes_manifest.minio_service \
  -target=kubernetes_manifest.minio_deployment \
  -target=kubernetes_manifest.minio_pvc \
  -target=kubernetes_job_v1.minio_init \
  -auto-approve
```

Wait for MinIO external IP:

```bash
until kubectl get svc minio-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q '.'; do
  sleep 10
done
echo "MinIO IP: $(kubectl get svc minio-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

### 4.4 Phase 3 — API, NGINX, HPA, Observability, and K6 Load Test Script

```bash
terraform apply -auto-approve
```

## 5. Post-Deployment Validation

### 5.1 Check resources

```bash
kubectl get nodes
kubectl get pods
kubectl get hpa
kubectl get pvc
kubectl get networkpolicy
```

### 5.2 Test the API

```bash
IP=$(kubectl get svc nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
DOMAIN="${IP}.nip.io"

# Health check
curl -k https://$DOMAIN/health

# Login and get JWT token
TOKEN=$(curl -k -s -X POST https://$DOMAIN/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | jq -r .access_token)

# Upload file with Basic Auth
echo "Hello Dropbox" > /tmp/test.txt
curl -k -u admin:admin123 -X POST https://$DOMAIN/files/upload \
  -F "file=@/tmp/test.txt"

# List files (Basic Auth)
curl -k -u admin:admin123 https://$DOMAIN/files

# List files with JWT
curl -k -H "Authorization: Bearer $TOKEN" https://$DOMAIN/files
```

### 5.3 Check Observability Stack

```bash
# Prometheus targets
kubectl port-forward svc/prometheus-service 9090:9090 &

# Grafana
kubectl port-forward svc/grafana-service 3000:3000 &
echo "Access http://localhost:3000 and check the 'Cloud Storage Dashboard'"

# Loki + Fluent Bit
kubectl port-forward svc/loki-service 3100:3100 &
```

### 5.4 Complete Tests Per Task

#### Task 1 — Terraform
```bash
kubectl get nodes
kubectl get pods
kubectl get hpa
kubectl get pvc
kubectl get networkpolicy
kubectl get serviceaccounts
```

#### Task 2 — NGINX (SSL, Auth, Rate Limit)
```bash
DOMAIN="${IP}.nip.io"

# SSL + redirect HTTP→HTTPS
curl -k -v http://$DOMAIN/health 2>&1 | grep "301"

# Basic Auth
curl -k https://$DOMAIN/files                          # 302 (OAuth) or 401
curl -k -u admin:admin123 https://$DOMAIN/files        # 200
curl -k -u admin:wrong https://$DOMAIN/files            # 401

# JWT
TOKEN=$(curl -k -s -X POST https://$DOMAIN/auth/login -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' | jq -r .access_token)
curl -k -H "Authorization: Bearer $TOKEN" https://$DOMAIN/files   # 200
curl -k -H "Authorization: Bearer invalid" https://$DOMAIN/files  # 401

# Rate limit
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  sh -c 'echo "test" > /tmp/f; for i in $(seq 1 15); do
    curl -k -s -o /dev/null -w "%{http_code}\n" -u admin:admin123 \
      -X POST https://nginx-service/files/upload -F "file=@/tmp/f"
  done'

# NGINX Metrics
kubectl port-forward svc/nginx-service 9113:9113 & sleep 2
curl http://localhost:9113/metrics | grep nginx_http_requests_total
kill %1
```
#### OAuth2-Proxy (Google)
```bash
# Browser Test (redirection to Google)
echo "Open on Browser: https://${IP}.nip.io/files"
echo "Should redirect to Google → login → come back and show files"

# Session Cookie Test (via curl)
# 1. Log in to browser at https://${IP}.nip.io/files
# 2. F12 → Application → Cookies → copy _oauth2_proxy cookie value
# 3. Use the cookie in curl:
curl -k -H 'Cookie: _oauth2_proxy=<_OAUTH2_PROXY COOKIE VALUE>' https://${IP}.nip.io/files

# Upload via OAuth
echo "oauth upload" > /tmp/oauth.txt
curl -k -H 'Cookie: _oauth2_proxy=<_OAUTH2_PROXY COOKIE VALUE>' \
  -X POST https://${IP}.nip.io/files/upload \
  -F "file=@/tmp/oauth.txt"
```
> **Note:** Don´t forget to replace <_OAUTH2_PROXY COOKIE VALUE> by the actual cookie value!

#### Task 3 - API + MinIO

```bash
# Upload
echo "test" > /tmp/t.txt
FILE_ID=$(curl -k -s -u admin:admin123 -X POST https://$DOMAIN/files/upload -F "file=@/tmp/t.txt" | jq -r .file_id)

# Listar
curl -k -u admin:admin123 https://$DOMAIN/files

# Download
curl -k -u admin:admin123 https://$DOMAIN/files/$FILE_ID -o /tmp/down.txt && cat /tmp/down.txt

# Metadados
curl -k -u admin:admin123 https://$DOMAIN/files/$FILE_ID/meta

# Share (presigned URL)
curl -k -u admin:admin123 -X POST https://$DOMAIN/files/$FILE_ID/share \
  -H "Content-Type: application/json" -d '{"ttl_seconds":3600}'

# Delete
curl -k -u admin:admin123 -X DELETE https://$DOMAIN/files/$FILE_ID

# API Metrics
kubectl port-forward svc/api-service 8000:8000 & sleep 2
curl http://localhost:8000/metrics | grep -E "http_requests_total|file_upload"
kill %1
```

#### Task 4 - Observability

```bash
# Prometheus targets
kubectl port-forward svc/prometheus-service 9090:9090 & sleep 2
curl -s http://localhost:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
kill %1

# Grafana dashboard
kubectl port-forward svc/grafana-service 3000:3000 &
echo "Open http://localhost:3000 anc verify 7 panels"

# Loki + logs
kubectl port-forward svc/loki-service 3100:3100 & sleep 2
curl http://localhost:3100/ready
curl -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="fluentbit"}' \
  --data-urlencode 'limit=5' | jq '.data.result | length'
kill %1 %2

# Alerting rules
kubectl port-forward svc/prometheus-service 9090:9090 & sleep 2
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[].name'
kill %1
```
#### Task 5 - K6 Load Test

```bash
kubectl apply -f k8s/k6-configmap.yaml
kubectl apply -f k8s/k6-job.yaml
kubectl logs job/k6-load-test -f

# See HPA in another terminal
kubectl get hpa -w
```

## 6. Load Testing (k6) — Task 5

```bash
# Create the Job
kubectl apply -f k8s/k6-job.yaml

# Follow logs
kubectl logs job/k6-load-test -f
```

To force HPA scaling during the test, temporarily lower the CPU target:

```bash
kubectl patch hpa project-dropbox-api-hpa --patch \
  '{"spec":{"metrics":[{"type":"Resource","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":2}}}]}}'
```

Restore the original value (60%) after the test:

```bash
kubectl patch hpa project-dropbox-api-hpa --patch \
  '{"spec":{"metrics":[{"type":"Resource","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":60}}}]}}'
```

## 7. Destroy Environment

```bash
cd terraform
terraform destroy -auto-approve
```

## 8. Additional Notes

* **OAuth2-Proxy**: To use Google authentication, create OAuth 2.0 credentials in the Google Cloud Console and configure `oauth_client_id`, `oauth_client_secret`, and `oauth_cookie_secret` in `terraform.tfvars`.
* **TLS Certificates**: Self-signed certificates are used in development. For production, it is recommended to use `cert-manager` with Let's Encrypt.
* **Persistence**: MinIO uses a 20 GiB PVC. Data survives pod restarts.
* **Rate Limiting**: Upload: 10 req/min (burst=5), Download: 60 req/min (burst=10). Adjustable in `nginx.conf`.
* **Logging**: Fluent Bit is used instead of Promtail due to GKE limitations. Logs are sent to Loki and can be viewed in Grafana.
* **API Metrics**: Exported via `prometheus-fastapi-instrumentator`, including latency histograms and upload size metrics.
* **HPA**: Default target is 60% CPU. Temporarily reduced to 2% during load testing to demonstrate scaling.

---

For more details, please consult the report in the `docs/` folder.

## Group Members
- Diogo Leandro: up202005034
- Luís Ganço: up202004196
