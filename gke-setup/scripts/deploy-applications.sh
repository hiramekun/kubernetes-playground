#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Deploying applications to ArgoCD${NC}"

# Check if kubectl is available
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required but not installed.${NC}" >&2; exit 1; }

# Check if ArgoCD is installed
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${RED}❌ ArgoCD namespace not found. Please run install-argocd.sh first.${NC}"
    exit 1
fi

# Check if ArgoCD server is running
if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    echo -e "${RED}❌ ArgoCD server not found. Please run install-argocd.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Available applications:${NC}"
echo "  1. Helm-based applications (dev + prod)"
echo "  2. Kustomize-based applications (dev + prod)" 
echo "  3. All applications"

read -p "Which applications do you want to deploy? (1-3): " -n 1 -r
echo

case $REPLY in
    1)
        echo -e "${GREEN}🎯 Deploying Helm-based applications...${NC}"
        kubectl apply -f ../../argocd-applications/sample-app-helm-dev.yaml
        kubectl apply -f ../../argocd-applications/sample-app-helm-prod.yaml
        APPS=("sample-app-helm-dev" "sample-app-helm-prod")
        ;;
    2)
        echo -e "${GREEN}🎯 Deploying Kustomize-based applications...${NC}"
        kubectl apply -f ../../argocd-applications/sample-app-kustomize-dev.yaml
        kubectl apply -f ../../argocd-applications/sample-app-kustomize-prod.yaml
        APPS=("sample-app-kustomize-dev" "sample-app-kustomize-prod")
        ;;
    3)
        echo -e "${GREEN}🎯 Deploying all applications...${NC}"
        kubectl apply -f ../../argocd-applications/
        APPS=("sample-app-helm-dev" "sample-app-helm-prod" "sample-app-kustomize-dev" "sample-app-kustomize-prod")
        ;;
    *)
        echo -e "${RED}❌ Invalid selection. Exiting.${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}⏳ Waiting for applications to sync...${NC}"
sleep 10

# Check application status
echo -e "${BLUE}📊 Application Status:${NC}"
for app in "${APPS[@]}"; do
    if kubectl get application $app -n argocd >/dev/null 2>&1; then
        STATUS=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}')
        HEALTH=$(kubectl get application $app -n argocd -o jsonpath='{.status.health.status}')
        echo "  $app: Sync=$STATUS, Health=$HEALTH"
    else
        echo "  $app: Not found"
    fi
done

echo ""
echo -e "${GREEN}🎉 Application deployment completed!${NC}"
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "  1. Check ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Monitor applications: kubectl get applications -n argocd"
echo "  3. Check pods: kubectl get pods -n dev && kubectl get pods -n prod"
echo "  4. Access services: kubectl get services -n dev && kubectl get services -n prod"