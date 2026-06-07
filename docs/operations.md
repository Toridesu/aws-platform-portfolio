# 運用

このドキュメントでは、AWS環境を作成、確認、停止、削除するための運用手順をまとめます。

対象はdev環境です。

## 前提

作業ディレクトリ:

```bash
cd aws-platform-portfolio
```

以降の `cd ...` は、特に指定がない限りリポジトリルートから実行する前提です。

AWS Profile:

```bash
export AWS_PROFILE=cdk-dev
```

認証確認:

```bash
aws sts get-caller-identity
```

認証が切れている場合:

```bash
aws sso login --profile cdk-dev
export AWS_PROFILE=cdk-dev
aws sts get-caller-identity
```

PowerShellの場合:

```powershell
$env:AWS_PROFILE="cdk-dev"
aws sts get-caller-identity
```

## ローカルAPI確認

```bash
cd app
npm install
npm start
```

別ターミナルで確認:

```bash
curl http://localhost:3000/health
```

期待する応答:

```json
{
  "status": "ok",
  "service": "aws-platform-api",
  "timestamp": "..."
}
```

## Dockerイメージ作成

```bash
cd app
docker build -t aws-platform-api .
```

ローカルでDocker起動確認:

```bash
docker run --rm -p 3000:3000 aws-platform-api
```

別ターミナルで確認:

```bash
curl http://localhost:3000/health
```

## Terraform基本操作

Terraform作業ディレクトリ:

```bash
cd infra/environments/dev
```

初期化:

```bash
terraform init
```

フォーマット:

```bash
terraform fmt -recursive ../..
```

検証:

```bash
terraform validate
```

差分確認:

```bash
terraform plan
```

作成:

```bash
terraform apply
```

削除:

```bash
terraform destroy
```

## ECRへDockerイメージをpushする

Terraform apply後、ECR Repository URLを確認します。

```bash
terraform output -raw ecr_repository_url
```

ECRへログインします。

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com
```

DockerイメージにECR用タグを付けます。

```bash
docker tag aws-platform-api:latest $(terraform output -raw ecr_repository_url):latest
```

ECRへpushします。

```bash
docker push $(terraform output -raw ecr_repository_url):latest
```

ECR上のイメージ確認:

```bash
aws ecr describe-images \
  --repository-name aws-platform-portfolio-dev-api \
  --region ap-northeast-1 \
  --query "imageDetails[].{Tags:imageTags,Digest:imageDigest,PushedAt:imagePushedAt,Size:imageSizeInBytes}" \
  --output json
```

## ECSタスクを一時起動する

dev環境では、通常時のECS Task数は0です。

```hcl
ecs_desired_count = 0
```

API疎通確認時だけ、ECS Taskを1台起動します。

```bash
terraform apply -auto-approve -var ecs_desired_count=1
```

ECS Serviceの状態確認:

```bash
aws ecs describe-services \
  --cluster aws-platform-portfolio-dev-cluster \
  --services aws-platform-portfolio-dev-api-service \
  --region ap-northeast-1 \
  --query "services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}" \
  --output json
```

期待値:

```json
{
  "Status": "ACTIVE",
  "Desired": 1,
  "Running": 1,
  "Pending": 0
}
```

## ALB経由でAPI疎通確認

ALB DNS名を確認します。

```bash
terraform output -raw alb_dns_name
```

`/health` にアクセスします。

```bash
curl http://$(terraform output -raw alb_dns_name)/health
```

期待する応答:

```json
{
  "status": "ok",
  "service": "aws-platform-api",
  "timestamp": "..."
}
```

## ALB Target Groupのヘルス確認

Target Group ARNを確認します。

```bash
aws elbv2 describe-target-groups \
  --names dev-api-tg \
  --region ap-northeast-1 \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text
```

Target Healthを確認します。

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-northeast-1 \
  --query "TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}" \
  --output json
```

期待値:

```json
[
  {
    "Port": 3000,
    "State": "healthy"
  }
]
```

## ECS Taskを0に戻す

疎通確認後は、Fargateの実行料金を止めるためECS Task数を0に戻します。

```bash
terraform apply -auto-approve
```

確認:

```bash
aws ecs describe-services \
  --cluster aws-platform-portfolio-dev-cluster \
  --services aws-platform-portfolio-dev-api-service \
  --region ap-northeast-1 \
  --query "services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}" \
  --output json
```

期待値:

```json
{
  "Desired": 0,
  "Running": 0,
  "Pending": 0
}
```

## CloudWatch Logs確認

ECS Taskのロググループ:

```text
/ecs/aws-platform-portfolio-dev-api
```

注意:

`terraform destroy` 後はCloudWatch Log Groupも削除されます。
ログを確認する場合は、`terraform apply` 後にECS Taskを起動し、API疎通確認を行ってから確認します。

ログストリーム一覧:

```bash
aws logs describe-log-streams \
  --log-group-name /ecs/aws-platform-portfolio-dev-api \
  --region ap-northeast-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

直近のログストリーム名だけ取得する場合:

```bash
aws logs describe-log-streams \
  --log-group-name /ecs/aws-platform-portfolio-dev-api \
  --region ap-northeast-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query "logStreams[0].logStreamName" \
  --output text
```

ログイベント確認:

```bash
aws logs get-log-events \
  --log-group-name /ecs/aws-platform-portfolio-dev-api \
  --log-stream-name <log-stream-name> \
  --region ap-northeast-1 \
  --limit 20
```

直近ログを時刻とメッセージに絞って確認する場合:

```bash
LOG_STREAM_NAME=$(aws logs describe-log-streams \
  --log-group-name /ecs/aws-platform-portfolio-dev-api \
  --region ap-northeast-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query "logStreams[0].logStreamName" \
  --output text)

aws logs get-log-events \
  --log-group-name /ecs/aws-platform-portfolio-dev-api \
  --log-stream-name "$LOG_STREAM_NAME" \
  --region ap-northeast-1 \
  --limit 20 \
  --query "events[].{Time:timestamp,Message:message}" \
  --output table
```

PowerShellの場合:

```powershell
$logStreamName = aws logs describe-log-streams `
  --log-group-name /ecs/aws-platform-portfolio-dev-api `
  --region ap-northeast-1 `
  --order-by LastEventTime `
  --descending `
  --max-items 1 `
  --query "logStreams[0].logStreamName" `
  --output text

aws logs get-log-events `
  --log-group-name /ecs/aws-platform-portfolio-dev-api `
  --log-stream-name $logStreamName `
  --region ap-northeast-1 `
  --limit 20 `
  --query "events[].{Time:timestamp,Message:message}" `
  --output table
```

見るポイント:

- アプリケーション起動ログが出ているか
- `/health` へのアクセス時にエラーが出ていないか
- `CannotPullContainerError` や権限エラーが出ていないか
- ログが出ない場合、CloudWatch Logs VPC Endpoint、Task Execution Role、Security Groupを確認する

## よくあるトラブル

### AWS認証エラー

エラー例:

```text
InvalidClientTokenId
The security token included in the request is invalid.
```

対応:

```bash
aws sso login --profile cdk-dev
export AWS_PROFILE=cdk-dev
aws sts get-caller-identity
```

### ECR Repository not empty

エラー例:

```text
RepositoryNotEmptyException
```

対応:

このリポジトリでは、ECRに以下を設定済みです。

```hcl
force_delete = true
```

そのため、現在は `terraform destroy` でECR内のDockerイメージごと削除できます。

### ECS Taskが起動しない

確認するもの:

```bash
aws ecs describe-services \
  --cluster aws-platform-portfolio-dev-cluster \
  --services aws-platform-portfolio-dev-api-service \
  --region ap-northeast-1
```

見るポイント:

- Service events
- Desired / Running / Pending
- Task停止理由
- ECR image pull失敗
- CloudWatch Logs出力
- VPC Endpoint設定
- Security Group設定

### Target Groupがhealthyにならない

確認するもの:

- ECS TaskがRunningか
- コンテナが3000番でListenしているか
- ALBからECSへのSecurity GroupがTCP 3000を許可しているか
- Target GroupのHealth Check Pathが `/health` か
- APIがHTTP 200を返しているか

## すべて削除する

検証が終わったら、AWSリソースを削除します。

```bash
cd infra/environments/dev
terraform destroy
```

削除後、Terraform stateを確認します。

```bash
terraform state list
```

何も表示されなければ、Terraform管理下のリソースは残っていません。

必要に応じてAWS Consoleでも以下を確認します。

- ALB
- Target Group
- ECS Cluster
- ECR Repository
- VPC Endpoint
- VPC
- CloudWatch Log Group

## 通常の作業フロー

```text
1. AWS SSO認証
2. Terraform init / validate / plan
3. terraform apply
4. Docker build
5. ECR login
6. Docker tag
7. Docker push
8. ECS desired_count = 1で起動
9. ALB /health 疎通確認
10. ECS desired_count = 0へ戻す
11. 必要がなければ terraform destroy
12. terraform state listで削除確認
```

## GitHub Actions OIDC有効化

GitHub ActionsからAWSへデプロイする場合は、長期Access KeyではなくOIDCを使います。

dev環境では、TerraformでGitHub Actions OIDC Roleを作成します。

```hcl
enable_github_oidc = true
github_repository  = "Toridesu/aws-platform-portfolio"
github_branch      = "main"
```

Role ARNを確認します。

```bash
cd infra/environments/dev
terraform output github_actions_role_arn
```

このRole ARNをGitHub ActionsのAWS認証設定で使用します。

`terraform destroy` 後はRoleも削除されるため、Deploy workflowを再実行する前に `terraform apply` で再作成します。

## GitHub Actions deploy workflow

Deploy workflowは手動実行です。

```text
Actions -> Deploy -> Run workflow
```

GitHub repository variablesに以下を設定します。

```text
AWS_ROLE_ARN = arn:aws:iam::273004335930:role/aws-platform-portfolio-dev-github-actions-deploy-role
AWS_REGION = ap-northeast-1
ECR_REPOSITORY = aws-platform-portfolio-dev-api
ECS_CLUSTER = aws-platform-portfolio-dev-cluster
ECS_SERVICE = aws-platform-portfolio-dev-api-service
```

Deploy workflowが行うこと:

```text
1. GitHub OIDCでAWSへ認証
2. Docker imageをbuild
3. ECRへcommit SHA tagをpush
4. ECRへlatest tagをpush
5. ECS Serviceをforce new deployment
```

注意:

Deploy workflowを成功させるには、ECR RepositoryとECS ServiceがAWS上に存在している必要があります。
`terraform destroy` 後の状態では失敗します。

## コミット前確認

```bash
git status --short
git diff --stat
```

Terraform変更がある場合:

```bash
terraform fmt -recursive ../..
terraform validate
```

作業手順MarkdownはGit管理しない方針です。
`docs/phase/` 配下は `.gitignore` で除外しています。
