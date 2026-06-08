# TODO

このファイルは、現在のポートフォリオ作業の進捗管理に使います。
今後、作業が完了したらCodexがこのTODOを更新します。

## 完了済み

- [x] Terraform構成を作成する
- [x] VPC / Subnet / Security GroupをTerraformで管理する
- [x] ALBをTerraformで管理する
- [x] ECS / FargateをTerraformで管理する
- [x] ECRをTerraformで管理する
- [x] IAM RoleをTerraformで管理する
- [x] CloudWatch LogsをTerraformで管理する
- [x] Dockerアプリを作成する
- [x] DockerイメージをECRへpushできるようにする
- [x] ECS/Fargateでコンテナを起動できるようにする
- [x] ALB経由でAPI疎通確認する
- [x] GitHubリポジトリをGit管理する
- [x] GitHubリポジトリをpublicに変更する
- [x] GitHub Actions Validate workflowを作成する
- [x] GitHub Actions Deploy workflowを手動実行できるようにする
- [x] GitHub Actions OIDCでAWS認証できるようにする
- [x] GitHub Actions Validate成功を確認する
- [x] GitHub Actions Deploy成功を確認する
- [x] ECR Lifecycle Policyを追加する
- [x] CloudWatch Alarmを追加する
- [x] AWS BudgetsをTerraformで設定できるようにする
- [x] READMEを日本語で整理する
- [x] docs配下の設計ドキュメントを日本語で整理する
- [x] 構成図を追加する
- [x] Terraform destroyを実行してリソース削除を確認する
- [x] `terraform plan -destroy` で残リソースなしを確認する
- [x] ECRが空でない場合のdestroy失敗原因を理解する
- [x] Cost Explorerで現時点の課金を確認する
- [x] `terraform.tfvars` でAWS Budgets通知先メールアドレスを設定する
- [x] `terraform apply` でAWS Budgetsが実際に作成されることを確認する
- [x] `terraform apply` でECR Lifecycle Policyが実際に作成されることを確認する
- [x] `terraform apply` でCloudWatch Alarmが実際に作成されることを確認する
- [x] GitHub Actions Deploy workflowを再実行して、ECR push / ECS deploy / ALB疎通を再確認する
- [x] 確認後に `terraform destroy` して、再びリソースを削除する
- [x] CloudWatch AlarmにSNS通知を追加するか判断する

## 未完了

- [ ] IAM権限をより最小化する
- [ ] Security Groupのアウトバウンド制御を見直す
- [ ] Cost Explorerで数日後に不要な課金が残っていないか確認する
- [ ] READMEに最終的な実行手順と検証結果を整理する
- [ ] ポートフォリオとして見せる用の説明文を整理する

## 今後の運用ルール

- 作業が完了したら、該当するTODOを `[ ]` から `[x]` に変更する
- 新しい作業が増えたら、未完了リストへ追加する
- 実行したコマンドや学習用メモは `docs/phase/` 配下の日本語Markdownにまとめる
- `docs/phase/` 配下の作業手順MarkdownはGit管理しない
- 作業完了時は、残っている作業もあわせて確認する
