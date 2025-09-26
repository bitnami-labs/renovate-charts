#!/bin/bash

# GitOps PoC Validation Script
# This script validates the complete GitOps PoC setup

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

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((PASSED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((FAILED_TESTS++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"

    ((TOTAL_TESTS++))
    log_info "Running test: $test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expected_result" = "success" ]; then
            log_success "$test_name"
        else
            log_error "$test_name (unexpected success)"
        fi
    else
        if [ "$expected_result" = "failure" ]; then
            log_success "$test_name"
        else
            log_error "$test_name"
        fi
    fi
}

# Test functions
test_cluster_connectivity() {
    log_info "Testing cluster connectivity..."

    run_test "Cluster is accessible" "kubectl cluster-info --context kind-$CLUSTER_NAME" "success"
    run_test "Cluster nodes are ready" "kubectl get nodes | grep -q Ready" "success"
    run_test "Cluster has required namespaces" "kubectl get namespace $ARGOCD_NAMESPACE" "success"
}

test_argocd_installation() {
    log_info "Testing ArgoCD installation..."

    run_test "ArgoCD namespace exists" "kubectl get namespace $ARGOCD_NAMESPACE" "success"
    run_test "ArgoCD server is running" "kubectl get pods -n $ARGOCD_NAMESPACE | grep -q argocd-server" "success"
    run_test "ArgoCD application controller is running" "kubectl get pods -n $ARGOCD_NAMESPACE | grep -q argocd-application-controller" "success"
    run_test "ArgoCD repo server is running" "kubectl get pods -n $ARGOCD_NAMESPACE | grep -q argocd-repo-server" "success"
    run_test "ArgoCD server service exists" "kubectl get svc -n $ARGOCD_NAMESPACE | grep -q argocd-server" "success"
}

test_ingress_controller() {
    log_info "Testing NGINX Ingress Controller..."

    run_test "Ingress namespace exists" "kubectl get namespace ingress-nginx" "success"
    run_test "Ingress controller is running" "kubectl get pods -n ingress-nginx | grep -q ingress-nginx-controller" "success"
    run_test "Ingress controller service exists" "kubectl get svc -n ingress-nginx | grep -q ingress-nginx-controller" "success"
}

test_argocd_applications() {
    log_info "Testing ArgoCD applications..."

    local applications=("postgresql" "mongodb" "redis")

    for app in "${applications[@]}"; do
        run_test "$app application exists" "kubectl get application $app -n $ARGOCD_NAMESPACE" "success"
        run_test "$app application is healthy" "kubectl get application $app -n $ARGOCD_NAMESPACE -o jsonpath='{.status.health.status}' | grep -q Healthy" "success"
        run_test "$app application is synced" "kubectl get application $app -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}' | grep -q Synced" "success"
    done
}

test_application_deployments() {
    log_info "Testing application deployments..."

    local applications=("postgresql" "mongodb" "redis")

    for app in "${applications[@]}"; do
        local namespace="app-$app"
        run_test "$app namespace exists" "kubectl get namespace $namespace" "success"
        run_test "$app deployment exists" "kubectl get deployment $app -n $namespace" "success"
        run_test "$app deployment is ready" "kubectl get deployment $app -n $namespace -o jsonpath='{.status.readyReplicas}' | grep -q 1" "success"
        run_test "$app service exists" "kubectl get svc $app -n $namespace" "success"
        run_test "$app pods are running" "kubectl get pods -n $namespace | grep -q Running" "success"
    done
}

test_application_connectivity() {
    log_info "Testing application connectivity..."

    # Test PostgreSQL
    run_test "PostgreSQL is accessible" "kubectl run postgresql-test --rm --tty -i --restart='Never' --namespace app-postgresql --image docker.io/bitnami/postgresql:15 --env='PGPASSWORD=apppass123' --command -- psql --host postgresql -U appuser -d appdb -p 5432 -c 'SELECT 1;'" "success"

    # Test Redis
    run_test "Redis is accessible" "kubectl run redis-test --rm --tty -i --restart='Never' --namespace app-redis --image docker.io/bitnami/redis:7 --command -- redis-cli -h redis -a redispass123 ping" "success"

}

test_helm_charts() {
    log_info "Testing Helm chart availability..."

    run_test "OCI charts are accessible" "kubectl get application postgresql -n argocd -o jsonpath='{.spec.source.repoURL}' | grep -q bitnamichartssecure" "success"
    run_test "PostgreSQL chart is available" "helm search repo bitnami/postgresql --versions | head -1" "success"
    run_test "MongoDB chart is available" "helm search repo bitnami/mongodb --versions | head -1" "success"
    run_test "Redis chart is available" "helm search repo bitnami/redis --versions | head -1" "success"
}

test_configuration_files() {
    log_info "Testing configuration files..."

    run_test "ArgoCD application files are valid YAML" "yq eval '.' argocd-applications/*.yaml > /dev/null" "success"
    run_test "Renovate configuration is valid JSON" "jq empty .github/renovate.json" "success"
    run_test "GitHub Actions workflows are valid YAML" "yq eval '.' .github/workflows/*.yml > /dev/null" "success"
}

test_gitops_workflow() {
    log_info "Testing GitOps workflow..."

    # Check if applications are synced
    local applications=("postgresql" "mongodb" "redis")

    for app in "${applications[@]}"; do
        run_test "$app is synced with Git" "kubectl get application $app -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}' | grep -q Synced" "success"
    done

    # Check if applications are healthy
    for app in "${applications[@]}"; do
        run_test "$app is healthy" "kubectl get application $app -n $ARGOCD_NAMESPACE -o jsonpath='{.status.health.status}' | grep -q Healthy" "success"
    done
}

test_security() {
    log_info "Testing security configurations..."

    local applications=("postgresql" "mongodb" "redis")

    for app in "${applications[@]}"; do
        local namespace="app-$app"
        run_test "$app pods run as non-root" "kubectl get pods -n $namespace -o jsonpath='{.items[0].spec.securityContext.runAsNonRoot}' | grep -q true" "success"
        run_test "$app pods have security context" "kubectl get pods -n $namespace -o jsonpath='{.items[0].spec.securityContext}' | grep -q runAsUser" "success"
    done
}

test_persistence() {
    log_info "Testing persistence configurations..."

    local applications=("postgresql" "mongodb" "redis")

    for app in "${applications[@]}"; do
        local namespace="app-$app"
        run_test "$app has persistent volume claim" "kubectl get pvc -n $namespace | grep -q $app" "success"
    done
}

# Main execution
main() {
    log_info "Starting GitOps PoC validation..."
    echo "======================================"
    echo ""

    # Run all tests
    test_cluster_connectivity
    echo ""

    test_argocd_installation
    echo ""

    test_ingress_controller
    echo ""

    test_argocd_applications
    echo ""

    test_application_deployments
    echo ""

    test_application_connectivity
    echo ""

    test_helm_charts
    echo ""

    test_configuration_files
    echo ""

    test_gitops_workflow
    echo ""

    test_security
    echo ""

    test_persistence
    echo ""

    # Print summary
    log_info "Validation Summary:"
    echo "==================="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All tests passed! GitOps PoC is working correctly."
        echo ""
        log_info "Next steps:"
        echo "1. Access ArgoCD UI at https://localhost:8080"
        echo "2. Configure Renovate Bot for automated updates"
        echo "3. Test the complete GitOps workflow"
        echo "4. Review the documentation for advanced usage"
        exit 0
    else
        log_error "Some tests failed. Please check the errors above and fix them."
        echo ""
        log_info "Common issues and solutions:"
        echo "1. Cluster not running: Run 'make setup' to create the cluster"
        echo "2. ArgoCD not accessible: Check if ArgoCD is installed and running"
        echo "3. Applications not syncing: Check ArgoCD application status"
        echo "4. Pods not running: Check pod logs and resource constraints"
        echo ""
        log_info "For detailed troubleshooting, see docs/setup.md (Troubleshooting section)"
        exit 1
    fi
}

# Run main function
main "$@"

