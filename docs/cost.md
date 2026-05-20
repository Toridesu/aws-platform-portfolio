# コスト

このドキュメントには、学習用環境としてのコスト配慮をまとめます。

## 現時点の方針

学習用環境では、`terraform apply` 後に確認が終わったら `terraform destroy` で削除します。

特にALB、NAT Gateway、RDS、Fargate Taskは放置すると継続課金につながるため、作成後の削除確認を必須にします。

## 現時点でコストに注意するリソース

### ALB

ALBは作成しているだけで時間課金が発生します。

今回のECS / ALB土台ではALBをTerraformに含めています。そのため、`terraform apply` で作成した場合は、確認後に `terraform destroy` で削除します。

### ECS / Fargate

ECS Service自体よりも、実際に起動するFargate Taskに課金が発生します。

現時点では `ecs_desired_count = 0` をデフォルトにしています。

理由:

- まだECRにイメージをpushしていない
- Private SubnetからECRやCloudWatch Logsへ出る通信経路が未整備
- Fargate Taskの不要な起動コストを避ける

### CloudWatch Logs

CloudWatch Logsは保存量に応じて課金されます。

現時点ではLog Groupの保持期間を7日にしています。

### ECR

ECRは保存したDockerイメージの容量に応じて課金されます。

不要なイメージを残し続けないように、後続フェーズでライフサイクルポリシーを検討します。

### NAT Gateway

現時点ではNAT Gatewayを作っていません。

NAT Gatewayは時間課金とデータ処理課金があり、学習用環境ではコストが大きくなりやすいためです。

ECS TaskをPrivate Subnetで実際に起動する段階で、NAT GatewayとVPC Endpointを比較します。

## クリーンアップ方針

検証後は以下を実行します。

```bash
terraform destroy
```

削除後は以下を確認します。

```bash
terraform state list
```

何も表示されなければ、Terraform管理下のリソースは残っていません。
