# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the GitOps PoC setup.

## Common Issues

### 1. ArgoCD Issues

#### ArgoCD Server Not Accessible

**Symptoms:**

- Cannot access ArgoCD UI at <https://localhost:8080>
- Port forward fails
- Connection refused errors

**Diagnosis:**

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD service
kubectl get svc -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
```

**Solutions:**

```bash
# Restart ArgoCD server
kubectl rollout restart deployment/argocd-server -n argocd

# Check if port is already in use
lsof -i :8080

# Use different port
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

#### ArgoCD Applications Not Syncing

**Symptoms:**

- Applications show "OutOfSync" status
- Applications stuck in "Progressing" state
- Sync failures in ArgoCD UI

**Diagnosis:**

```bash
# Check application status
kubectl get applications -n argocd

# Describe specific application
kubectl describe application postgresql -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

**Solutions:**

```bash
# Force sync application
argocd app sync postgresql

# Refresh application
argocd app get postgresql --refresh

# Check repository connectivity
argocd repo get https://github.com/your-org/renovate-charts
```

#### ArgoCD Repository Connection Issues

**Symptoms:**

- Repository shows "Unknown" status
- Cannot fetch application manifests
- Authentication errors

**Diagnosis:**

```bash
# Check repository status
argocd repo list

# Test repository access
argocd repo get https://github.com/your-org/renovate-charts
```

**Solutions:**

```bash
# Add repository with credentials (if private)
argocd repo add https://github.com/your-org/renovate-charts \
  --username <username> \
  --password <token>

# Update repository
argocd repo update https://github.com/your-org/renovate-charts
```

### 2. Kubernetes Cluster Issues

#### Cluster Not Accessible

**Symptoms:**

- `kubectl` commands fail
- "connection refused" errors
- Context not found

**Diagnosis:**

```bash
# Check cluster status
kubectl cluster-info

# Check current context
kubectl config current-context

# List available contexts
kubectl config get-contexts
```

**Solutions:**

```bash
# For kind cluster
kind get clusters
kubectl config use-context kind-gitops-poc

# For k3d cluster
k3d cluster list
kubectl config use-context k3d-gitops-poc

# For Docker Desktop
kubectl config use-context docker-desktop
```

#### Pods Not Starting

**Symptoms:**

- Pods stuck in "Pending" state
- Pods in "CrashLoopBackOff" state
- Image pull errors

**Diagnosis:**

```bash
# Check pod status
kubectl get pods -n app-postgresql

# Describe pod for details
kubectl describe pod <pod-name> -n app-postgresql

# Check pod logs
kubectl logs <pod-name> -n app-postgresql
```

**Solutions:**

```bash
# Check node resources
kubectl describe nodes

# Check storage classes
kubectl get storageclass

# Check persistent volume claims
kubectl get pvc -n app-postgresql
```

### 3. Helm Chart Issues

#### Chart Not Found

**Symptoms:**

- "chart not found" errors
- ArgoCD sync failures
- Helm repository errors

**Diagnosis:**

```bash
   # Note: Using OCI charts directly - no helm repo operations needed

# Search for chart
helm search repo bitnami/postgresql --versions
```

**Solutions:**

```bash
   # Note: Using OCI charts directly - no helm repo operations needed

# Check chart availability
helm search repo bitnami/postgresql --versions | head -10
```

#### Chart Version Issues

**Symptoms:**

- "version not found" errors
- ArgoCD shows "Unknown" chart version
- Sync failures

**Diagnosis:**

```bash
# Check available versions
helm search repo bitnami/postgresql --versions

# Check current version in application
yq eval '.spec.source.targetRevision' argocd-applications/postgresql.yaml
```

**Solutions:**

```bash
# Update to latest version
helm search repo bitnami/postgresql --versions | head -1

# Update application manifest
yq eval '.spec.source.targetRevision = "12.15.0"' -i argocd-applications/postgresql.yaml
```

### 4. Application-Specific Issues

#### PostgreSQL Connection Issues

**Symptoms:**

- Cannot connect to PostgreSQL
- Authentication failures
- Connection timeouts

**Diagnosis:**

```bash
# Check PostgreSQL pod
kubectl get pods -n app-postgresql

# Check PostgreSQL service
kubectl get svc -n app-postgresql

# Test connection
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --namespace app-postgresql \
  --image docker.io/bitnami/postgresql:15 \
  --env="PGPASSWORD=apppass123" \
  --command -- psql --host postgresql -U appuser -d appdb -p 5432
```

**Solutions:**

```bash
# Check password in application configuration
kubectl get secret postgresql -n app-postgresql \
  -o jsonpath='{.data.postgres-password}' | base64 -d

# Restart PostgreSQL
kubectl rollout restart deployment/postgresql -n app-postgresql

# Check logs
kubectl logs -n app-postgresql deployment/postgresql
```

#### MongoDB Connection Issues

**Symptoms:**

- Cannot connect to MongoDB
- Authentication failures
- Connection refused

**Diagnosis:**

```bash
# Check MongoDB pod
kubectl get pods -n app-mongodb

# Check MongoDB service
kubectl get svc -n app-mongodb

# Test connection
kubectl run mongodb-client --rm --tty -i --restart='Never' \
  --namespace app-mongodb \
  --image docker.io/bitnami/mongodb:7 \
  --env="MONGODB_ROOT_PASSWORD=rootpass123" \
  --command -- mongosh --host mongodb -u root -p rootpass123
```

**Solutions:**

```bash
# Check password in application configuration
kubectl get secret mongodb -n app-mongodb \
  -o jsonpath='{.data.mongodb-root-password}' | base64 -d

# Restart MongoDB
kubectl rollout restart deployment/mongodb -n app-mongodb

# Check logs
kubectl logs -n app-mongodb deployment/mongodb
```

#### Redis Connection Issues

**Symptoms:**

- Cannot connect to Redis
- Authentication failures
- Connection timeouts

**Diagnosis:**

```bash
# Check Redis pod
kubectl get pods -n app-redis

# Check Redis service
kubectl get svc -n app-redis

# Test connection
kubectl run redis-client --rm --tty -i --restart='Never' \
  --namespace app-redis \
  --image docker.io/bitnami/redis:7 \
  --command -- redis-cli -h redis -a redispass123
```

**Solutions:**

```bash
# Check password in application configuration
kubectl get secret redis -n app-redis \
  -o jsonpath='{.data.redis-password}' | base64 -d

# Restart Redis
kubectl rollout restart deployment/redis -n app-redis

# Check logs
kubectl logs -n app-redis deployment/redis
```

### 5. Renovate Bot Issues

#### Renovate Not Creating PRs

**Symptoms:**

- No PRs from Renovate Bot
- Renovate dashboard shows no updates
- Configuration errors

**Diagnosis:**

```bash
# Check Renovate configuration
jq empty .github/renovate.json

# Check repository settings
# Go to GitHub repository → Settings → Integrations & services
```

**Solutions:**

```bash
# Validate Renovate configuration
npx renovate-config-validator .github/renovate.json

# Check Renovate logs
# Go to GitHub repository → Actions → Renovate
```

#### Renovate PR Validation Failures

**Symptoms:**

- Renovate PRs fail validation
- GitHub Actions fail
- Auto-merge not working

**Diagnosis:**

```bash
# Check GitHub Actions logs
# Go to GitHub repository → Actions

# Check PR validation
# Look at the "Renovate PR Validation" workflow
```

**Solutions:**

```bash
# Check Helm chart versions
helm search repo bitnami/postgresql --versions

# Update chart versions manually
yq eval '.spec.source.targetRevision = "12.15.0"' -i argocd-applications/postgresql.yaml

# Commit and push changes
git add argocd-applications/
git commit -m "Update chart versions"
git push
```

### 6. GitHub Actions Issues

#### Workflow Failures

**Symptoms:**

- GitHub Actions fail
- Validation errors
- Permission issues

**Diagnosis:**

```bash
# Check workflow logs
# Go to GitHub repository → Actions

# Check workflow syntax
# Validate YAML syntax
```

**Solutions:**

```bash
# Check workflow permissions
# Go to GitHub repository → Settings → Actions → General

# Update workflow files
# Fix syntax errors
# Update action versions
```

#### Permission Issues

**Symptoms:**

- "Permission denied" errors
- Cannot access secrets
- Workflow fails on push

**Diagnosis:**

```bash
# Check repository permissions
# Go to GitHub repository → Settings → Actions → General

# Check branch protection rules
# Go to GitHub repository → Settings → Branches
```

**Solutions:**

```bash
# Update workflow permissions
# Add required permissions to workflow files

# Check branch protection
# Ensure required status checks are configured
```

## Debugging Commands

### General Debugging

```bash
# Check cluster status
kubectl cluster-info

# Check all namespaces
kubectl get namespaces

# Check all pods
kubectl get pods --all-namespaces

# Check all services
kubectl get svc --all-namespaces

# Check all applications
kubectl get applications --all-namespaces
```

### ArgoCD Debugging

```bash
# Check ArgoCD status
kubectl get pods -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-application-controller

# Check ArgoCD configuration
kubectl get configmap -n argocd
kubectl get secret -n argocd
```

### Application Debugging

```bash
# Check application status
kubectl get applications -n argocd

# Describe application
kubectl describe application <app-name> -n argocd

# Check application events
kubectl get events -n argocd --field-selector involvedObject.name=<app-name>
```

### Resource Debugging

```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check storage
kubectl get pv
kubectl get pvc --all-namespaces

# Check network
kubectl get ingress --all-namespaces
kubectl get networkpolicies --all-namespaces
```

## Log Analysis

### ArgoCD Logs

```bash
# Server logs
kubectl logs -n argocd deployment/argocd-server -f

# Application controller logs
kubectl logs -n argocd deployment/argocd-application-controller -f

# Repository server logs
kubectl logs -n argocd deployment/argocd-repo-server -f
```

### Application Logs

```bash
# PostgreSQL logs
kubectl logs -n app-postgresql deployment/postgresql -f

# MongoDB logs
kubectl logs -n app-mongodb deployment/mongodb -f

# Redis logs
kubectl logs -n app-redis deployment/redis -f

```

## Performance Issues

### Resource Constraints

```bash
# Check node resources
kubectl describe nodes

# Check pod resources
kubectl describe pods --all-namespaces

# Check resource quotas
kubectl get resourcequota --all-namespaces
```

### Storage Issues

```bash
# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc --all-namespaces

# Check storage classes
kubectl get storageclass
```

## Getting Help

### Community Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Renovate Bot Documentation](https://docs.renovatebot.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Support Channels

- [ArgoCD Slack](https://argoproj.github.io/community/join-slack)
- [Helm Slack](https://kubernetes.slack.com/channels/helm)
- [Renovate Bot GitHub](https://github.com/renovatebot/renovate)

### Issue Reporting

When reporting issues, include:

1. **Environment**: OS, Kubernetes version, ArgoCD version
2. **Steps to Reproduce**: Detailed steps
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Logs**: Relevant log output
6. **Configuration**: Relevant configuration files
