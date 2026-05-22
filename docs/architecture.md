# アーキテクチャ

このドキュメントには、AWS構成、設計意図、採用した構成の理由、トレードオフをまとめます。

## 現在の対象範囲

現在はPhase 2として、AWSネットワークの土台をTerraformで定義しています。

現在は、ネットワーク、Security Group、VPC Endpoint、ECR、ECS/Fargate、ALBの土台をTerraformで定義しています。

RDS、WAF、GuardDutyなどはまだ作成していません。

## ネットワーク構成

現在のネットワーク構成は以下です。

```text
VPC: 10.0.0.0/16

Public Subnet:
  - 10.0.0.0/24  ap-northeast-1a
  - 10.0.1.0/24  ap-northeast-1c

Private Subnet:
  - 10.0.10.0/24  ap-northeast-1a
  - 10.0.11.0/24  ap-northeast-1c

Internet Gateway:
  - VPCにアタッチ

Public Route Table:
  - 0.0.0.0/0 -> Internet Gateway
  - Public Subnet 2つに関連付け
```

## 設計意図

### VPC

VPCは、AWS上に作るネットワーク全体の大枠です。

今回のCIDRは以下です。

```text
10.0.0.0/16
```

この範囲を使うことで、今後ECS、RDS、VPC Endpointなどを追加してもサブネットを拡張しやすくしています。

また、以下を有効化しています。

```text
enable_dns_support   = true
enable_dns_hostnames = true
```

これは、AWS内部でDNS名前解決を使いやすくするためです。ECS、ALB、RDSなどを組み合わせる構成では、DNS解決を有効にしておくのが基本です。

### Public Subnet

Public Subnetは、インターネットから到達可能な入口を置くためのサブネットです。

今回の構成では、将来的にALBをPublic Subnetに配置する想定です。

```text
10.0.0.0/24  ap-northeast-1a
10.0.1.0/24  ap-northeast-1c
```

2つのAvailability Zoneに分けている理由は、単一AZ障害に対する耐性を持たせるためです。

Public Subnetでは以下を有効にしています。

```text
map_public_ip_on_launch = true
```

これは、このサブネットで起動したリソースにパブリックIPを自動付与する設定です。

ただし、今回の最終構成では、アプリ本体をPublic Subnetに直接置くのではなく、ALBをPublic Subnetに置き、ECS TaskはPrivate Subnetに置く方針です。

### Private Subnet

Private Subnetは、インターネットから直接到達させたくないリソースを置くためのサブネットです。

今回の構成では、将来的にECS TaskやRDSをPrivate Subnetに配置する想定です。

```text
10.0.10.0/24  ap-northeast-1a
10.0.11.0/24  ap-northeast-1c
```

Private Subnetでは、パブリックIPを自動付与しません。

この設計により、外部公開する入口と内部で保護するリソースを分離できます。

### Internet Gateway

Internet Gatewayは、VPCとインターネットを接続するためのリソースです。

Public Subnetからインターネットへ通信するために、VPCへアタッチしています。

### Public Route Table

Public Route Tableには、以下のルートを定義しています。

```text
0.0.0.0/0 -> Internet Gateway
```

このルートにより、Public Subnet内のリソースはインターネットへ通信できます。

このRoute Tableは、2つのPublic Subnetに関連付けています。

## 現時点で作らないもの

### NAT Gateway

現時点ではNAT Gatewayを作っていません。

理由は、NAT Gatewayは学習用環境としてはコストが高くなりやすいためです。

Private Subnet内のECS TaskがECRや外部APIへ通信する必要が出た段階で、以下を比較して判断します。

- NAT Gatewayを使う
- VPC Endpointを使う
- 学習用として一時的にPublic Subnet配置を許容する

本番想定では、Private Subnetから外部へ出る設計が必要になるため、NAT GatewayまたはVPC Endpointの検討は必須です。

### RDS

現時点ではRDSを作っていません。

RDSは継続課金が発生するため、まずはネットワークとECS/Fargateの土台を作った後に追加します。

追加する場合は、Private Subnetに配置し、Security GroupでECS Taskからのみ接続できるようにします。

## Terraform module構成

Terraformは以下の構成にしています。

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

`environments/dev` は、dev環境固有の値やprovider設定を持ちます。

`modules/network` は、VPCやSubnetなどの再利用可能なネットワーク定義を持ちます。

`modules/security` は、ALB用Security GroupとECS Task用Security Groupを持ちます。

`modules/endpoints` は、Private Subnet内のECS TaskがECRとCloudWatch Logsへ到達するためのVPC Endpointを持ちます。

`modules/ecs` は、ECR、CloudWatch Logs、ECS Cluster、Task Definition、ECS Service、ALB、Target Group、Listenerを持ちます。

この分割により、将来的に `stg` や `prod` を追加する場合でも、同じmoduleを再利用できます。

## ECS / ALB構成

ECS / ALBの構成は以下です。

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
```

ALBはPublic Subnetに配置します。

ECS TaskはPrivate Subnetに配置します。

Task Definitionでは、ECRの `latest` タグのイメージを参照します。

```text
ECR Repository URL: <repository_url>:latest
Container Port: 3000
Health Check Path: /health
```

## 現時点のECS desired_count

dev環境では、ECS Serviceの `desired_count` をデフォルトで `0` にしています。

理由:

- まだECRにDockerイメージをpushしていないため
- Private SubnetからECRやCloudWatch Logsへ出るためのNAT GatewayまたはVPC Endpointをまだ作っていないため
- 不要なFargate起動コストを避けるため

今後、ECRへDockerイメージをpushし、Private Subnetのアウトバウンド経路を設計した後に `desired_count = 1` へ変更します。

## VPC Endpoint構成

ECS TaskはPrivate Subnetに配置するため、インターネットへ直接出られません。

ECRからイメージをpullし、CloudWatch Logsへログを送るため、以下のVPC Endpointを定義しています。

```text
Interface Endpoint:
  - ecr.api
  - ecr.dkr
  - logs

Gateway Endpoint:
  - s3
```

ECRのイメージレイヤー取得にはS3への到達が必要になるため、S3 Gateway Endpointも追加しています。

Interface Endpointには専用Security Groupを付与し、ECS Task用Security GroupからのHTTPS通信のみ受ける設計です。

## terraform planで確認した作成予定

`terraform plan` では、以下の結果を確認しています。

```text
Plan: 9 to add, 0 to change, 0 to destroy.
```

作成予定リソース:

```text
aws_vpc.this
aws_internet_gateway.this
aws_subnet.public[0]
aws_subnet.public[1]
aws_subnet.private[0]
aws_subnet.private[1]
aws_route_table.public
aws_route_table_association.public[0]
aws_route_table_association.public[1]
```

現時点では `terraform apply` は実行していません。
