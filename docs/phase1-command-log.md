# Phase 1 実行コマンドログ

## このドキュメントの目的

このドキュメントは、Phase 1でCodexが実際に実行したコマンドだけをまとめたものです。

「どのコマンドを、何のために打ったのか」を自分で追えるようにするための記録です。

## 1. ポートフォリオ方針メモを読む

```powershell
Get-Content -Raw -LiteralPath .\aws_portfolio_plan.md
```

意味:

- `aws_portfolio_plan.md` の中身を読む
- 昨日決めたポートフォリオ方針を確認する

確認したこと:

- CDKは使わない
- Terraform中心で進める
- Go言語はまだ使わない
- まずはNode.js / Express APIを作る

## 2. 作業フォルダの中身を確認する

```powershell
Get-ChildItem -Force | Select-Object Mode,Length,LastWriteTime,Name
```

意味:

- 現在の作業フォルダにあるファイル・フォルダを一覧表示する
- `-Force` は隠しファイルも含めて表示する指定
- `Select-Object` で表示する項目を絞っている

確認したこと:

- `career_strategy_handoff.md`
- `next_project_preferences.md`
- `resume_positioning.md`
- `aws_portfolio_plan.md`
- `daily_logs/`

## 3. Node.jsのバージョンを確認する

```powershell
node --version
```

意味:

- Node.jsが入っているか確認する
- 入っている場合はバージョンを表示する

結果:

```text
v24.15.0
```

## 4. npmのバージョンを確認する

```powershell
npm --version
```

意味:

- npmが入っているか確認する
- npmはNode.jsのパッケージ管理ツール

結果:

```text
11.14.1
```

## 5. Dockerのバージョンを確認する

```powershell
docker --version
```

意味:

- Dockerコマンドが使えるか確認する
- Docker CLIのバージョンを表示する

結果:

```text
Docker version 28.3.0, build 38b7060
```

## 6. 依存関係をインストールする

```powershell
npm install
```

実行場所:

```text
C:\Users\siton\Documents\Codex\career\aws-platform-portfolio\app
```

意味:

- `package.json` に書かれている依存パッケージをインストールする
- 今回は `express` と `helmet` がインストール対象

作成・更新されたもの:

- `node_modules/`
- `package-lock.json`

結果:

```text
added 69 packages
found 0 vulnerabilities
```

## 7. APIを一時起動してヘルスチェックする

```powershell
$p = Start-Process -FilePath node -ArgumentList 'src/index.js' -WorkingDirectory (Get-Location) -WindowStyle Hidden -PassThru; Start-Sleep -Seconds 2; try { Invoke-RestMethod -Uri 'http://localhost:3000/health' | ConvertTo-Json -Compress } finally { Stop-Process -Id $p.Id -Force }
```

実行場所:

```text
C:\Users\siton\Documents\Codex\career\aws-platform-portfolio\app
```

意味:

- `node src/index.js` でAPIを一時的に起動する
- 2秒待つ
- `http://localhost:3000/health` にアクセスする
- レスポンスをJSONとして表示する
- 最後に起動したAPIプロセスを停止する

分解すると以下です。

```powershell
$p = Start-Process -FilePath node -ArgumentList 'src/index.js' -WorkingDirectory (Get-Location) -WindowStyle Hidden -PassThru
```

意味:

- Node.jsで `src/index.js` を起動する
- 起動したプロセス情報を `$p` に入れる

```powershell
Start-Sleep -Seconds 2
```

意味:

- APIが起動するまで2秒待つ

```powershell
Invoke-RestMethod -Uri 'http://localhost:3000/health'
```

意味:

- `/health` にHTTPアクセスする

```powershell
Stop-Process -Id $p.Id -Force
```

意味:

- 最初に起動したAPIプロセスを停止する

結果:

```json
{"status":"ok","service":"aws-platform-api","timestamp":"2026-05-16T07:26:40.339Z"}
```

## 8. Dockerイメージをビルドする

```powershell
docker build -t aws-platform-api .
```

実行場所:

```text
C:\Users\siton\Documents\Codex\career\aws-platform-portfolio\app
```

意味:

- Dockerfileを使ってDockerイメージを作る
- `-t aws-platform-api` でイメージ名を `aws-platform-api` にする
- `.` は現在のフォルダをビルド対象にするという意味

最初の結果:

- Docker DesktopのLinuxエンジンに接続できず失敗

エラーの要点:

```text
dockerDesktopLinuxEngine に接続できない
```

## 9. Docker Desktopコマンドの有無を確認する

```powershell
Get-Command 'Docker Desktop' -ErrorAction SilentlyContinue
```

意味:

- `Docker Desktop` というコマンドがPowerShellから見つかるか確認する
- `-ErrorAction SilentlyContinue` は、見つからない場合もエラー表示を抑える指定

結果:

- この方法ではコマンドとしては見つからなかった

## 10. Docker Desktopの標準インストール先を確認する

```powershell
Test-Path 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
```

意味:

- 指定したパスにDocker Desktopの実行ファイルがあるか確認する

結果:

```text
True
```

## 11. Docker Desktopのプロセスを確認する

```powershell
Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue
```

意味:

- Docker Desktopが起動中か確認する
- `-ErrorAction SilentlyContinue` は、起動していない場合もエラー表示を抑える指定

結果:

- Docker Desktopのプロセスは起動していた
- ただし、この時点ではDockerエンジンがまだ使える状態ではなかった

## 12. Dockerエンジンの起動を待って確認する

```powershell
Start-Sleep -Seconds 10; docker info --format '{{.ServerVersion}}'
```

意味:

- 10秒待つ
- Dockerエンジンに接続できるか確認する
- 接続できた場合、Docker Serverのバージョンを表示する

結果:

```text
28.3.0
```

この結果により、Dockerエンジンが利用可能になったことを確認しました。

## 13. Dockerイメージを再ビルドする

```powershell
docker build -t aws-platform-api .
```

実行場所:

```text
C:\Users\siton\Documents\Codex\career\aws-platform-portfolio\app
```

意味:

- Dockerfileを使って、改めてDockerイメージを作る

結果:

- ビルド成功
- `aws-platform-api:latest` が作成された

## 14. Dockerコンテナを一時起動してヘルスチェックする

```powershell
$containerId = docker run -d -p 3000:3000 aws-platform-api; Start-Sleep -Seconds 2; try { Invoke-RestMethod -Uri 'http://localhost:3000/health' | ConvertTo-Json -Compress } finally { docker stop $containerId | Out-Null }
```

実行場所:

```text
C:\Users\siton\Documents\Codex\career\aws-platform-portfolio\app
```

意味:

- `aws-platform-api` イメージからコンテナを起動する
- PC側の3000番ポートとコンテナ側の3000番ポートをつなぐ
- 2秒待つ
- `http://localhost:3000/health` にアクセスする
- 最後にコンテナを停止する

分解すると以下です。

```powershell
$containerId = docker run -d -p 3000:3000 aws-platform-api
```

意味:

- コンテナをバックグラウンドで起動する
- `-d` はバックグラウンド起動
- `-p 3000:3000` はポートの対応付け
- 起動したコンテナIDを `$containerId` に入れる

```powershell
Invoke-RestMethod -Uri 'http://localhost:3000/health'
```

意味:

- コンテナ内で動くAPIの `/health` にアクセスする

```powershell
docker stop $containerId
```

意味:

- 起動したコンテナを停止する

結果:

```json
{"status":"ok","service":"aws-platform-api","timestamp":"2026-05-16T07:28:17.307Z"}
```

## 15. 作成ファイル一覧を確認する

```powershell
rg --files aws-platform-portfolio
```

意味:

- `aws-platform-portfolio` 配下のファイル一覧を表示する
- `rg --files` はファイル検索用の高速コマンド

結果:

- `node_modules` 配下のファイルまで大量に表示された
- そのため、後で `node_modules` を除外して再確認した

## 16. Git状態を確認しようとする

```powershell
git status --short
```

意味:

- Git管理されているフォルダで、変更されたファイル一覧を短く表示する

結果:

```text
fatal: not a git repository
```

意味:

- 現在のフォルダはまだGitリポジトリではない
- そのため、Git上の変更状態は確認できなかった

## 17. node_modulesを除いてファイル一覧を確認する

```powershell
rg --files aws-platform-portfolio -g '!node_modules'
```

意味:

- `aws-platform-portfolio` 配下のファイル一覧を表示する
- `-g '!node_modules'` で `node_modules` 配下を除外する

確認できた主なファイル:

```text
aws-platform-portfolio\README.md
aws-platform-portfolio\app\package-lock.json
aws-platform-portfolio\app\Dockerfile
aws-platform-portfolio\app\package.json
aws-platform-portfolio\app\src\index.js
aws-platform-portfolio\docs\cost.md
aws-platform-portfolio\docs\architecture.md
aws-platform-portfolio\docs\operations.md
aws-platform-portfolio\docs\security.md
```

## 18. Markdownファイル一覧を確認する

```powershell
rg --files -g '*.md'
```

意味:

- 現在のフォルダ配下にあるMarkdownファイルを一覧表示する

結果:

- プロジェクト用Markdownに加えて、`node_modules` 配下の外部ライブラリのMarkdownも大量に表示された

## 19. READMEの内容を確認する

```powershell
Get-Content -Raw -LiteralPath .\aws-platform-portfolio\README.md
```

意味:

- 作成したREADMEの内容を確認する
- この後、日本語化するために内容を読んだ

## 20. architecture.mdの内容を確認する

```powershell
Get-Content -Raw -LiteralPath .\aws-platform-portfolio\docs\architecture.md
```

意味:

- `architecture.md` の内容を確認する
- この後、日本語化するために内容を読んだ

## 21. operations.mdの内容を確認する

```powershell
Get-Content -Raw -LiteralPath .\aws-platform-portfolio\docs\operations.md
```

意味:

- `operations.md` の内容を確認する
- この後、日本語化するために内容を読んだ

## 22. security.mdの内容を確認する

```powershell
Get-Content -Raw -LiteralPath .\aws-platform-portfolio\docs\security.md
```

意味:

- `security.md` の内容を確認する
- この後、日本語化するために内容を読んだ

## 23. cost.mdの内容を確認する

```powershell
Get-Content -Raw -LiteralPath .\aws-platform-portfolio\docs\cost.md
```

意味:

- `cost.md` の内容を確認する
- この後、日本語化するために内容を読んだ

## 24. プロジェクト用Markdownだけを確認する

```powershell
rg --files aws-platform-portfolio -g '*.md' -g '!node_modules'
```

意味:

- `aws-platform-portfolio` 配下のMarkdownファイルを一覧表示する
- `node_modules` 配下は除外する
- 自分たちで作ったMarkdownがどれか確認する

確認できたファイル:

```text
aws-platform-portfolio\README.md
aws-platform-portfolio\docs\security.md
aws-platform-portfolio\docs\phase1-local-api-setup.md
aws-platform-portfolio\docs\operations.md
aws-platform-portfolio\docs\cost.md
aws-platform-portfolio\docs\architecture.md
```

## 補足: apply_patchについて

今回、ファイル作成やMarkdown修正は `apply_patch` という編集用ツールで行いました。

これはPowerShellコマンドではありませんが、以下のファイルを作成・更新しました。

- `aws-platform-portfolio/README.md`
- `aws-platform-portfolio/.gitignore`
- `aws-platform-portfolio/app/package.json`
- `aws-platform-portfolio/app/src/index.js`
- `aws-platform-portfolio/app/Dockerfile`
- `aws-platform-portfolio/app/.dockerignore`
- `aws-platform-portfolio/docs/architecture.md`
- `aws-platform-portfolio/docs/operations.md`
- `aws-platform-portfolio/docs/security.md`
- `aws-platform-portfolio/docs/cost.md`
- `aws-platform-portfolio/docs/phase1-local-api-setup.md`
- `aws-platform-portfolio/docs/phase1-command-log.md`

## 今回の重要コマンドだけ抜粋

自分で最低限再現するなら、特に重要なのは以下です。

```powershell
cd C:\Users\siton\Documents\Codex\career\aws-platform-portfolio\app
npm install
npm start
```

別のPowerShellで確認:

```powershell
Invoke-RestMethod -Uri 'http://localhost:3000/health'
```

Dockerで確認:

```powershell
docker build -t aws-platform-api .
docker run --rm -p 3000:3000 aws-platform-api
```

別のPowerShellで確認:

```powershell
Invoke-RestMethod -Uri 'http://localhost:3000/health'
```
