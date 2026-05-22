# セキュリティ

このドキュメントには、セキュリティ設計と実装時のメモをまとめます。

## 現在の対象範囲

現在は、ALBとECS Task間のSecurity Group設計をTerraformで定義しています。

まだIAM、Secrets Manager、WAF、GuardDuty、Security Hub、ECR image scanは実装していません。

## Security Group設計

現在の通信方針は以下です。

```text
Internet
  |
  | HTTP :80
  v
ALB Security Group
  |
  | TCP :3000
  v
ECS Security Group
```

## ALB Security Group

ALB用Security Groupは、インターネットからHTTP通信を受けます。

許可するインバウンド:

```text
0.0.0.0/0 -> TCP 80
```

理由:

- 今後ALBをPublic Subnetに配置するため
- ブラウザや外部クライアントからAPIへ到達する入口になるため

許可するアウトバウンド:

```text
ALB Security Group -> ECS Security Group TCP 3000
```

理由:

- ALBからECS Taskへアプリケーション通信を流すため
- 送信先をECS用Security Groupに限定することで、不要な送信先を広げないため

## ECS Security Group

ECS Task用Security Groupは、ALBからの通信だけを受けます。

許可するインバウンド:

```text
ALB Security Group -> ECS Security Group TCP 3000
```

理由:

- ECS Taskをインターネットへ直接公開しないため
- アプリケーションへの入口をALBに集約するため
- Private Subnetに配置する前提と整合するため

許可するアウトバウンド:

```text
ECS Security Group -> 0.0.0.0/0 all traffic
```

理由:

- ECS TaskがECR、CloudWatch Logs、外部APIなどへ通信する可能性があるため
- 現時点ではNAT GatewayやVPC Endpointをまだ導入していないため

今後の改善:

- 必要な通信先に応じてECSのアウトバウンドを絞る
- HTTPS化後はALBのインバウンドをTCP 443中心にする

## VPC Endpoint Security Group

Interface VPC Endpoint用のSecurity Groupを追加しています。

許可するインバウンド:

```text
ECS Security Group -> VPC Endpoint Security Group TCP 443
```

理由:

- ECS TaskがECR API、ECR Docker、CloudWatch LogsへPrivateLink経由で通信するため
- Endpoint側の入口をECS Taskに限定するため

VPC EndpointはPrivate Subnet内のECS TaskがAWSサービスへ到達するための経路です。

今回追加しているInterface Endpoint:

```text
ecr.api
ecr.dkr
logs
```

S3はGateway Endpointとして追加しています。ECRのイメージレイヤー取得にS3が関係するためです。

## 現時点で実装しないもの

### WAF

WAFはALB作成後に関連付けます。

現時点ではALB本体がまだないため、Security Group設計を先に定義しています。

### IAM最小権限

IAM RoleはECS Task DefinitionやCI/CDを作る段階で設計します。

現時点ではSecurity Groupによるネットワーク境界を先に定義しています。

### Secrets Manager

Secrets Managerは、RDSや外部APIキーを扱う段階で追加します。

現時点ではDB接続がないため未実装です。

## Terraform module構成

Security Groupは以下のmoduleで管理します。

```text
infra/modules/security/
  main.tf
  variables.tf
  outputs.tf
```

dev環境では以下のように呼び出します。

```text
module "security" {
  source = "../../modules/security"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.network.vpc_id
  container_port = 3000
}
```
