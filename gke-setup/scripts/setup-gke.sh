#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting GKE cluster setup${NC}"

# Check if required tools are installed
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform is required but not installed.${NC}" >&2; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo -e "${RED}❌ gcloud CLI is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required but not installed.${NC}" >&2; exit 1; }

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars not found. Please copy terraform.tfvars.example to terraform.tfvars and update the values.${NC}"
    exit 1
fi

cd gke-setup/terraform

# Initialize Terraform
echo -e "${GREEN}📋 Initializing Terraform...${NC}"
terraform init

# Plan the deployment
echo -e "${GREEN}📋 Planning Terraform deployment...${NC}"
terraform plan

# Ask for confirmation
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Deployment cancelled.${NC}"
    exit 1
fi

# Apply the Terraform configuration
echo -e "${GREEN}🏗️  Creating GKE cluster...${NC}"
terraform apply -auto-approve

# Get cluster credentials
CLUSTER_NAME=$(terraform output -raw cluster_name)
PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw region)

echo -e "${GREEN}🔑 Getting cluster credentials...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID

# Verify cluster connection
echo -e "${GREEN}✅ Verifying cluster connection...${NC}"
kubectl cluster-info
kubectl get nodes

echo -e "${GREEN}🎉 GKE cluster setup completed successfully!${NC}"
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "  1. Install ArgoCD: kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
echo "  2. Setup ArgoCD access: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  3. Get ArgoCD admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "  4. Apply ArgoCD applications: kubectl apply -f ../../argocd-applications/"