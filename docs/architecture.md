# アーキテクチャ設計

## 目的

この構成は、Docker化したAPIをAWS上で安全に公開し、TerraformとGitHub Actionsで再現可能に管理することを目的としています。

対象は短時間の検証を前提としたdev環境です。本番相当の可用性を意識しつつ、継続課金を抑える運用を採用しています。

![AWSコンテナ基盤の構成図](assets/architecture-overview.png)

## 要件

- アプリケーションをコンテナとして実行する
- アプリケーションへ直接インターネットから接続させない
- 2つのAvailability Zoneを使用する
- インフラをTerraformで再作成・削除できる
- GitHub Actionsから長期Access Keyを使わずデプロイする
- ログ、死活監視、コスト監視を実装する
- 検証後にAWSリソースを削除できる

## リソース配置

| レイヤー | 主なリソース | 配置・役割 |
| --- | --- | --- |
| 外部公開 | Application Load Balancer | Public Subnetに配置し、HTTPリクエストを受け付ける |
| アプリケーション | ECS Fargate Service / Task | Private Subnetに配置し、ALBからの通信だけを受ける |
| イメージ管理 | Amazon ECR | Docker imageを保存する |
| Private接続 | ECR API、ECR Docker、CloudWatch Logs、S3のVPC Endpoint | Private Subnetから必要なAWSサービスへ接続する |
| ログ・監視 | CloudWatch Logs / CloudWatch Alarm | アプリケーションログとALBの異常を確認する |
| CI/CD認証 | GitHub Actions OIDC IAM Role | GitHub Actionsへ一時的なAWS権限を付与する |
| コスト監視 | AWS Budgets | 月額コストの実績・予測をメール通知する |

## ネットワーク設計

```text
VPC: 10.0.0.0/16

Public Subnets:
  10.0.0.0/24   ap-northeast-1a
  10.0.1.0/24   ap-northeast-1c

Private Subnets:
  10.0.10.0/24  ap-northeast-1a
  10.0.11.0/24  ap-northeast-1c
```

ALBはPublic Subnet、ECS TaskはPrivate Subnetへ配置します。ECS TaskにはPublic IPを付与せず、外部公開の入口をALBに限定します。

通信経路は以下に制限しています。

```text
Internet -> ALB                         : TCP 80
ALB -> ECS Task                         : TCP 3000
ECS Task -> Interface VPC Endpoints     : TCP 443
ECS Task -> S3 managed prefix list      : TCP 443
```

## 主要な設計判断

### ECS Fargate

EC2インスタンスの管理を行わず、コンテナ実行基盤の設計と運用に集中するためFargateを採用しました。Task DefinitionではCPU、メモリ、コンテナポート、ログ出力先、Task Execution Roleを管理します。

dev環境では通常の `desired_count` を `0` とし、疎通確認時だけTaskを1台起動します。

### VPC Endpoint

Private Subnet上のECS TaskがECRからimageを取得し、CloudWatch Logsへログを送信するために以下を使用します。

- ECR API Interface Endpoint
- ECR Docker Interface Endpoint
- CloudWatch Logs Interface Endpoint
- S3 Gateway Endpoint

この構成は外部API接続を必要としないため、NAT Gatewayを採用していません。Interface Endpointにも時間課金があるため、NAT Gatewayとの優劣は稼働時間、AZ数、通信量によって変わります。

### GitHub Actions OIDC

GitHub ActionsはOIDCで一時認証情報を取得します。信頼対象をこのリポジトリの `main` ブランチに限定し、Deploy RoleにはECR pushと既存ECS Service更新に必要な権限だけを付与しています。

Deploy workflowは意図しないAWS反映と課金を避けるため、手動実行に限定しています。実行時はECS Taskを1台起動し、Serviceの安定化とALB経由の `/health` を確認した後、成功・失敗に関係なくTaskを0台へ戻します。

### 削除可能なdev環境

検証後に `terraform destroy` できることを運用要件としています。ECRはimageが残っていても削除できるよう `force_delete = true` を設定し、Lifecycle Policyで不要なimageも整理します。

## Terraform構成

```text
infra/
  environments/dev/   # dev環境のprovider、変数、module呼び出し
  modules/
    network/           # VPC、Subnet、Route Table、Internet Gateway
    security/          # Security Groupと通信ルール
    endpoints/         # Interface / Gateway VPC Endpoint
    ecs/               # ECR、ECS、ALB、Logs、Alarm、IAM
    github_oidc/       # GitHub Actions OIDC ProviderとDeploy Role
    budgets/           # AWS Budgetsと通知設定
```

moduleを責務ごとに分割し、環境固有値は `environments/dev` から渡します。

## 検証結果

- Terraformによる作成・再作成・削除
- GitHub Actions OIDCによるAWS認証
- GitHub ActionsからのECR pushとECS Service更新
- Deploy workflowによるALB経由の `/health` 自動確認
- Deploy workflow終了後にECS Taskが0台へ戻ることの確認
- ECS Fargate Task起動
- ALB Target Groupのhealthy確認
- ALB経由の `/health` HTTP 200確認
- CloudWatch Logsへのログ出力
- CloudWatch Alarm、AWS Budgets、ECR Lifecycle Policyの作成
- destroy後のTerraform stateが空であることの確認

## 制約と改善候補

| 現在の制約 | 本番相当へ近づける場合の対応 |
| --- | --- |
| ALBはHTTPのみ | ACM証明書とHTTPS Listenerを追加する |
| WAF未実装 | AWS Managed Rules、レート制限を追加する |
| DB未実装 | Private SubnetへRDSを追加し、認証情報をSecrets Managerで管理する |
| Alarm通知未実装 | SNS TopicとAlarm Actionを追加する |
| 単一dev環境 | staging / production環境とTerraform stateを分離する |
