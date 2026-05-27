# アーキテクチャ

このドキュメントでは、現在のAWS構成、設計意図、採用理由、トレードオフをまとめます。

## 対象範囲

現在のTerraformでは、以下のAWS基盤を定義しています。

- VPC
- Public Subnet
- Private Subnet
- Internet Gateway
- Route Table
- Security Group
- VPC Endpoint
- ECR
- CloudWatch Logs
- ECS Cluster
- ECS Task Definition
- ECS Service
- Application Load Balancer
- Target Group
- Listener
- ECS Task Execution Role

RDS、WAF、GuardDuty、Security Hub、HTTPS化、CI/CDはまだ未実装です。

## 全体構成

```text
Internet
  |
  | HTTP :80
  v
Application Load Balancer
  |
  | HTTP :3000
  v
ECS Service
  |
  v
Fargate Task
  |
  v
Dockerized Node.js API
```

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

ECS TaskはPrivate Subnetに配置します。
外部からの入口はPublic Subnet上のALBに限定します。

## ネットワーク構成

```text
VPC: 10.0.0.0/16

Public Subnet:
  - 10.0.0.0/24   ap-northeast-1a
  - 10.0.1.0/24   ap-northeast-1c

Private Subnet:
  - 10.0.10.0/24  ap-northeast-1a
  - 10.0.11.0/24  ap-northeast-1c

Internet Gateway:
  - VPCにアタッチ

Public Route Table:
  - 0.0.0.0/0 -> Internet Gateway
  - Public Subnet 2つに関連付け

Private Route Table:
  - Private Subnetごとに作成
  - S3 Gateway Endpointを関連付け
```

## 設計意図

### VPC

VPCはAWS上に作る仮想ネットワーク全体の枠です。

CIDRは以下です。

```text
10.0.0.0/16
```

`/16` にしている理由は、Public Subnet、Private Subnet、VPC Endpoint、将来のRDSなどを追加してもIPアドレス設計に余裕を持たせるためです。

また、以下を有効化しています。

```text
enable_dns_support   = true
enable_dns_hostnames = true
```

ECS、ALB、VPC Endpoint、RDSなどを組み合わせる構成では、AWS内部のDNS名前解決が重要になるためです。

### Public Subnet

Public Subnetは、インターネットから到達可能な入口を配置するサブネットです。

今回の構成では、ALBをPublic Subnetに配置します。

```text
10.0.0.0/24  ap-northeast-1a
10.0.1.0/24  ap-northeast-1c
```

2つのAvailability Zoneに分けている理由は、単一AZ障害に対する耐性を持たせるためです。

Public Subnetには以下のルートがあります。

```text
0.0.0.0/0 -> Internet Gateway
```

これにより、ALBがインターネットからHTTPリクエストを受けられます。

### Private Subnet

Private Subnetは、インターネットから直接到達させたくないリソースを配置するサブネットです。

今回の構成では、ECS Fargate TaskをPrivate Subnetに配置します。

```text
10.0.10.0/24  ap-northeast-1a
10.0.11.0/24  ap-northeast-1c
```

ECS TaskにはPublic IPを付与しません。
そのため、外部からECS Taskへ直接アクセスすることはできません。

アプリケーションへのアクセスは、必ずALBを経由します。

## Security Group設計

通信経路は以下のように制御しています。

```text
Internet -> ALB Security Group : TCP 80
ALB Security Group -> ECS Security Group : TCP 3000
ECS Security Group -> VPC Endpoint Security Group : TCP 443
```

### ALB Security Group

ALBは外部公開の入口です。

許可する通信:

```text
Inbound:
  0.0.0.0/0 -> TCP 80

Outbound:
  ALB Security Group -> ECS Security Group TCP 3000
```

ALBからECS Taskへの通信先はSecurity Groupで限定しています。

### ECS Security Group

ECS TaskはPrivate Subnetに配置し、ALBからの通信だけを受けます。

許可する通信:

```text
Inbound:
  ALB Security Group -> ECS Security Group TCP 3000

Outbound:
  0.0.0.0/0 all traffic
```

ECS TaskのOutboundは現時点では広めに許可しています。
ただし、Private SubnetにNAT Gatewayを置いていないため、実際のAWSサービス到達はVPC Endpoint経由が中心です。

### VPC Endpoint Security Group

Interface VPC Endpointには専用Security Groupを付与します。

許可する通信:

```text
Inbound:
  ECS Security Group -> VPC Endpoint Security Group TCP 443

Outbound:
  0.0.0.0/0 all traffic
```

ECS TaskからECR API、ECR Docker Registry、CloudWatch LogsへPrivateLink経由で通信するために必要です。

## VPC Endpoint設計

ECS TaskはPrivate Subnetに配置されており、NAT Gatewayを使っていません。

そのため、ECS TaskがECRからDockerイメージをpullし、CloudWatch Logsへログを送信するにはVPC Endpointが必要です。

定義しているEndpoint:

```text
Interface Endpoint:
  - com.amazonaws.ap-northeast-1.ecr.api
  - com.amazonaws.ap-northeast-1.ecr.dkr
  - com.amazonaws.ap-northeast-1.logs

Gateway Endpoint:
  - com.amazonaws.ap-northeast-1.s3
```

ECRのイメージレイヤー取得にはS3への到達が必要になるため、S3 Gateway Endpointも追加しています。

NAT Gatewayを採用しなかった理由:

- 学習用環境では継続課金が大きくなりやすい
- 今回必要な通信先はECRとCloudWatch Logsが中心
- VPC Endpointの方が通信先をAWSサービスに限定しやすい
- Private Subnet構成を維持したままECS Taskを起動できる

トレードオフ:

- Interface Endpointにも時間課金はある
- 外部APIへ出る必要がある場合はNAT Gatewayなど別経路が必要
- Endpoint数が増えると構成が複雑になる

## ECS / ALB設計

### ECR

ECRはDockerイメージの保存先です。

ローカルでビルドしたDockerイメージをECRにpushし、ECS Task Definitionから参照します。

```text
<account_id>.dkr.ecr.ap-northeast-1.amazonaws.com/aws-platform-portfolio-dev-api:latest
```

学習環境を削除しやすくするため、ECRリポジトリには以下を設定しています。

```hcl
force_delete = true
```

これにより、Dockerイメージが残っていても `terraform destroy` でECRリポジトリを削除できます。

### ECS Cluster

ECS Clusterは、ECS ServiceやTaskをまとめる論理的な単位です。

今回はFargateを使うため、EC2インスタンスの管理は行いません。

### ECS Task Definition

Task Definitionは、コンテナをどう起動するかを定義します。

主な設定:

- Dockerイメージ
- CPU
- Memory
- Container Port
- CloudWatch Logs設定
- Task Execution Role

今回のAPIはコンテナ内で3000番ポートをListenします。

### ECS Service

ECS Serviceは、指定した数のTaskを維持する仕組みです。

dev環境では、通常時の `desired_count` を `0` にしています。

理由:

- Fargateの不要な継続課金を避けるため
- 必要なときだけAPI疎通確認を行うため

疎通確認時だけ以下で1台起動します。

```bash
terraform apply -auto-approve -var ecs_desired_count=1
```

確認後は、変数指定なしでapplyして `desired_count = 0` に戻します。

```bash
terraform apply -auto-approve
```

### ALB

ALBはインターネットからのHTTPリクエストを受け、ECS Taskへ転送します。

```text
ALB Listener : HTTP 80
Target Group : HTTP 3000
Health Check : /health
```

ALB Target GroupはECS TaskをIPターゲットとして登録します。
ECS Taskが起動するとTarget Groupに登録され、`/health` が成功すると `healthy` になります。

## Terraform module構成

Terraformは以下の構成です。

```text
infra/
  environments/
    dev/
      main.tf
      variables.tf
      outputs.tf
      terraform.tfvars.example
  modules/
    network/
      main.tf
      variables.tf
      outputs.tf
    security/
      main.tf
      variables.tf
      outputs.tf
    endpoints/
      main.tf
      variables.tf
      outputs.tf
    ecs/
      main.tf
      variables.tf
      outputs.tf
```

### environments/dev

dev環境固有のprovider設定、変数、module呼び出し、outputsを持ちます。

### modules/network

以下を定義します。

- VPC
- Public Subnet
- Private Subnet
- Internet Gateway
- Public Route Table
- Private Route Table
- Route Table Association

### modules/security

以下を定義します。

- ALB Security Group
- ECS Security Group
- VPC Endpoint Security Group
- Security Group Rules

### modules/endpoints

以下を定義します。

- ECR API Interface Endpoint
- ECR Docker Interface Endpoint
- CloudWatch Logs Interface Endpoint
- S3 Gateway Endpoint

### modules/ecs

以下を定義します。

- ECR Repository
- CloudWatch Log Group
- ECS Cluster
- ECS Task Execution Role
- ECS Task Definition
- ECS Service
- ALB
- Target Group
- Listener

## 検証済み内容

以下を実施済みです。

- `terraform fmt`
- `terraform init`
- `terraform validate`
- `terraform plan`
- `terraform apply`
- Docker image build
- ECR push
- ECS Task起動
- ALB Target Groupのhealthy確認
- ALB経由の `/health` 疎通確認
- ECS desired countを0へ戻す確認
- `terraform destroy`
- ECR削除時の `force_delete = true` 対応

## 現時点で作らないもの

### NAT Gateway

今回の構成ではNAT Gatewayを作っていません。

理由:

- 学習用環境では料金が高くなりやすい
- ECS Taskが必要とするAWSサービス通信はVPC Endpointで満たせる
- Private Subnet構成を保ちながらコストを抑えたい

外部APIへPrivate Subnetからアクセスする要件が出た場合は、NAT Gatewayを検討します。

### RDS

現時点ではRDSを作っていません。

追加する場合は、Private Subnetに配置し、ECS Security Groupからのみ接続できるようにします。

### HTTPS / ACM

現時点ではALBのHTTP 80番のみです。

公開用途に近づける場合は、ACM証明書を使ってHTTPS化します。

### WAF / GuardDuty / Security Hub

現時点では未実装です。

ALB公開後の防御、検知、セキュリティ可視化を強化する段階で追加します。

## 今後の改善候補

- GitHub ActionsによるCI/CD
- HTTPS化
- CloudWatch Alarm
- ECS Exec
- IAM権限の最小化
- ECRライフサイクルポリシー
- README用の構成図画像
- RDS追加
- WAF追加
