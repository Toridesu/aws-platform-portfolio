# AWS Platform Portfolio

## 概要

このリポジトリは、AWS上にコンテナアプリケーション基盤をTerraformで構築するポートフォリオです。

主目的は、アプリケーション開発ではなく、以下の設計・構築スキルを示すことです。

- TerraformによるInfrastructure as Code
- VPC / Public Subnet / Private Subnetのネットワーク設計
- Security Groupによる通信制御
- Docker化したNode.js APIのECR登録
- ECS Fargateによるコンテナ実行
- ALBによるHTTP公開とヘルスチェック
- VPC EndpointによるPrivate SubnetからのAWSサービス到達
- 検証後に `terraform destroy` で削除できる運用

## 構成

```mermaid
flowchart TB
  user["User / Browser"]

  subgraph aws["AWS ap-northeast-1"]
    subgraph vpc["VPC 10.0.0.0/16"]
      subgraph public["Public Subnets"]
        alb["Application Load Balancer\nHTTP :80"]
      end

      subgraph private["Private Subnets"]
        ecs["ECS Fargate Service\nTask desired_count 0 or 1"]
        app["Dockerized Node.js API\nContainer :3000"]
      end

      subgraph endpoints["VPC Endpoints"]
        ecr_api["ECR API\nInterface Endpoint"]
        ecr_dkr["ECR Docker\nInterface Endpoint"]
        logs_ep["CloudWatch Logs\nInterface Endpoint"]
        s3_ep["S3\nGateway Endpoint"]
      end
    end

    ecr["Amazon ECR\nDocker Image Repository"]
    logs["CloudWatch Logs"]
  end

  local["Local Docker Build"]

  user -->|"HTTP :80"| alb
  alb -->|"HTTP :3000"| ecs
  ecs --> app

  local -->|"docker push"| ecr
  ecs -->|"pull image"| ecr_dkr
  ecs -->|"ECR auth/API"| ecr_api
  ecs -->|"image layers"| s3_ep
  ecs -->|"application logs"| logs_ep

  ecr_dkr --> ecr
  ecr_api --> ecr
  logs_ep --> logs
```

ECSタスクはPrivate Subnetに配置し、外部から直接アクセスできない構成にしています。
外部公開の入口はPublic Subnet上のALBに限定しています。

Private Subnet上のECSタスクがECRからイメージをpullし、CloudWatch Logsへログを送信できるように、NAT GatewayではなくVPC Endpointを利用しています。

## 使用技術

- AWS
- Terraform
- Docker
- Amazon ECR
- Amazon ECS Fargate
- Application Load Balancer
- VPC Endpoint
- CloudWatch Logs
- Node.js
- Express

## ディレクトリ構成

```text
.
├── app/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       └── index.js
├── docs/
│   ├── architecture.md
│   ├── cost.md
│   ├── operations.md
│   └── security.md
└── infra/
    ├── environments/
    │   └── dev/
    │       ├── main.tf
    │       ├── outputs.tf
    │       ├── terraform.tfvars.example
    │       └── variables.tf
    └── modules/
        ├── ecs/
        ├── endpoints/
        ├── network/
        └── security/
```

## アプリケーション

検証用のNode.js APIを用意しています。

エンドポイント:

- `GET /`
- `GET /health`

`/health` はALBのヘルスチェックでも利用します。

## ローカル実行

```bash
cd app
npm install
npm start
```

確認:

```bash
curl http://localhost:3000/health
```

## Docker実行

```bash
cd app
docker build -t aws-platform-api .
docker run --rm -p 3000:3000 aws-platform-api
```

確認:

```bash
curl http://localhost:3000/health
```

## Terraform

dev環境のTerraformは以下にあります。

```bash
cd infra/environments/dev
```

初期化:

```bash
terraform init
```

フォーマット:

```bash
terraform fmt -recursive ../..
```

検証:

```bash
terraform validate
```

差分確認:

```bash
terraform plan
```

作成:

```bash
terraform apply
```

削除:

```bash
terraform destroy
```

## CI

GitHub Actionsで以下の検証を行います。

- Node.js依存関係のインストール
- アプリケーション構文チェック
- Docker image build
- Terraform format check
- Terraform init
- Terraform validate

現時点では、AWSへの自動デプロイは行いません。
GitHub Actions OIDC用のIAM Roleは作成済みです。
次の段階で、ECR pushとECS deployのworkflowを追加します。

## ECSタスク起動確認

この構成では、Fargateの不要な課金を避けるため、dev環境のECS Serviceは通常 `desired_count = 0` にしています。

API疎通を確認する場合のみ、一時的にタスクを1台起動します。

```bash
terraform apply -auto-approve -var ecs_desired_count=1
```

ALB DNS名を確認します。

```bash
terraform output -raw alb_dns_name
```

ALB経由でAPIを確認します。

```bash
curl http://$(terraform output -raw alb_dns_name)/health
```

確認後はタスク数を0に戻します。

```bash
terraform apply -auto-approve
```

## 設計上のポイント

### Public / Private Subnet分離

ALBはPublic Subnetに配置し、ECSタスクはPrivate Subnetに配置しています。

これにより、外部公開する入口をALBに限定し、アプリケーション本体への直接アクセスを防ぎます。

### Security Group制御

通信は以下のように制限しています。

```text
Internet -> ALB : TCP 80
ALB -> ECS Task : TCP 3000
ECS Task -> VPC Endpoint : TCP 443
```

ECSタスクはALBからの通信のみ受ける設計です。

### VPC Endpoint

Private Subnet上のECSタスクがECRとCloudWatch Logsへ到達するため、以下を作成しています。

- ECR API Interface Endpoint
- ECR Docker Interface Endpoint
- CloudWatch Logs Interface Endpoint
- S3 Gateway Endpoint

NAT Gatewayはコストが高くなりやすいため、今回の学習用構成では採用していません。

### ECR削除

ECRリポジトリ内にDockerイメージが残っていると、通常は `terraform destroy` で削除に失敗します。

このリポジトリでは、学習環境を確実に削除できるように以下を設定しています。

```hcl
force_delete = true
```

## 実施済みの検証

- Terraform `fmt`
- Terraform `init`
- Terraform `validate`
- Terraform `plan`
- Terraform `apply`
- Docker image build
- ECR push
- ECS Fargate task起動
- ALB Target Group health check
- ALB経由の `/health` 疎通確認
- ECS desired countを0へ戻す運用
- `terraform destroy`
- GitHub Actionsによる検証CI
- GitHub Actions OIDC IAM Role module
- GitHub Actions OIDC IAM Role作成

## 関連ドキュメント

- [アーキテクチャ](docs/architecture.md)
- [セキュリティ](docs/security.md)
- [コスト](docs/cost.md)
- [運用](docs/operations.md)

## 今後の改善候補

- GitHub ActionsによるCI/CD
- GitHub ActionsによるECR push / ECS deploy
- CloudWatch Alarm追加
- ECS Execの検討
- HTTPS化
- WAF追加
- IAM権限の最小化
- ECRライフサイクルポリシー
- RDSをPrivate Subnetに追加
