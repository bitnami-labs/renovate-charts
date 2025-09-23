# Setup Guide

This guide provides step-by-step instructions for setting up the GitOps PoC environment.

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# macOS (using Homebrew)
brew install kind helm kubectl yq jq

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y kind helm kubectl yq jq

# Windows (using Chocolatey)
choco install kind kubernetes-helm kubernetes-cli yq jq
```

### Verify Installation

```bash
# Check versions
kind version
helm version
kubectl version --client
yq --version
jq --version
```

## Step 1: Create Kubernetes Cluster

### Option 1: Using Kind (Recommended)

```bash
# Create kind cluster with the provided configuration
kind create cluster --config kind-config.yaml

# Verify cluster is running
kubectl cluster-info --context kind-gitops-poc
```

### Option 2: Using k3d

```bash
# Create k3d cluster
k3d cluster create gitops-poc \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --port "8080:8080@loadbalancer" \
  --wait

# Verify cluster is running
kubectl cluster-info --context k3d-gitops-poc
```

### Option 3: Using Docker Desktop

1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Enable Kubernetes
4. Click "Apply & Restart"

## Step 2: Install ArgoCD

### Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server \\
  -n argocd

# Note: Using OCI charts directly - no helm repo setup needed
```

### Access ArgoCD UI

```bash
# Port forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \\
  -o jsonpath="{.data.password}" | base64 -d && echo
```

**Access ArgoCD:**

- URL: <https://localhost:8080>
- Username: `admin`
- Password: (from the command above)

### Install ArgoCD CLI (Optional)

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login to ArgoCD
argocd login localhost:8080 --username admin --password <password>
```

## Step 3: Install Ingress Controller (Optional)

If you want to access applications via ingress:

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## Step 4: Deploy Applications

### Method 1: Using ArgoCD CLI

```bash
# Note: Using OCI charts directly - no helm repo setup needed

# Apply the app-of-apps pattern
kubectl apply -f argocd-applications/app-of-apps.yaml

# Or apply individual applications
kubectl apply -f argocd-applications/
```

### Method 2: Using ArgoCD UI

1. Open ArgoCD UI at <https://localhost:8080>
2. Click "New App"
3. Fill in the application details:
   - **Application Name**: `app-of-apps`
   - **Project**: `default`
   - **Sync Policy**: `Automatic`
   - **Repository URL**: `https://github.com/your-org/renovate-charts`
   - **Path**: `argocd-applications`
   - **Cluster URL**: `https://kubernetes.default.svc`
   - **Namespace**: `argocd`
4. Click "Create"

### Verify Deployments

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check application pods
kubectl get pods -n app-postgresql
kubectl get pods -n app-mongodb
kubectl get pods -n app-redis

# Check application services
kubectl get svc -n app-postgresql
kubectl get svc -n app-mongodb
kubectl get svc -n app-redis
```

## Step 5: Configure GitHub Repository

### Create GitHub Repository

1. Create a new repository on GitHub (e.g., `your-org/renovate-charts`)
2. Push this project to the repository:

```bash
# Initialize git repository
git init
git add .
git commit -m "Initial commit: GitOps PoC setup"

# Add remote origin (replace with your repository URL)
git remote add origin https://github.com/your-org/renovate-charts.git
git branch -M main
git push -u origin main
```

### Update ArgoCD Applications

Update the repository URL in the ArgoCD applications:

```bash
# Update repository URL in all application files
REPO_URL="https://github.com/your-org/renovate-charts"
sed -i "s|$REPO_URL|$REPO_URL|g" argocd-applications/*.yaml

# Commit and push changes
git add argocd-applications/
git commit -m "Update repository URL"
git push
```

## Step 6: Configure Renovate Bot

### Enable Renovate Bot

1. Go to your GitHub repository
2. Click on "Settings" → "Integrations & services"
3. Search for "Renovate" and install it
4. Renovate will automatically create a configuration PR

### Verify Renovate Configuration

```bash
# Check if renovate.json is valid
jq empty .github/renovate.json

# Test Renovate configuration
npx renovate-config-validator .github/renovate.json
```

## Step 7: Test the Workflow

### Test Application Deployment

1. Check ArgoCD UI to ensure all applications are healthy
2. Verify applications are accessible:

```bash
# Test PostgreSQL connection
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --namespace app-postgresql \
  --image docker.io/bitnami/postgresql:15 \
  --env="PGPASSWORD=apppass123" \
  --command -- psql --host postgresql -U appuser -d appdb -p 5432

# Test Redis connection
kubectl run redis-client --rm --tty -i --restart='Never' \
  --namespace app-redis \
  --image docker.io/bitnami/redis:7 \
  --command -- redis-cli -h redis -a redispass123

```

### Test Renovate Bot

1. Wait for Renovate to create its first PR
2. Review the PR and merge it
3. Verify ArgoCD syncs the changes

## Troubleshooting

### Common Issues

1. **ArgoCD not accessible**

   ```bash
   # Check ArgoCD pods
   kubectl get pods -n argocd

   # Check ArgoCD logs
   kubectl logs -n argocd deployment/argocd-server
   ```

2. **Applications not syncing**

   ```bash
   # Check application status
   kubectl describe application <app-name> -n argocd

   # Force sync
   argocd app sync <app-name>
   ```

3. **Helm chart not found**

   ```bash
   # Note: Using OCI charts directly - no helm repo operations needed

   # Check chart availability
   helm search repo bitnami/postgresql --versions
   ```

### Cleanup

```bash
# Delete kind cluster
kind delete cluster --name gitops-poc

# Or delete k3d cluster
k3d cluster delete gitops-poc
```

## Next Steps

1. **Monitor Applications**: Use ArgoCD UI to monitor application health
2. **Test Updates**: Wait for Renovate to propose chart updates
3. **Customize Configuration**: Modify Helm values as needed
4. **Add More Applications**: Extend the setup with additional charts
5. **Production Considerations**: Review security and scalability requirements

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Renovate Bot Documentation](https://docs.renovatebot.com/)
- [Bitnami Helm Charts](https://github.com/bitnami/charts)
