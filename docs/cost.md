# コスト設計

## 方針

このdev環境は常時稼働させず、必要なときだけ作成・検証・削除します。

```text
terraform apply
  -> Deploy / 疎通確認
  -> terraform destroy
```

AWS Budgetsの月額上限は5 USDを想定しています。ただしBudgetは通知機能であり、リソースを自動停止するものではありません。

## 主な課金要因

| リソース | 主な課金単位 | 管理方針 |
| --- | --- | --- |
| Interface VPC Endpoint | Endpoint × AZ × 稼働時間、データ処理量 | 検証後にdestroy |
| Application Load Balancer | 稼働時間、LCU | 検証後にdestroy |
| ECS Fargate | TaskのvCPU、メモリ、稼働時間 | 通常 `desired_count = 0` |
| Public IPv4 | 使用時間 | ALB削除時に解放 |
| ECR | image保存容量 | Lifecycle Policyとdestroyで削除 |
| CloudWatch Logs | 取り込み量、保存容量 | 保持期間7日、destroyで削除 |
| CloudWatch Alarm | Alarm数 | 必要な2種類に限定 |

VPC、Subnet、Route Table、Security Group、ECS Clusterなど、作成自体に直接料金が発生しないリソースもあります。ただし、それらに関連する有料リソースやデータ転送には料金が発生します。

## コストを抑える設計

### 通常時はECS Taskを停止

dev環境のデフォルトは以下です。

```hcl
ecs_desired_count = 0
```

Deploy workflowは疎通確認時だけTaskを1台起動し、自動ヘルスチェックの成功・失敗に関係なく0台へ戻します。Taskを0台に戻してもALBやInterface VPC Endpointの課金は残るため、検証終了後は環境全体をdestroyします。

### NAT Gatewayを使用しない

現在のアプリケーションは外部API接続を必要としません。Private Subnetから必要なAWSサービスへはVPC Endpointで接続します。

Interface Endpointにも時間課金があるため、常にNAT Gatewayより安いわけではありません。現在の構成は通信先の限定と学習目的を重視した選択です。

### 保存データを残さない

- ECRのuntagged imageは1日後に削除
- tagged imageは直近10個を保持
- ECRは `force_delete = true`
- CloudWatch Logsの保持期間は7日
- 検証後はECRとLog Groupを含めてdestroy

## AWS Budgets

Terraformで以下を設定できます。

| 項目 | 設定 |
| --- | --- |
| 月額上限 | 5 USD |
| 実績コスト通知 | 80% |
| 予測コスト通知 | 100% |
| 通知先 | Git管理外の `terraform.tfvars` で指定 |

通知先メールアドレスは公開リポジトリへ含めません。

## 実測結果

2026年6月1日から6月7日までに実施した短時間の作成・デプロイ・疎通確認・削除では、ポートフォリオ構成に対応するVPCとECSの推定料金は約 `$0.0862` でした。

主な内訳:

| Usage Type | 推定料金 |
| --- | ---: |
| VPC Endpoint Hours | `$0.0840` |
| ECS / Fargate | 約 `$0.00184` |
| Idle Public IPv4 | 約 `$0.000385` |
| VPC Endpoint Bytes | 約 `$0.00000168` |

短時間検証では、Interface VPC Endpointの時間料金が大部分を占めました。料金データには反映遅延があるため、この値は構成の固定価格ではなく、実施時点の参考値です。

## 削除後の確認

```bash
terraform destroy
terraform plan -destroy
terraform state list
```

`terraform plan -destroy` が `No changes`、`terraform state list` が空であることを確認します。

Terraform管理外で作成したリソースや、別リージョン・別アカウントのリソースはこの確認に含まれません。実運用ではAWS Budgets、Billing画面、タグによるコスト分類も併用します。

## 将来リソースを追加する場合

| 追加候補 | コスト上の注意 |
| --- | --- |
| HTTPS / Route 53 | 証明書、Hosted Zone、DNS queryの料金体系を確認する |
| WAF | Web ACL、Rule、request数を確認する |
| RDS | Instance稼働時間、Storage、Backupを確認する |
| SNS通知 | 通知数は小規模なら低額だが、運用対象が増える |
