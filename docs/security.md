# セキュリティ

このドキュメントでは、現在のAWS構成におけるセキュリティ設計、実装済みの対策、未実装の改善候補をまとめます。

## 対象範囲

現在のTerraformでは、以下のセキュリティ要素を定義しています。

- ALB用Security Group
- ECS Task用Security Group
- VPC Endpoint用Security Group
- Security Group Rule
- ECS Task Execution Role
- ECR image scan on push
- CloudWatch Logs
- ECS Container Insights
- GitHub Actions用OIDC IAM Role module

以下はまだ未実装です。

- HTTPS / ACM
- WAF
- Secrets Manager
- GuardDuty
- Security Hub
- ECS Exec

## 通信設計

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
  |
  | TCP :443
  v
VPC Endpoint Security Group

ECS Security Group
  |
  | TCP :443
  v
S3 managed prefix list
```

アプリケーション本体であるECS TaskはPrivate Subnetに配置します。
外部から直接ECS Taskへアクセスする経路は作っていません。

外部公開の入口はALBのみです。

## ALB Security Group

ALB用Security Groupは、インターネットからHTTP通信を受け付けます。

許可するインバウンド:

```text
0.0.0.0/0 -> TCP 80
```

許可するアウトバウンド:

```text
ALB Security Group -> ECS Security Group TCP 3000
```

設計意図:

- 外部公開する入口をALBに限定する
- ECS Taskへ直接アクセスさせない
- ALBからECSへの通信先をSecurity Groupで限定する

現時点ではHTTP 80番のみです。
公開用途に近づける場合は、ACM証明書を使ってHTTPS 443番へ移行します。

## ECS Security Group

ECS Task用Security Groupは、ALBからのアプリケーション通信だけを受けます。

許可するインバウンド:

```text
ALB Security Group -> ECS Security Group TCP 3000
```

許可するアウトバウンド:

```text
ECS Security Group -> VPC Endpoint Security Group TCP 443
ECS Security Group -> S3 managed prefix list TCP 443
```

設計意図:

- ECS TaskをPrivate Subnetに配置する
- アプリケーションへの入口をALBに集約する
- ECS Taskへインターネットから直接到達できないようにする

ECSのアウトバウンドは、ECR API、ECR Docker Registry、CloudWatch Logs用のInterface Endpointと、ECR image layer取得で必要になるS3 managed prefix listへのHTTPS通信に絞っています。

今後の改善候補:

- 外部API接続が必要になった場合、NAT GatewayやPrivateLinkを再検討する

## VPC Endpoint Security Group

Interface VPC Endpoint用のSecurity Groupを定義しています。

許可するインバウンド:

```text
ECS Security Group -> VPC Endpoint Security Group TCP 443
```

許可するアウトバウンド:

```text
VPC Endpoint Security Group -> 0.0.0.0/0 all traffic
```

設計意図:

- ECR API、ECR Docker Registry、CloudWatch Logsへの通信をPrivateLink経由にする
- Interface Endpointの入口をECS Taskに限定する
- NAT GatewayなしでPrivate Subnet上のECS Taskを起動できるようにする

対象のInterface Endpoint:

```text
ecr.api
ecr.dkr
logs
```

S3はGateway Endpointとして追加しています。
ECRのイメージレイヤー取得でS3への到達が必要になるためです。

## IAM

現在はECS Task Execution Roleを作成しています。

このRoleは、ECSがタスク起動時に以下を行うために使います。

- ECRからDockerイメージをpullする
- CloudWatch Logsへログを書き込む

AWS管理ポリシーは使わず、Terraformで定義したカスタムポリシーを付与しています。

許可する権限:

```text
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:BatchGetImage
ecr:GetDownloadUrlForLayer
logs:CreateLogStream
logs:PutLogEvents
```

権限範囲:

- `ecr:GetAuthorizationToken` はAWS仕様上Resourceを `*` にする必要がある
- image pull権限はアプリケーション用ECR Repositoryに限定する
- logs書き込み権限はアプリケーション用CloudWatch Log Group配下に限定する

設計意図:

- アプリケーションコンテナではなく、ECSのタスク起動処理に必要な権限を付与する
- ECR pullとCloudWatch Logs出力を可能にする
- ECS Taskが任意のECR RepositoryやLog Groupへアクセスできる範囲を減らす

今後、アプリケーションがAWSサービスへアクセスする場合は、Task Roleを別途作成します。
Task Execution RoleとTask Roleは役割が異なります。

```text
Task Execution Role:
  ECSがコンテナを起動するために使う

Task Role:
  コンテナ内のアプリケーションがAWS APIを呼ぶために使う
```

## ECR

ECRリポジトリでは、push時のイメージスキャンを有効化しています。

```hcl
image_scanning_configuration {
  scan_on_push = true
}
```

また、学習環境を確実に削除できるように以下も設定しています。

```hcl
force_delete = true
```

`force_delete = true` により、Dockerイメージが残っていても `terraform destroy` でECRリポジトリを削除できます。

セキュリティ観点では、今後以下を検討します。

- ECRライフサイクルポリシー
- イメージタグ運用の改善
- `latest` ではなくGit SHAなどの固定タグ利用
- 脆弱性スキャン結果の確認フロー

## ログと監視

ECS TaskのログはCloudWatch Logsへ送信します。

Log Groupの保持期間は変数で管理しており、dev環境では短めに設定します。
学習環境では不要なログ保存コストを避けるためです。

ECS ClusterではContainer Insightsを有効化しています。

```hcl
setting {
  name  = "containerInsights"
  value = "enabled"
}
```

CloudWatch Alarmで以下を監視します。

- ALB 5xxエラー
- Target Group unhealthy host

dev環境は通常 `desired_count = 0` のため、ECS Taskが0台であること自体は異常として扱いません。

今後の改善候補:

- SNSによるAlarm通知
- CloudWatch Logsのエラー文字列監視

## 現時点で未実装のセキュリティ項目

### HTTPS / ACM

現時点ではALB ListenerはHTTP 80番のみです。

公開用途に近づける場合は、ACMで証明書を発行し、ALB ListenerをHTTPS 443番にします。

### WAF

WAFは未実装です。

ALBをインターネット公開する場合、以下のような保護を検討します。

- AWS Managed Rules
- IP制限
- レート制限
- SQL injection / XSS対策ルール

### Secrets Manager

現時点ではDB接続情報やAPIキーを扱っていないため、Secrets Managerは未実装です。

RDSや外部APIを追加する場合は、環境変数へ直接秘密情報を置かず、Secrets ManagerまたはSSM Parameter Storeを使います。

### GuardDuty / Security Hub

検知・可視化系のセキュリティサービスは未実装です。

今後、本番に近い構成へ進める場合に追加候補になります。

### GitHub Actions OIDC

GitHub Actions OIDC用のIAM RoleはTerraformで作成します。

```hcl
enable_github_oidc = true
github_repository  = "Toridesu/aws-platform-portfolio"
github_branch      = "main"
```

このRoleは、長期Access Keyを使わず、GitHub ActionsからOIDCで一時認証情報を取得するためのものです。
`terraform destroy` 後はRoleも削除されるため、Deploy workflowを再実行する前に `terraform apply` で再作成します。

現在想定している権限は以下です。

- ECRへのDocker image push
- ECS Serviceのdescribe/update

Terraform apply用の広い権限ではなく、既存ECS Serviceを更新するdeploy用途に絞っています。

Deploy workflowは手動実行にしています。
push時に自動でAWSへ反映するのではなく、明示的に実行した場合だけECR pushとECS deployを行います。

## セキュリティ設計として説明すべきポイント

面接やレビューでは、以下を説明できることが重要です。

- ALBだけを外部公開している
- ECS TaskはPrivate Subnetに配置している
- ECS TaskはALBからの通信だけを受ける
- ECS Taskのアウトバウンドも必要なAWSサービス通信に絞っている
- ECR / CloudWatch Logsへの到達はVPC Endpoint経由にしている
- NAT Gatewayを使わず、必要なAWSサービスへの通信に絞っている
- Task Execution RoleとTask Roleの違いを理解している
- ECS Task Execution Roleの権限をECR pullとCloudWatch Logs出力に限定している
- ECR image scanを有効化している
- destroy時のECR削除問題に対応している
- HTTPS、WAF、Secrets Managerなど未実装項目も認識している
- GitHub Actionsでは長期Access KeyではなくOIDCを使う方針にしている

## Terraform module構成

Security Groupは以下のmoduleで管理します。

```text
infra/modules/security/
  main.tf
  variables.tf
  outputs.tf
```

ECR、IAM Role、CloudWatch Logs、ECS関連のセキュリティ設定は以下のmoduleで管理します。

```text
infra/modules/ecs/
  main.tf
  variables.tf
  outputs.tf
```

dev環境では以下のように呼び出します。

```hcl
module "security" {
  source = "../../modules/security"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.network.vpc_id
  container_port = 3000
}
```
