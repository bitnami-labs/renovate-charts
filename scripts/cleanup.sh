#!/bin/bash

# GitOps PoC Cleanup Script
# This script cleans up the local Kubernetes cluster and related resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="gitops-poc"

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

stop_port_forwards() {
    log_info "Stopping port forwards..."

    # Stop ArgoCD port forward
    if [ -f "argocd-port-forward.pid" ]; then
        local pid=$(cat argocd-port-forward.pid)
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "Stopped ArgoCD port forward (PID: $pid)"
        fi
        rm -f argocd-port-forward.pid
    fi

    # Kill any remaining port forwards
    pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true
}

delete_cluster() {
    log_info "Deleting Kubernetes cluster..."

    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        kind delete cluster --name "$CLUSTER_NAME"
        log_success "Cluster $CLUSTER_NAME deleted successfully"
    else
        log_warning "Cluster $CLUSTER_NAME not found"
    fi
}

cleanup_files() {
    log_info "Cleaning up temporary files..."

    # Remove temporary files
    rm -f argocd-password.txt
    rm -f argocd-port-forward.pid

    # Remove any local kubeconfig backups
    rm -f kubeconfig-backup

    log_success "Temporary files cleaned up"
}

cleanup_docker() {
    log_info "Cleaning up Docker resources..."

    # Remove unused images
    docker image prune -f

    # Remove unused volumes
    docker volume prune -f

    # Remove unused networks
    docker network prune -f

    log_success "Docker resources cleaned up"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --cluster-only    Only delete the cluster, keep other resources"
    echo "  --files-only      Only clean up temporary files"
    echo "  --docker-only     Only clean up Docker resources"
    echo "  --all             Clean up everything (default)"
    echo "  --help            Show this help message"
}

# Main execution
main() {
    local cleanup_cluster=true
    local cleanup_files=true
    local cleanup_docker=true

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cluster-only)
                cleanup_cluster=true
                cleanup_files=false
                cleanup_docker=false
                shift
                ;;
            --files-only)
                cleanup_cluster=false
                cleanup_files=true
                cleanup_docker=false
                shift
                ;;
            --docker-only)
                cleanup_cluster=false
                cleanup_files=false
                cleanup_docker=true
                shift
                ;;
            --all)
                cleanup_cluster=true
                cleanup_files=true
                cleanup_docker=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    log_info "Starting GitOps PoC cleanup..."

    # Confirm deletion
    if [ "$cleanup_cluster" = true ]; then
        log_warning "This will delete the Kubernetes cluster and all applications."
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled"
            exit 0
        fi
    fi

    # Execute cleanup steps
    if [ "$cleanup_cluster" = true ]; then
        stop_port_forwards
        delete_cluster
    fi

    if [ "$cleanup_files" = true ]; then
        cleanup_files
    fi

    if [ "$cleanup_docker" = true ]; then
        cleanup_docker
    fi

    log_success "Cleanup completed successfully!"
}

# Run main function
main "$@"

