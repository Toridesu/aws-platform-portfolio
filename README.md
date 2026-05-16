# AWS Platform Portfolio

## 目的

このポートフォリオは、Terraform、ECS/Fargate、Docker、CI/CD、監視、セキュリティを含むAWS基盤構築の実践力を示すためのものです。

アプリケーション自体は意図的にシンプルにします。主役はアプリ開発ではなく、インフラと運用設計です。

- AWSネットワークとアプリケーション基盤の設計
- TerraformによるInfrastructure as Code
- Docker化したAPIのECS/Fargateへのデプロイ
- GitHub ActionsによるCI/CD
- CloudWatchによる監視
- IAM、Secrets Manager、WAF、GuardDuty、Security Hubなどのセキュリティ設計

## 現在のフェーズ

Phase 1では、Dockerで起動できるローカルAPIを作成します。

現在のゴール:

- シンプルなヘルスチェック用エンドポイントを用意する
- 今後AWS基盤に集中できるように、アプリは小さく保つ
- Terraformとドキュメントを置くためのリポジトリ構成を用意する

## ローカルAPI

エンドポイント:

- `GET /`: サービスの基本情報を返す
- `GET /health`: ALBやコンテナのヘルスチェックに使う状態確認を返す

## ローカルで起動する

```bash
cd app
npm install
npm start
```

確認URL:

```text
http://localhost:3000/health
```

## Dockerで起動する

```bash
cd app
docker build -t aws-platform-api .
docker run --rm -p 3000:3000 aws-platform-api
```

## 予定している構成

```text
GitHub Actions
  |
  v
ECR
  |
  v
ECS Fargate
  |
  v
ALB
  |
  v
Internet

ECS Fargate
  |
  v
RDS PostgreSQL
```

## 次にやること

- `infra/` 配下にTerraformの土台を追加する
- VPC、サブネット、ルートテーブル、セキュリティグループを作成する
- ECR、ECS Cluster、ALB、ECS Serviceを作成する
- Docker buildとデプロイ用のGitHub Actionsを追加する
- CloudWatch LogsとCloudWatch Alarmを追加する
- セキュリティ設定と設計ドキュメントを追加する
