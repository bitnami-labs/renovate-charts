#!/bin/bash

# GitOps PoC Cluster Setup Script
# This script sets up a local Kubernetes cluster with ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="gitops-poc"
ARGOCD_NAMESPACE="argocd"
ARGOCD_PORT="8080"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if required tools are installed
    local tools=("kind" "kubectl" "helm" "yq" "jq")
    local missing_tools=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and run the script again."
        exit 1
    fi

    log_success "All prerequisites are installed"
}

create_cluster() {
    log_info "Creating Kubernetes cluster with kind..."

    # Check if cluster already exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        log_warning "Cluster $CLUSTER_NAME already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "$CLUSTER_NAME"
        else
            log_info "Using existing cluster"
            return 0
        fi
    fi

    # Create cluster with configuration
    if [ -f "kind-config.yaml" ]; then
        log_info "Creating cluster with custom configuration..."
        kind create cluster --config kind-config.yaml
    else
        log_info "Creating cluster with default configuration..."
        kind create cluster --name "$CLUSTER_NAME"
    fi

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    log_success "Cluster created successfully"
}

install_ingress() {
    log_info "Installing NGINX Ingress Controller..."

    # Install NGINX Ingress Controller
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    # Wait for ingress controller to be ready
    log_info "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s

    log_success "NGINX Ingress Controller installed successfully"
}

install_argocd() {
    log_info "Installing ArgoCD..."

    # Create ArgoCD namespace
    kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Install ArgoCD
    kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n "$ARGOCD_NAMESPACE"

    log_success "ArgoCD installed successfully"
}

get_argocd_password() {
    log_info "Getting ArgoCD admin password..."

    # Wait for secret to be created
    kubectl wait --for=condition=Ready --timeout=60s secret/argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" 2>/dev/null || true

    # Get password
    local password
    password=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")

    if [ -z "$password" ]; then
        log_warning "Could not retrieve ArgoCD password. You may need to wait a bit longer."
        log_info "Try running: kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    else
        log_success "ArgoCD admin password: $password"
        echo "$password" > argocd-password.txt
        log_info "Password saved to argocd-password.txt"
    fi
}

setup_port_forward() {
    log_info "Setting up port forward for ArgoCD..."

    # Kill existing port forward if any
    pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true

    # Start port forward in background
    kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" "$ARGOCD_PORT:443" > /dev/null 2>&1 &
    local pf_pid=$!

    # Wait a moment for port forward to establish
    sleep 3

    # Check if port forward is working
    if curl -k -s https://localhost:"$ARGOCD_PORT" > /dev/null 2>&1; then
        log_success "ArgoCD is accessible at https://localhost:$ARGOCD_PORT"
        log_info "Port forward PID: $pf_pid"
        echo "$pf_pid" > argocd-port-forward.pid
    else
        log_warning "Port forward may not be working. You can start it manually with:"
        log_info "kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE $ARGOCD_PORT:443"
    fi
}

deploy_applications() {
    log_info "Deploying ArgoCD applications..."

    # Check if application files exist
    if [ ! -d "argocd-applications" ]; then
        log_error "argocd-applications directory not found"
        return 1
    fi

    # Apply applications
    kubectl apply -f argocd-applications/

    log_success "ArgoCD applications deployed successfully"
}

verify_setup() {
    log_info "Verifying setup..."

    # Check cluster status
    log_info "Cluster status:"
    kubectl cluster-info

    # Check ArgoCD status
    log_info "ArgoCD status:"
    kubectl get pods -n "$ARGOCD_NAMESPACE"

    # Check applications
    log_info "ArgoCD applications:"
    kubectl get applications -n "$ARGOCD_NAMESPACE" 2>/dev/null || log_warning "No applications found yet"

    # Check ingress
    log_info "Ingress controller:"
    kubectl get pods -n ingress-nginx

    log_success "Setup verification completed"
}

print_summary() {
    log_success "GitOps PoC setup completed successfully!"
    echo
    log_info "Access Information:"
    echo "  ArgoCD UI: https://localhost:$ARGOCD_PORT"
    echo "  Username: admin"
    echo "  Password: $(cat argocd-password.txt 2>/dev/null || echo 'Check argocd-password.txt file')"
    echo
    log_info "Useful Commands:"
    echo "  Check ArgoCD applications: kubectl get applications -n $ARGOCD_NAMESPACE"
    echo "  Check application pods: kubectl get pods --all-namespaces"
    echo "  Stop port forward: kill \$(cat argocd-port-forward.pid)"
    echo "  Delete cluster: kind delete cluster --name $CLUSTER_NAME"
    echo
    log_info "Next Steps:"
    echo "  1. Access ArgoCD UI and verify applications are syncing"
    echo "  2. Check application health in ArgoCD"
    echo "  3. Test application access"
    echo "  4. Configure Renovate Bot for automated updates"
    echo
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f argocd-password.txt argocd-port-forward.pid
}

# Main execution
main() {
    log_info "Starting GitOps PoC cluster setup..."

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-ingress)
                SKIP_INGRESS=true
                shift
                ;;
            --skip-applications)
                SKIP_APPLICATIONS=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --skip-ingress      Skip NGINX Ingress Controller installation"
                echo "  --skip-applications Skip ArgoCD applications deployment"
                echo "  --help              Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Setup trap for cleanup
    trap cleanup EXIT

    # Execute setup steps
    check_prerequisites
    create_cluster
    install_ingress
    install_argocd
    get_argocd_password
    setup_port_forward

    if [ "$SKIP_APPLICATIONS" != "true" ]; then
        deploy_applications
    fi

    verify_setup
    print_summary
}

# Run main function
main "$@"

