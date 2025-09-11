# Kubernetes Playground - GKE CI/CD with ArgoCD

このプロジェクトでは、GKEにおけるCI/CDの仕組みを試すために、ArgoCD + Helm と ArgoCD + Kustomize の二つの構成を実装しています。

## 🏗️ アーキテクチャ

### フォルダ構成
```
📁 kubernetes-playground/
├── 🛠️ helm-config/              # Helm構成
│   ├── apps/sample-app/         # Helmチャート
│   └── environments/            # 環境別設定
│       ├── dev/values.yaml
│       └── prod/values.yaml
├── 🔧 kustomize-config/         # Kustomize構成  
│   ├── base/                    # ベースマニフェスト
│   └── environments/            # 環境別オーバーレイ
│       ├── dev/
│       └── prod/
├── 🚀 argocd-applications/      # ArgoCD Application定義
├── 🏭 gke-setup/               # GKEセットアップ
│   ├── terraform/              # インフラ構成
│   └── scripts/                # デプロイスクリプト
└── 🔄 .github/workflows/       # CI/CD パイプライン
```

### システム構成図

#### 1. インフラストラクチャ層

```mermaid
graph TB
    subgraph "GCP Project"
        subgraph "Terraform構成"
            TF[Terraform]
            TF_MAIN[main.tf]
            TF_VAR[variables.tf]
            TF_OUT[outputs.tf]
        end
        
        subgraph "作成されるリソース"
            GKE[GKE Cluster<br/>kubernetes-playground]
            AR[Artifact Registry<br/>Container Images]
            SA[Service Account<br/>gke-nodes-sa]
            NET[Network<br/>Private Cluster]
        end
        
        subgraph "セキュリティ"
            WI[Workload Identity<br/>Enabled]
            IAM[IAM Roles<br/>Minimal Permissions]
        end
    end
    
    TF --> TF_MAIN
    TF --> TF_VAR
    TF --> TF_OUT
    
    TF_MAIN -->|creates| GKE
    TF_MAIN -->|creates| AR
    TF_MAIN -->|creates| SA
    TF_MAIN -->|creates| NET
    
    SA --> WI
    SA --> IAM
    
    classDef tf fill:#623ce4,stroke:#333,stroke-width:2px,color:#fff
    classDef gcp fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    classDef security fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
    
    class TF,TF_MAIN,TF_VAR,TF_OUT tf
    class GKE,AR,SA,NET gcp
    class WI,IAM security
```

#### 2. CI/CDパイプライン

```mermaid
graph LR
    subgraph "GitHub Repository"
        REPO[kubernetes-playground]
        HELM[helm-config/]
        KUST[kustomize-config/]
        ARGO_APP[argocd-applications/]
    end
    
    subgraph "GitHub Actions"
        PR[Pull Request]
        VALIDATE[Validate Workflow]
        HELM_TEST[Helm Template Test]
        KUST_TEST[Kustomize Build Test]
    end
    
    subgraph "GKE Cluster"
        ARGOCD[ArgoCD Controller]
        DEV_APP[Dev Application]
        PROD_APP[Prod Application]
    end
    
    REPO --> PR
    PR --> VALIDATE
    VALIDATE --> HELM_TEST
    VALIDATE --> KUST_TEST
    
    HELM --> HELM_TEST
    KUST --> KUST_TEST
    
    REPO -->|GitOps Sync| ARGOCD
    ARGO_APP --> ARGOCD
    ARGOCD --> DEV_APP
    ARGOCD --> PROD_APP
    
    classDef github fill:#24292e,stroke:#333,stroke-width:2px,color:#fff
    classDef ci fill:#28a745,stroke:#333,stroke-width:2px,color:#fff
    classDef argocd fill:#ef7b4d,stroke:#333,stroke-width:2px,color:#fff
    
    class REPO,HELM,KUST,ARGO_APP,PR github
    class VALIDATE,HELM_TEST,KUST_TEST ci
    class ARGOCD,DEV_APP,PROD_APP argocd
```

#### 3. 設定管理の比較

```mermaid
graph TB
    subgraph "Helm Approach"
        HELM_CHART[Chart.yaml<br/>Metadata]
        HELM_TPL[templates/<br/>deployment.yaml<br/>service.yaml]
        HELM_VAL[values.yaml<br/>Default Values]
        HELM_DEV[environments/dev/<br/>values.yaml]
        HELM_PROD[environments/prod/<br/>values.yaml]
        
        HELM_CHART --> HELM_TPL
        HELM_VAL --> HELM_TPL
        HELM_DEV -->|overrides| HELM_VAL
        HELM_PROD -->|overrides| HELM_VAL
    end
    
    subgraph "Kustomize Approach"
        KUST_BASE[base/<br/>deployment.yaml<br/>service.yaml<br/>kustomization.yaml]
        KUST_DEV[environments/dev/<br/>kustomization.yaml<br/>patches/]
        KUST_PROD[environments/prod/<br/>kustomization.yaml<br/>patches/]
        
        KUST_BASE --> KUST_DEV
        KUST_BASE --> KUST_PROD
    end
    
    HELM_TPL -->|helm template| K8S_HELM[Kubernetes Manifests]
    KUST_DEV -->|kubectl kustomize| K8S_KUST_DEV[Dev Manifests]
    KUST_PROD -->|kubectl kustomize| K8S_KUST_PROD[Prod Manifests]
    
    classDef helm fill:#0f1689,stroke:#333,stroke-width:2px,color:#fff
    classDef kustomize fill:#326ce5,stroke:#333,stroke-width:2px,color:#fff
    classDef k8s fill:#ff9900,stroke:#333,stroke-width:2px,color:#fff
    
    class HELM_CHART,HELM_TPL,HELM_VAL,HELM_DEV,HELM_PROD helm
    class KUST_BASE,KUST_DEV,KUST_PROD kustomize
    class K8S_HELM,K8S_KUST_DEV,K8S_KUST_PROD k8s
```

#### 4. Kubernetes クラスター内部構成

```mermaid
graph TB
    subgraph "GKE Cluster"
        subgraph "argocd namespace"
            ARGO_CONTROLLER[ArgoCD Application<br/>Controller]
            ARGO_SERVER[ArgoCD Server<br/>UI/API]
            ARGO_REPO[ArgoCD Repo Server<br/>Git Sync]
        end
        
        subgraph "dev namespace"
            DEV_DEPLOY[dev-sample-app<br/>Deployment<br/>Replicas: 1]
            DEV_SVC[dev-sample-app-service<br/>Service: ClusterIP]
            DEV_PODS[Nginx Pods<br/>Resources: 50m CPU<br/>64Mi Memory]
        end
        
        subgraph "prod namespace"
            PROD_DEPLOY[prod-sample-app<br/>Deployment<br/>Replicas: 3]
            PROD_SVC[prod-sample-app-service<br/>Service: LoadBalancer]
            PROD_PODS[Nginx Pods<br/>Resources: 200m CPU<br/>256Mi Memory]
        end
    end
    
    subgraph "External"
        GIT[Git Repository]
        REGISTRY[Artifact Registry<br/>nginx:1.21]
        USERS[External Users]
    end
    
    GIT -->|GitOps| ARGO_REPO
    ARGO_CONTROLLER -->|manages| DEV_DEPLOY
    ARGO_CONTROLLER -->|manages| PROD_DEPLOY
    
    DEV_DEPLOY --> DEV_PODS
    DEV_SVC --> DEV_PODS
    PROD_DEPLOY --> PROD_PODS
    PROD_SVC --> PROD_PODS
    
    REGISTRY -->|pull images| DEV_PODS
    REGISTRY -->|pull images| PROD_PODS
    
    USERS -->|access| PROD_SVC
    
    classDef argocd fill:#ef7b4d,stroke:#333,stroke-width:2px,color:#fff
    classDef dev fill:#28a745,stroke:#333,stroke-width:2px,color:#fff
    classDef prod fill:#dc3545,stroke:#333,stroke-width:2px,color:#fff
    classDef external fill:#6c757d,stroke:#333,stroke-width:2px,color:#fff
    
    class ARGO_CONTROLLER,ARGO_SERVER,ARGO_REPO argocd
    class DEV_DEPLOY,DEV_SVC,DEV_PODS dev
    class PROD_DEPLOY,PROD_SVC,PROD_PODS prod
    class GIT,REGISTRY,USERS external
```

## 🚀 クイックスタート

### 1. 前提条件

以下のツールがインストールされていることを確認してください：
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

### 2. GCPプロジェクトの設定

```bash
# gcloud認証
gcloud auth login
gcloud auth application-default login

# プロジェクトを設定
gcloud config set project YOUR_PROJECT_ID
```

### 3. Terraform設定

```bash
# 設定ファイルをコピーして編集
cp gke-setup/terraform/terraform.tfvars.example gke-setup/terraform/terraform.tfvars

# YOUR_PROJECT_IDを実際のプロジェクトIDに変更
vim gke-setup/terraform/terraform.tfvars
```

### 4. GKEクラスターの作成

```bash
# 自動セットアップスクリプトを実行
./gke-setup/scripts/setup-gke.sh
```

### 5. ArgoCDのインストール

```bash
# ArgoCDをインストール
./gke-setup/scripts/install-argocd.sh
```

### 6. アプリケーションのデプロイ

```bash
# アプリケーションをデプロイ
./gke-setup/scripts/deploy-applications.sh
```

## 📊 構成の比較

| 項目 | Helm | Kustomize |
|------|------|-----------|
| **設定方法** | Values files | Patches |
| **テンプレート** | Go template | YAML merge |
| **環境差分** | `-f values.yaml` | Overlay |
| **複雑度** | 中程度 | シンプル |
| **再利用性** | 高い | 中程度 |

### Helm構成の特徴
- テンプレート化による柔軟性
- Values filesによる環境別設定
- パッケージ化と配布が容易

### Kustomize構成の特徴
- YAMLマニフェストベース
- Patchによる差分管理
- Kubernetesネイティブ

## 🔄 CI/CD パイプライン

GitHub Actionsを使用して以下を自動化：

- **Helmバリデーション**
  - `helm template` による構文チェック
  - 環境別設定のテスト
  - `helm lint` によるベストプラクティス確認

- **Kustomizeバリデーション** 
  - `kubectl kustomize` による構文チェック
  - 環境別オーバーレイのテスト

## 🌐 アクセス方法

### ArgoCD UI
```bash
# ポートフォワード
kubectl port-forward svc/argocd-server -n argocd 8080:443

# ブラウザで https://localhost:8080 にアクセス
# ユーザー名: admin
# パスワード: install-argocd.sh実行時に表示される
```

### アプリケーション
```bash
# dev環境のサービス確認
kubectl get services -n dev

# prod環境のサービス確認  
kubectl get services -n prod

# ポートフォワードでアクセス
kubectl port-forward -n dev svc/dev-sample-app-service 8081:80
```

## 🧹 クリーンアップ

```bash
# ArgoCD Applicationsを削除
kubectl delete -f argocd-applications/

# GKEクラスターを削除
cd gke-setup/terraform
terraform destroy

# 確認が求められるのでyesを入力
```

## 📚 参考リンク

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)