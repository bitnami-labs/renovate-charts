# GitOps-driven Application Lifecycle Management PoC

This Proof of Concept demonstrates a complete GitOps workflow using Helm, ArgoCD,
GitHub Actions, and Renovate Bot for managing application lifecycle in Kubernetes.

## Project Overview

This PoC establishes a foundational understanding and practical demonstration of
managing the lifecycle of applications embedded with Helm charts using GitOps
principles. The outcome serves as a practical complement and validation for
technical documentation focusing on best practices for application deployment,
versioning, and dependency management.

## Architecture

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   ArgoCD        │    │   Kubernetes    │
│   (GitOps)      │◄──►│   (GitOps CD)   │◄──►│   Cluster       │
│                 │    │                 │    │                 │
│ • App Manifests │    │ • Sync Status   │    │ • Applications  │
│ • Helm Values   │    │ • Health Check  │    │ • Services      │
│ • Renovate      │    │ • Auto-Sync     │    │ • Ingress       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲
         │
┌─────────────────┐
│  GitHub Actions │
│  (CI/CD)        │
│                 │
│ • Validation    │
│ • Testing       │
│ • Auto-merge    │
└─────────────────┘
```

## Components

### 1. Kubernetes Infrastructure

- **Local Cluster**: kind/k3d for easy setup and teardown
- **ArgoCD**: GitOps continuous delivery tool

### 2. Applications (Bitnami OCI Charts)

- **PostgreSQL**: Database with persistence
- **MongoDB**: Document database
- **Redis**: In-memory data store

> **Note**: This PoC uses OCI (Open Container Initiative) Helm charts from Bitnami,
> which provide better security, faster downloads, and improved reliability
> compared to traditional Helm repositories.

### 3. GitOps Repository

- **ArgoCD Applications**: Declarative application definitions
- **App-of-Apps**: Pattern for managing multiple applications

### 4. Automation

- **Renovate Bot**: Automated dependency updates
- **GitHub Actions**: CI/CD pipeline with validation and auto-merge

## Quick Start

1. **Prerequisites**

   ```bash
   # Install required tools
   brew install kind helm kubectl argocd
   ```

2. **Setup Kubernetes Cluster**

   ```bash
   # Create kind cluster
   kind create cluster --name gitops-poc

   # Install ArgoCD
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

3. **Access ArgoCD**

   ```bash
   # Port forward to access UI
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Access at https://localhost:8080
   # Default username: admin
   # Get password: kubectl -n argocd get secret argocd-initial-admin-secret \\
   #   -o jsonpath="{.data.password}" | base64 -d
   ```

4. **Deploy Applications**

   ```bash
   # Apply ArgoCD applications
   kubectl apply -f argocd-applications/
   ```

## Directory Structure

```text
├── README.md                  # This file
├── kind-config.yaml           # Kind cluster configuration
├── argocd-applications/       # ArgoCD application manifests
│   ├── app-of-apps.yaml       # Root application
│   ├── postgresql.yaml        # PostgreSQL application
│   ├── mongodb.yaml           # MongoDB application
│   └── redis.yaml             # Redis application
├── .github/                   # GitHub configuration
│   ├── workflows/             # GitHub Actions workflows
│   │   ├── renovate-pr.yml    # Renovate PR validation
│   │   └── ci.yml             # General CI workflow
│   └── renovate.json          # Renovate Bot configuration
└── docs/                      # Documentation
    ├── setup.md               # Detailed setup instructions
    ├── troubleshooting.md     # Common issues and solutions
    └── architecture.md        # Detailed architecture overview
```

## Success Metrics

- ✅ ArgoCD applications remain synchronized and healthy
- ✅ Renovate Bot consistently proposes chart updates via PRs
- ✅ GitHub Actions pipeline validates Renovate PRs without errors
- ✅ Complete setup is easily reproducible and well-documented

## Next Steps

1. Follow the detailed setup instructions in `docs/setup.md`
2. Deploy the applications using ArgoCD
3. Configure Renovate Bot for automated updates
4. Test the complete GitOps workflow

## Contributing

This is a PoC project. For production use, consider:

- Security hardening (RBAC, network policies)
- Monitoring and observability
- Backup and disaster recovery
- Multi-environment support
