# コスト

このドキュメントでは、学習用AWS環境としてのコスト方針、課金ポイント、削除運用をまとめます。

## 基本方針

このポートフォリオでは、AWSリソースを必要なときだけ作成し、検証後は削除する方針です。

基本運用:

```text
terraform apply
  ↓
必要な検証を行う
  ↓
terraform destroy
```

特に以下は放置すると継続課金につながります。

- ALB
- Interface VPC Endpoint
- Fargate Task
- CloudWatch Logs
- ECR
- NAT Gateway
- RDS

今回の構成ではNAT GatewayとRDSは作成していません。

## 現在の構成における課金ポイント

### ALB

Application Load Balancerは、作成しているだけで時間課金が発生します。

今回の構成では、ALBはTerraformで作成されます。
ECS Taskの `desired_count` が0でも、ALB自体が存在していれば課金対象です。

コスト管理方針:

- 検証が終わったら `terraform destroy` で削除する
- 常時稼働させる段階までは作りっぱなしにしない

### ECS / Fargate

ECS Serviceそのものよりも、実際に起動しているFargate Taskが主な課金対象です。

dev環境では、ECS Serviceのデフォルトを以下にしています。

```hcl
ecs_desired_count = 0
```

理由:

- Fargate Taskの不要な継続課金を避けるため
- API疎通確認時だけ一時的に起動するため
- Terraform構成は保持しつつ、実行中コンテナを止められるため

API疎通確認時のみ以下を実行します。

```bash
terraform apply -auto-approve -var ecs_desired_count=1
```

確認後は以下で0に戻します。

```bash
terraform apply -auto-approve
```

注意点:

`desired_count = 0` にしてもALB、VPC Endpoint、ECR、CloudWatch Logsなどは残ります。
Fargate Taskの実行料金は止まりますが、基盤リソースの課金は残るため、完全に止めるには `terraform destroy` が必要です。

### VPC Endpoint

Private Subnet上のECS TaskがECRとCloudWatch Logsへ到達するため、Interface VPC Endpointを使っています。

作成しているInterface Endpoint:

```text
ecr.api
ecr.dkr
logs
```

Interface Endpointは時間課金とデータ処理課金の対象です。
今回の構成では2つのAvailability Zoneに配置しているため、Endpointごとに複数のENIが作成されます。

S3はGateway Endpointとして作成しています。
S3 Gateway EndpointはInterface Endpointとは課金体系が異なり、時間課金はありません。

コスト管理方針:

- NAT Gatewayを使わず、必要なAWSサービスへの通信に絞る
- 短時間検証後は `terraform destroy` で削除する
- 外部API通信が必要になった段階でNAT Gatewayとの比較を行う

### ECR

ECRはDockerイメージの保存容量に応じて課金されます。

今回の構成では、ローカルでビルドしたDockerイメージをECRへpushし、ECS Task Definitionから参照します。

コスト管理方針:

- 不要なイメージを残し続けない
- 学習環境では `terraform destroy` でECRリポジトリごと削除する
- 将来的にはECR Lifecycle Policyを追加する

ECRリポジトリ内にイメージが残っていると削除に失敗するため、以下を設定しています。

```hcl
force_delete = true
```

これにより、`terraform destroy` 時にECRリポジトリと中のイメージをまとめて削除できます。

### CloudWatch Logs

CloudWatch Logsは、保存量と保持期間に応じて課金されます。

今回の構成では、ECS TaskのログをCloudWatch Logsへ送信します。

Log Groupの保持期間は以下です。

```hcl
log_retention_days = 7
```

コスト管理方針:

- dev環境ではログ保持期間を短くする
- 検証後は `terraform destroy` でLog Groupを削除する
- 本番想定では保持期間と監査要件を分けて考える

### NAT Gateway

今回の構成ではNAT Gatewayを作成していません。

理由:

- 時間課金とデータ処理課金があり、学習用環境では高くなりやすい
- 今回必要な通信先はECRとCloudWatch Logsが中心
- VPC Endpointで必要なAWSサービスへの通信を満たせる

ただし、Private Subnet上のECS Taskから外部APIへアクセスする必要がある場合は、NAT Gatewayの検討が必要です。

### RDS

現時点ではRDSを作成していません。

理由:

- 継続課金が発生する
- 現在の学習テーマはコンテナ基盤、ECS、ALB、VPC Endpointが中心
- DBを追加すると、バックアップ、サブネットグループ、Security Group、認証情報管理も必要になる

追加する場合は、短時間検証または停止可能な構成を前提にします。

## 短時間検証時の考え方

短時間だけAPI疎通を確認する場合、主に発生するのは以下です。

- ALBの稼働時間
- Interface VPC Endpointの稼働時間
- Fargate Taskの起動時間
- CloudWatch Logsの少量ログ
- ECRの短時間保存

短時間であれば大きな金額にはなりにくいですが、ALBやInterface Endpointは「起動しているだけ」で課金されるため、検証後に削除することが重要です。

## コストを止める操作

### Fargate Taskだけ止める

```bash
terraform apply -auto-approve
```

dev環境のデフォルト `ecs_desired_count = 0` に戻すことで、ECS Taskを停止します。

この操作で止まるもの:

- Fargate Taskの実行料金

この操作では残るもの:

- ALB
- VPC Endpoint
- ECR
- CloudWatch Logs
- VPC
- Subnet
- Security Group

### すべて削除する

```bash
terraform destroy
```

Terraform管理下のAWSリソースを削除します。

検証後はこれを実行するのが基本です。

削除後は以下でstateを確認します。

```bash
terraform state list
```

何も表示されなければ、Terraform state上に管理リソースは残っていません。

## destroy時に注意すること

ECRにDockerイメージが残っていると、通常はECRリポジトリ削除に失敗します。

この構成では以下を設定済みです。

```hcl
force_delete = true
```

そのため、ECRにイメージが残っていても `terraform destroy` で削除できます。

destroy後に確認するもの:

```bash
terraform state list
```

必要に応じてAWS Consoleでも以下を確認します。

- ALBが残っていないか
- VPC Endpointが残っていないか
- ECS Clusterが残っていないか
- ECR Repositoryが残っていないか
- CloudWatch Log Groupが残っていないか
- VPCが残っていないか

## 面接やレビューで説明すべきポイント

コスト設計として、以下を説明できるとよいです。

- FargateはTaskが起動している時間に注意する
- `desired_count = 0` でFargate Taskの実行料金を止めている
- ALBとInterface VPC Endpointは存在しているだけで課金される
- NAT Gatewayは学習用では高くなりやすいため採用していない
- Private SubnetからAWSサービスへはVPC Endpointで到達させている
- ECRはイメージ保存容量に注意する
- ECR Lifecycle Policyでuntagged imageを1日後に削除し、tagged imageは直近10個を保持する
- CloudWatch Logsは保持期間を短めにしている
- 最終的に `terraform destroy` で削除できるようにしている
- ECR削除失敗を防ぐため `force_delete = true` を設定している

## Cost Explorer実測結果

2026年6月7日に、2026年6月1日から2026年6月7日までの推定料金をCost Explorerで確認しました。

確認コマンド:

```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-06-01,End=2026-06-08 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

確認できた推定料金:

| 項目 | 金額 |
| --- | ---: |
| Amazon Virtual Private Cloud | 約 `$0.08439` |
| Amazon Elastic Container Service | 約 `$0.00184` |
| Amazon GuardDuty | 約 `$0.00255` |
| Tax | `$0.01` |
| その他 | ほぼ `$0` |
| 合計 | 約 `$0.0988` |

ポートフォリオ構成に直接対応する確認済み料金は、VPCとECSを合わせて約 `$0.0862` です。

VPC料金の主な内訳:

| Usage Type | 金額 |
| --- | ---: |
| VPC Endpoint Hours | `$0.0840` |
| Idle Public IPv4 | 約 `$0.000385` |
| VPC Endpoint Bytes | 約 `$0.00000168` |

今回の短時間検証では、料金の大部分がInterface VPC Endpointの時間料金でした。
ECS/Fargate Taskを短時間だけ起動した料金は、VPC Endpointより小さい結果でした。

Cost Explorerの料金データには反映遅延があります。
2026年6月7日に実行した最終再作成テスト分は、確認時点ではまだ反映されていない可能性があります。

また、GuardDutyはこのポートフォリオとは別の料金であり、destroy後も日次料金が確認されています。

## 今後の改善候補

- CloudWatch Alarmのコストも考慮する
- AWS Budgetsを設定する
- `Environment = dev` タグでコストを分類する
- RDS追加時の停止・削除運用を設計する
