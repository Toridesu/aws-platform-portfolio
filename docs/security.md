# セキュリティ設計

## 方針

この構成では、公開範囲、ネットワーク通信、IAM権限、CI/CD認証を必要最小限に制限します。短時間利用のdev環境ですが、本番環境へ発展させる際の境界と未対応リスクも明示しています。

## 実装済み対策

| 領域 | 対策 |
| --- | --- |
| 外部公開 | インターネットから到達可能な入口をALBだけに限定 |
| アプリケーション | ECS TaskをPrivate Subnetに配置し、Public IPを付与しない |
| Inbound通信 | ECS TaskはALB Security GroupからのTCP 3000だけを許可 |
| Outbound通信 | ECS TaskからVPC EndpointとS3へのTCP 443だけを許可 |
| AWS認証 | GitHub Actionsは長期Access KeyではなくOIDCを使用 |
| IAM | ECS Task Execution RoleとDeploy Roleを用途別に最小権限化 |
| コンテナ | ECRでpush時のimage scanを有効化 |
| ログ | ECSアプリケーションログをCloudWatch Logsへ出力 |
| 監視 | ALB 5xxとunhealthy targetをCloudWatch Alarmで監視 |

## ネットワーク境界

```text
Internet
  -> ALB Security Group : TCP 80
  -> ECS Security Group : 接続不可

ALB Security Group
  -> ECS Security Group : TCP 3000

ECS Security Group
  -> VPC Endpoint Security Group : TCP 443
  -> S3 managed prefix list      : TCP 443
```

Security Group同士を参照することで、固定IPではなく役割単位で通信元・通信先を制限しています。

## IAM設計

### ECS Task Execution Role

ECSがコンテナを起動するための権限です。アプリケーションがAWS APIを呼ぶためのTask Roleとは分離しています。

許可範囲:

- `ecr:GetAuthorizationToken`
- 対象ECR Repositoryからのimage pull
- 対象CloudWatch Log Groupへのログ出力

`ecr:GetAuthorizationToken` はAWS仕様上Resourceを `*` にする必要があります。それ以外は対象RepositoryとLog Groupへ限定しています。

### GitHub Actions Deploy Role

OIDCの信頼条件を対象GitHubリポジトリの `main` ブランチに限定しています。Deploy Roleには以下だけを許可します。

- 対象ECR Repositoryへのimage push
- 対象ECS Cluster / Serviceの参照と更新
- 自動ヘルスチェックに必要なALB / Target Group情報の参照

Terraform apply用の広い権限はGitHub Actionsへ付与していません。

## コンテナとログ

- ECR image scan on pushを有効化
- ECR Lifecycle Policyでuntagged imageを1日後に削除
- tagged imageは直近10個を保持
- CloudWatch Logsの保持期間を7日に設定
- ECR RepositoryとLog Groupはdev環境のdestroy対象

`latest` に加えてcommit SHA tagをpushし、デプロイ元のcommitを追跡できるようにしています。

## 検証済み項目

- インターネットからECS Taskへ直接接続できない構成
- ALBからECS Taskへのヘルスチェック成功
- Private SubnetからVPC Endpoint経由でECR imageを取得
- CloudWatch Logsへのログ出力
- GitHub Actions OIDC認証
- GitHub Actions Deploy RoleによるECR pushとECS Service更新
- ECS Task Execution Roleのカスタムポリシー化
- ECS Security Groupの広いOutboundルール削除

## 未対応リスク

| リスク | 現在の状態 | 対応案 |
| --- | --- | --- |
| 通信がHTTP | ALB ListenerはTCP 80 | ACM証明書を発行しHTTPSへ移行 |
| L7攻撃対策 | WAF未実装 | AWS Managed Rules、レート制限を追加 |
| 秘密情報管理 | 現在は秘密情報を扱わない | RDSや外部API追加時にSecrets Managerを使用 |
| Alarm通知 | Alarm本体のみ | SNS通知を追加 |
| 脅威検知 | GuardDuty / Security Hub未実装 | 本番相当環境で有効化 |
| 操作監査 | CloudTrailを本構成では管理していない | 組織・アカウント基盤側で有効化 |

このポートフォリオは、上記を実装済みと見せるのではなく、現在の境界と次に必要な対策を説明できる状態を目標としています。
