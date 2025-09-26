# Bitnami Charts Secure Repository

## Overview

This GitOps PoC uses **Bitnami Charts Secure OCI charts** directly from the
Docker registry instead of traditional Helm repositories. The OCI charts provide
additional security features, faster downloads, and improved reliability.

## Repository Information

- **Repository URL**: `https://charts.bitnami.com/bitnami-secure`
- **Docker Hub**: [Bitnami Charts Secure](https://hub.docker.com/u/bitnamichartssecure)
- **Documentation**: [Bitnami Charts Secure Documentation](https://docs.bitnami.com/kubernetes/)

## Key Differences

### Security Enhancements

- **Hardened Images**: Security-hardened container images
- **Non-root Containers**: All containers run as non-root users
- **Minimal Attack Surface**: Reduced image size and dependencies
- **Security Scanning**: Regular vulnerability scanning and updates

### Configuration Changes

- **Source Type**: Using OCI charts directly from `registry-1.docker.io/bitnamichartssecure`
- **No Helm Repo**: No need to add or manage Helm repositories
- **Direct Access**: Charts are pulled directly from the OCI registry
- **Values Compatibility**: Standard Helm values remain compatible

## Updated Components

### ArgoCD Applications

All ArgoCD application manifests have been updated to use the secure repository:

- `argocd-applications/postgresql.yaml`
- `argocd-applications/mongodb.yaml`
- `argocd-applications/redis.yaml`

### GitHub Actions Workflows

Both CI/CD workflows have been updated:

- `.github/workflows/renovate-pr.yml`
- `.github/workflows/ci.yml`

### Documentation

All documentation has been updated to reflect the use of Bitnami Charts Secure:

- `README.md`
- `docs/setup.md`
- `docs/architecture.md`

### Automation Scripts

- `Makefile`: Added `setup-helm-repo` target for adding the secure repository

## Setup Instructions

### Adding the Secure Repository

```bash
# Note: Using OCI charts directly - no helm repo setup needed
# The ArgoCD applications reference OCI charts directly from:
# registry-1.docker.io/bitnamichartssecure
```

### Using with ArgoCD

The ArgoCD applications are already configured to use OCI charts directly.
No additional configuration or repository setup is required.

### Verification

To verify that OCI charts are being used:

```bash
# Check ArgoCD application source
kubectl get application postgresql -n argocd -o yaml | grep repoURL

# Expected output:
# repoURL: registry-1.docker.io/bitnamichartssecure
```

## Benefits

### Enhanced Security

- **Vulnerability Management**: Regular security updates and patches
- **Compliance**: Meets enterprise security requirements
- **Audit Trail**: Better security monitoring and logging

### Production Readiness

- **Enterprise Support**: Professional support and SLA
- **Stability**: Tested and validated configurations
- **Documentation**: Comprehensive security documentation

## Migration Notes

### From Standard Bitnami Charts

If migrating from the standard Bitnami charts repository:

1. **Update Repository URL**: Change from `bitnami` to `bitnami-secure`
2. **Verify Chart Versions**: Ensure chart versions are available in secure repository
3. **Test Deployments**: Validate that applications deploy correctly
4. **Update CI/CD**: Update any automation scripts or workflows

### Compatibility

- **Helm Values**: Existing Helm values files are compatible
- **Chart Versions**: Same version numbers across both repositories
- **API Compatibility**: No changes to Kubernetes APIs or resources

## References

- [Bitnami Charts Secure Documentation](https://docs.bitnami.com/kubernetes/)
- [Docker Hub - Bitnami Charts Secure](https://hub.docker.com/u/bitnamichartssecure)
- [Bitnami Security Best Practices](https://docs.bitnami.com/kubernetes/security/)
- [Helm Repository Management](https://helm.sh/docs/helm/helm_repo/)
