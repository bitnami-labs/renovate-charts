# GitOps PoC Makefile
# This Makefile provides convenient commands for managing the GitOps PoC

.PHONY: help setup clean status logs test validate

# Default target
help: ## Show this help message
	@echo "GitOps PoC - Available Commands:"
	@echo "================================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Setup commands
setup: ## Set up the complete GitOps PoC environment
	@echo "🚀 Setting up GitOps PoC environment..."
	./scripts/setup-cluster.sh

setup-cluster: ## Set up only the Kubernetes cluster and ArgoCD
	@echo "🔧 Setting up Kubernetes cluster and ArgoCD..."
	./scripts/setup-cluster.sh --skip-applications

setup-ingress: ## Install NGINX Ingress Controller
	@echo "🌐 Installing NGINX Ingress Controller..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s

setup-helm-repo: ## Note: Using OCI charts directly - no helm repo setup needed
	@echo "📦 Using OCI charts directly - no helm repo setup needed"
	@echo "ℹ️  ArgoCD applications reference OCI charts directly from registry-1.docker.io/bitnamichartssecure"

# Cleanup commands
clean: ## Clean up the entire GitOps PoC environment
	@echo "🧹 Cleaning up GitOps PoC environment..."
	./scripts/cleanup.sh

clean-cluster: ## Clean up only the Kubernetes cluster
	@echo "🗑️ Cleaning up Kubernetes cluster..."
	./scripts/cleanup.sh --cluster-only

clean-files: ## Clean up temporary files
	@echo "📁 Cleaning up temporary files..."
	./scripts/cleanup.sh --files-only

clean-docker: ## Clean up Docker resources
	@echo "🐳 Cleaning up Docker resources..."
	./scripts/cleanup.sh --docker-only

# Status commands
status: ## Show the status of all components
	@echo "📊 GitOps PoC Status:"
	@echo "===================="
	@echo ""
	@echo "🔍 Cluster Status:"
	@kubectl cluster-info --context kind-gitops-poc 2>/dev/null || echo "  ❌ Cluster not accessible"
	@echo ""
	@echo "🔍 ArgoCD Status:"
	@kubectl get pods -n argocd 2>/dev/null || echo "  ❌ ArgoCD not found"
	@echo ""
	@echo "🔍 Applications Status:"
	@kubectl get applications -n argocd 2>/dev/null || echo "  ❌ No applications found"
	@echo ""
	@echo "🔍 Application Pods:"
	@kubectl get pods --all-namespaces | grep -E "(app-|argocd)" || echo "  ❌ No application pods found"

status-apps: ## Show detailed status of all applications
	@echo "📱 Application Status:"
	@echo "====================="
	@for app in postgresql mongodb redis; do \
		echo ""; \
		echo "🔍 $$app:"; \
		kubectl get application $$app -n argocd 2>/dev/null || echo "  ❌ Application not found"; \
		kubectl get pods -n app-$$app 2>/dev/null || echo "  ❌ No pods found"; \
		kubectl get svc -n app-$$app 2>/dev/null || echo "  ❌ No services found"; \
	done

# Logging commands
logs: ## Show logs for all ArgoCD components
	@echo "📋 ArgoCD Logs:"
	@echo "==============="
	@kubectl logs -n argocd deployment/argocd-server --tail=50
	@echo ""
	@kubectl logs -n argocd deployment/argocd-application-controller --tail=50

logs-app: ## Show logs for a specific application (usage: make logs-app APP=postgresql)
	@if [ -z "$(APP)" ]; then \
		echo "❌ Please specify APP parameter (e.g., make logs-app APP=postgresql)"; \
		exit 1; \
	fi
	@echo "📋 Logs for $(APP):"
	@echo "=================="
	@kubectl logs -n app-$(APP) deployment/$(APP) --tail=50

# Testing commands
test: ## Run basic tests to verify the setup
	@echo "🧪 Running GitOps PoC Tests:"
	@echo "============================"
	@echo ""
	@echo "🔍 Testing cluster connectivity..."
	@kubectl cluster-info --context kind-gitops-poc > /dev/null 2>&1 && echo "  ✅ Cluster accessible" || echo "  ❌ Cluster not accessible"
	@echo ""
	@echo "🔍 Testing ArgoCD..."
	@kubectl get pods -n argocd | grep -q "Running" && echo "  ✅ ArgoCD running" || echo "  ❌ ArgoCD not running"
	@echo ""
	@echo "🔍 Testing applications..."
	@for app in postgresql mongodb redis; do \
		if kubectl get application $$app -n argocd > /dev/null 2>&1; then \
			echo "  ✅ $$app application exists"; \
		else \
			echo "  ❌ $$app application not found"; \
		fi; \
	done
	@echo ""
	@echo "🔍 Testing application pods..."
	@for app in postgresql mongodb redis; do \
		if kubectl get pods -n app-$$app | grep -q "Running" 2>/dev/null; then \
			echo "  ✅ $$app pods running"; \
		else \
			echo "  ❌ $$app pods not running"; \
		fi; \
	done

test-connectivity: ## Test connectivity to all applications
	@echo "🔗 Testing Application Connectivity:"
	@echo "===================================="
	@echo ""
	@echo "🔍 Testing PostgreSQL..."
	@kubectl run postgresql-test --rm --tty -i --restart='Never' --namespace app-postgresql --image docker.io/bitnami/postgresql:15 --env="PGPASSWORD=apppass123" --command -- psql --host postgresql -U appuser -d appdb -p 5432 -c "SELECT 1;" > /dev/null 2>&1 && echo "  ✅ PostgreSQL accessible" || echo "  ❌ PostgreSQL not accessible"
	@echo ""
	@echo "🔍 Testing Redis..."
	@kubectl run redis-test --rm --tty -i --restart='Never' --namespace app-redis --image docker.io/bitnami/redis:7 --command -- redis-cli -h redis -a redispass123 ping > /dev/null 2>&1 && echo "  ✅ Redis accessible" || echo "  ❌ Redis not accessible"
	@echo ""

# Validation commands
validate: ## Validate all configuration files
	@echo "✅ Validating Configuration Files:"
	@echo "=================================="
	@echo ""
	@echo "🔍 Validating ArgoCD applications..."
	@for file in argocd-applications/*.yaml; do \
		if yq eval '.' "$$file" > /dev/null 2>&1; then \
			echo "  ✅ $$file"; \
		else \
			echo "  ❌ $$file"; \
		fi; \
	done
	@echo ""
	@echo ""
	@echo "🔍 Validating Renovate configuration..."
	@if jq empty .github/renovate.json 2>/dev/null; then \
		echo "  ✅ .github/renovate.json"; \
	else \
		echo "  ❌ .github/renovate.json"; \
	fi
	@echo ""
	@echo "🔍 Validating GitHub Actions workflows..."
	@for file in .github/workflows/*.yml; do \
		if yq eval '.' "$$file" > /dev/null 2>&1; then \
			echo "  ✅ $$file"; \
		else \
			echo "  ❌ $$file"; \
		fi; \
	done

# Port forwarding commands
port-forward: ## Start port forwarding for ArgoCD and applications
	@echo "🔗 Starting Port Forwards:"
	@echo "=========================="
	@echo ""
	@echo "🔍 ArgoCD UI: https://localhost:8080"
	@kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
	@echo "  ✅ ArgoCD port forward started (PID: $$!)"
	@echo ""
	@echo "🔍 PostgreSQL: localhost:5432"
	@kubectl port-forward svc/postgresql -n app-postgresql 5432:5432 > /dev/null 2>&1 &
	@echo "  ✅ PostgreSQL port forward started (PID: $$!)"
	@echo ""
	@echo "🔍 Redis: localhost:6379"
	@kubectl port-forward svc/redis -n app-redis 6379:6379 > /dev/null 2>&1 &
	@echo "  ✅ Redis port forward started (PID: $$!)"
	@echo ""
	@echo "📝 Port forward PIDs saved to .port-forward-pids"
	@echo "$$!" > .port-forward-pids

stop-port-forward: ## Stop all port forwards
	@echo "🛑 Stopping Port Forwards:"
	@echo "=========================="
	@if [ -f ".port-forward-pids" ]; then \
		while read pid; do \
			if kill -0 "$$pid" 2>/dev/null; then \
				kill "$$pid" && echo "  ✅ Stopped port forward (PID: $$pid)"; \
			fi; \
		done < .port-forward-pids; \
		rm -f .port-forward-pids; \
	else \
		echo "  ℹ️ No port forward PIDs found"; \
	fi
	@pkill -f "kubectl port-forward" 2>/dev/null || true

# Utility commands
get-password: ## Get ArgoCD admin password
	@echo "🔑 ArgoCD Admin Password:"
	@echo "========================"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "❌ Could not retrieve password"

sync-apps: ## Force sync all ArgoCD applications
	@echo "🔄 Syncing ArgoCD Applications:"
	@echo "==============================="
	@for app in postgresql mongodb redis; do \
		echo "🔍 Syncing $$app..."; \
		kubectl patch application $$app -n argocd --type merge -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}' 2>/dev/null && echo "  ✅ $$app synced" || echo "  ❌ Failed to sync $$app"; \
	done

restart-apps: ## Restart all application deployments
	@echo "🔄 Restarting Applications:"
	@echo "==========================="
	@for app in postgresql mongodb redis; do \
		echo "🔍 Restarting $$app..."; \
		kubectl rollout restart deployment/$$app -n app-$$app 2>/dev/null && echo "  ✅ $$app restarted" || echo "  ❌ Failed to restart $$app"; \
	done

# Documentation commands
docs: ## Open documentation in browser
	@echo "📚 Opening Documentation:"
	@echo "========================"
	@echo "  📖 README.md"
	@echo "  📖 docs/setup.md"
	@echo "  📖 docs/architecture.md"
	@echo ""
	@echo "Use 'make help' to see all available commands"

# Development commands
dev-setup: ## Set up development environment
	@echo "🛠️ Setting up Development Environment:"
	@echo "====================================="
	@echo ""
	@echo "🔍 Installing development tools..."
	@if command -v brew > /dev/null 2>&1; then \
		brew install kind helm kubectl yq jq; \
	else \
		echo "  ℹ️ Please install required tools manually"; \
	fi
	@echo ""
	@echo "🔍 Setting up pre-commit hooks..."
	@if [ -f ".git/hooks/pre-commit" ]; then \
		echo "  ✅ Pre-commit hooks already installed"; \
	else \
		echo "  ℹ️ Pre-commit hooks not installed"; \
	fi

# All-in-one commands
full-setup: setup validate test ## Complete setup with validation and testing
	@echo "🎉 Full setup completed successfully!"

full-clean: stop-port-forward clean ## Complete cleanup including port forwards
	@echo "🧹 Full cleanup completed successfully!"
