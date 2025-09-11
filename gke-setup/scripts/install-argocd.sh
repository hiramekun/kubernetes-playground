#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Installing ArgoCD on GKE cluster${NC}"

# Check if kubectl is available
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required but not installed.${NC}" >&2; exit 1; }

# Check if cluster is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot access Kubernetes cluster. Please run setup-gke.sh first.${NC}"
    exit 1
fi

# Create ArgoCD namespace
echo -e "${GREEN}📦 Creating ArgoCD namespace...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "${GREEN}⬇️  Installing ArgoCD...${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "${GREEN}⏳ Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-redis -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd

# Get ArgoCD admin password
echo -e "${GREEN}🔐 Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo -e "${GREEN}🎉 ArgoCD installation completed successfully!${NC}"
echo -e "${YELLOW}📋 Access Information:${NC}"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo -e "${YELLOW}🌐 To access ArgoCD UI:${NC}"
echo "  1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Open browser: https://localhost:8080"
echo "  3. Login with admin/$ARGOCD_PASSWORD"
echo ""
echo -e "${YELLOW}📱 To deploy applications:${NC}"
echo "  kubectl apply -f ../../argocd-applications/"