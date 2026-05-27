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

```text
Internet
  |
  | HTTP :80
  v
Application Load Balancer
  |
  | HTTP :3000
  v
ECS Fargate Task
  |
  v
Dockerized Node.js API
```

ECSタスクはPrivate Subnetに配置し、外部から直接アクセスできない構成にしています。
外部公開の入口はPublic Subnet上のALBに限定しています。

Dockerイメージの流れは以下です。

```text
Local Docker Build
  |
  v
Amazon ECR
  |
  v
ECS Fargate Task
```

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

## 関連ドキュメント

- [アーキテクチャ](docs/architecture.md)
- [セキュリティ](docs/security.md)
- [コスト](docs/cost.md)
- [運用](docs/operations.md)

## 今後の改善候補

- GitHub ActionsによるCI/CD
- README用の構成図追加
- CloudWatch Alarm追加
- ECS Execの検討
- HTTPS化
- WAF追加
- IAM権限の最小化
- ECRライフサイクルポリシー
- RDSをPrivate Subnetに追加
