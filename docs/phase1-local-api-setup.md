# Phase 1 ローカルAPI作成手順

## この手順書の目的

このドキュメントは、2026-05-16に実施したPhase 1の作業を、自分でも再現・説明できるようにまとめたものです。

今回のゴールは、AWSへデプロイする前段階として、以下を完了させることでした。

- Node.js / Express の小さなAPIを作る
- `/health` エンドポイントを作る
- Dockerfileを作る
- ローカルでAPI単体の起動確認をする
- Dockerコンテナとして起動確認をする
- 今後のTerraformや設計ドキュメントの置き場を用意する

## 1. 作業フォルダを確認する

作業場所:

```powershell
C:\Users\siton\Documents\Codex\career
```

最初に、既存のファイルを確認しました。

```powershell
Get-ChildItem -Force | Select-Object Mode,Length,LastWriteTime,Name
```

この確認で、以下のような既存メモがあることを確認しました。

```text
career_strategy_handoff.md
next_project_preferences.md
resume_positioning.md
aws_portfolio_plan.md
daily_logs/
```

## 2. ポートフォリオ方針を確認する

昨日作成した `aws_portfolio_plan.md` を読み、今回の実装方針を確認しました。

```powershell
Get-Content -Raw -LiteralPath .\aws_portfolio_plan.md
```

確認した方針:

- CDKは使わない
- Terraform中心で進める
- Go言語はまだ使わない
- まずはNode.js / Express APIを作る
- 主役はアプリではなく、AWS基盤、Terraform、ECS/Fargate、CI/CD、監視、セキュリティ

## 3. プロジェクト構成を作る

今回作った主な構成は以下です。

```text
aws-platform-portfolio/
  README.md
  .gitignore
  app/
    src/
      index.js
    package.json
    package-lock.json
    Dockerfile
    .dockerignore
  infra/
    environments/
      dev/
    modules/
      network/
      ecs/
      rds/
      security/
      monitoring/
  docs/
    architecture.md
    operations.md
    security.md
    cost.md
    phase1-local-api-setup.md
```

それぞれの役割:

- `app/`: Node.js / Express APIを置く場所
- `infra/`: Terraformを置く場所
- `docs/`: 設計、運用、セキュリティ、コスト、作業手順をまとめる場所
- `README.md`: ポートフォリオ全体の説明
- `.gitignore`: Gitに含めないファイルを指定する場所

## 4. Node.js / Express APIを作る

作成したファイル:

```text
app/src/index.js
```

このファイルでは、ExpressでAPIサーバーを作っています。

実装したエンドポイント:

```text
GET /
GET /health
```

`GET /` の役割:

- サービス名
- 簡単な説明
- 利用できるエンドポイント

`GET /health` の役割:

- アプリが正常に動いているか確認する
- 将来ALBやECSのヘルスチェックに使う

返却例:

```json
{
  "status": "ok",
  "service": "aws-platform-api",
  "timestamp": "2026-05-16T07:28:17.307Z"
}
```

## 5. package.jsonを作る

作成したファイル:

```text
app/package.json
```

主な内容:

```json
{
  "scripts": {
    "start": "node src/index.js",
    "dev": "node --watch src/index.js"
  },
  "dependencies": {
    "express": "^4.19.2",
    "helmet": "^7.1.0"
  }
}
```

`express` の役割:

- Web APIを作るためのNode.jsフレームワーク

`helmet` の役割:

- HTTPレスポンスヘッダーに基本的なセキュリティ設定を追加する
- 小さいAPIでも、セキュリティを意識していることを示せる

## 6. Dockerfileを作る

作成したファイル:

```text
app/Dockerfile
```

主な意図:

- Node.js 20系の軽量イメージを使う
- 依存関係のインストールと実行環境を分ける
- 本番実行時は `NODE_ENV=production` にする
- rootではなく `node` ユーザーで実行する
- 3000番ポートを公開する

今回のDockerfileは、将来ECS/Fargateで動かす前提のシンプルな構成です。

## 7. .dockerignoreを作る

作成したファイル:

```text
app/.dockerignore
```

除外したもの:

```text
node_modules
npm-debug.log
.env
.git
.gitignore
Dockerfile
```

理由:

- `node_modules` はコンテナ内で入れ直すため不要
- `.env` は秘密情報が入る可能性があるため含めない
- `.git` などのGit情報はDockerイメージに不要

## 8. Markdownドキュメントを作る

作成したファイル:

```text
docs/architecture.md
docs/operations.md
docs/security.md
docs/cost.md
```

現時点では中身は土台だけです。

今後、TerraformやAWS構成を作りながら以下を追記します。

- なぜそのAWS構成にしたか
- 障害時にどこを見るか
- IAMやSecurity Groupをどう設計したか
- NAT GatewayやRDSのコストをどう考えるか

## 9. ローカル環境を確認する

Node.js、npm、Dockerが使えるか確認しました。

```powershell
node --version
npm --version
docker --version
```

確認結果:

```text
Node.js: v24.15.0
npm: 11.14.1
Docker: 28.3.0
```

## 10. 依存関係をインストールする

`app/` に移動して、依存関係をインストールしました。

```powershell
cd .\aws-platform-portfolio\app
npm install
```

この作業で作成されたファイル:

```text
package-lock.json
node_modules/
```

`package-lock.json` の役割:

- どのバージョンの依存パッケージを入れたか固定する
- 他の環境でも同じ依存関係を再現しやすくする

`node_modules/` の役割:

- npmでインストールした依存パッケージの実体
- Gitには含めない

結果:

```text
found 0 vulnerabilities
```

## 11. API単体で起動確認する

Dockerを使う前に、まずNode.jsだけでAPIが動くか確認しました。

通常の起動コマンド:

```powershell
npm start
```

今回の確認では、APIを一時起動して `/health` にアクセスし、確認後に停止しました。

```powershell
$p = Start-Process -FilePath node -ArgumentList 'src/index.js' -WorkingDirectory (Get-Location) -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 2
Invoke-RestMethod -Uri 'http://localhost:3000/health'
Stop-Process -Id $p.Id -Force
```

確認結果:

```json
{
  "status": "ok",
  "service": "aws-platform-api",
  "timestamp": "2026-05-16T07:26:40.339Z"
}
```

この時点で、API単体は正常に動いていることが確認できました。

## 12. Dockerエンジンの状態を確認する

最初にDocker buildを実行したとき、Docker DesktopのLinuxエンジンに接続できず失敗しました。

そのため、Dockerエンジンが使える状態か確認しました。

```powershell
docker info --format '{{.ServerVersion}}'
```

確認結果:

```text
28.3.0
```

これでDockerエンジンが利用可能になったことを確認しました。

## 13. Dockerイメージをビルドする

`app/` 配下でDockerイメージを作成しました。

```powershell
docker build -t aws-platform-api .
```

コマンドの意味:

- `docker build`: Dockerイメージを作る
- `-t aws-platform-api`: イメージ名を `aws-platform-api` にする
- `.`: 現在のディレクトリにあるDockerfileを使う

結果:

```text
docker.io/library/aws-platform-api:latest
```

Dockerイメージのビルドは成功しました。

## 14. Dockerコンテナで起動確認する

ビルドしたイメージを使って、コンテナを一時起動しました。

通常の起動コマンド:

```powershell
docker run --rm -p 3000:3000 aws-platform-api
```

今回の確認では、コンテナをバックグラウンドで起動し、`/health` にアクセスしてから停止しました。

```powershell
$containerId = docker run -d -p 3000:3000 aws-platform-api
Start-Sleep -Seconds 2
Invoke-RestMethod -Uri 'http://localhost:3000/health'
docker stop $containerId
```

確認結果:

```json
{
  "status": "ok",
  "service": "aws-platform-api",
  "timestamp": "2026-05-16T07:28:17.307Z"
}
```

この時点で、以下が確認できました。

- Dockerイメージを作れる
- Dockerコンテナとして起動できる
- コンテナ経由でも `/health` が正常に返る

## 15. .gitignoreを作る

作成したファイル:

```text
.gitignore
```

主な除外対象:

```text
node_modules/
.env
.terraform/
*.tfstate
terraform.tfvars
```

理由:

- `node_modules/` は依存パッケージなのでGit管理しない
- `.env` は秘密情報が入る可能性がある
- `.terraform/` や `*.tfstate` はTerraformのローカル状態や実行結果なのでGit管理しない
- `terraform.tfvars` はAWS環境固有の値や秘密情報が入る可能性がある

## 16. 作成ファイルを確認する

最後に、`node_modules` を除いて作成ファイル一覧を確認しました。

```powershell
rg --files aws-platform-portfolio -g '!node_modules'
```

主な作成ファイル:

```text
aws-platform-portfolio\README.md
aws-platform-portfolio\.gitignore
aws-platform-portfolio\app\package.json
aws-platform-portfolio\app\package-lock.json
aws-platform-portfolio\app\Dockerfile
aws-platform-portfolio\app\.dockerignore
aws-platform-portfolio\app\src\index.js
aws-platform-portfolio\docs\architecture.md
aws-platform-portfolio\docs\operations.md
aws-platform-portfolio\docs\security.md
aws-platform-portfolio\docs\cost.md
aws-platform-portfolio\docs\phase1-local-api-setup.md
```

## 今回理解しておきたいポイント

### なぜ最初に小さいAPIを作ったのか

今回の主役はアプリではなくAWS基盤です。

ただし、ECS/FargateやALBを使うには、動かす対象のコンテナが必要です。そのため、まずは小さなAPIを作りました。

### なぜ `/health` が必要なのか

将来ALBやECSが「このコンテナは正常か」を判断するために使います。

ヘルスチェックがあると、以下を実現しやすくなります。

- ALBが異常なタスクへ通信を流さない
- ECSが異常なタスクを再起動できる
- 運用時にアプリの状態を確認しやすい

### なぜDocker化したのか

ECS/Fargateではコンテナを動かします。

そのため、ローカルでDockerコンテナとして動くことを確認しておくと、AWSに載せる準備になります。

### なぜREADMEやdocsを早めに作ったのか

ポートフォリオでは、作ったものだけでなく「なぜそう設計したか」を説明できることが重要です。

今後AWS構成を追加するたびに、READMEやdocsへ理由を残していきます。

## 今回の到達点

```text
Node.js / Express APIを作成した
/health エンドポイントを作成した
Dockerfileを作成した
API単体で起動確認した
Dockerコンテナとして起動確認した
READMEとdocsの土台を作成した
Terraform用ディレクトリの土台を作成した
```

## 次にやること

次回はPhase 2として、Terraformの土台を作ります。

予定:

- `infra/environments/dev` にTerraform初期ファイルを作る
- `modules/network` にVPC、Subnet、Route Table、Security Groupを作る
- まずはAWSネットワークの基本構成をTerraformで表現する
