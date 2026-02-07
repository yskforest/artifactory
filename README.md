# JFrog Artifactory Community Edition for C/C++

Docker Composeを使用してJFrog Artifactory Community Edition (C/C++専用)を構築するためのリポジトリです。

## 概要

このリポジトリは、C/C++開発向けのJFrog Artifactory Community Editionを簡単にセットアップできるDocker Compose構成を提供します。

### 含まれるサービス

- **Artifactory**: JFrog Artifactory Community Edition (C/C++対応)
- **PostgreSQL**: Artifactoryのメタデータストレージ

## 必要な要件

- Docker Engine 20.10以上
- Docker Compose 2.0以上
- 最低4GB以上の空きメモリ

## セットアップ手順

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd artifactory
```

### 2. 環境変数の設定

`.env.example`をコピーして`.env`ファイルを作成し、必要に応じて編集してください：

```bash
cp .env.example .env
```

**重要**: 本番環境では必ず`DB_PASSWORD`を強力なパスワードに変更してください。

### 3. Artifactoryの起動

```bash
docker compose up -d
```

初回起動時は、Artifactoryの初期化に数分かかります。

### 4. 起動確認

```bash
docker compose logs -f artifactory
```

ログに`Artifactory successfully started`のようなメッセージが表示されたら準備完了です。

## アクセス方法

- **Artifactory UI**: http://localhost:8092
- **デフォルト管理者ユーザー名**: `admin`
- **デフォルトパスワード**: `password`

**ログイン手順**:
1. ブラウザで http://localhost:8092 にアクセス
2. ログイン画面で以下を入力：
   - Username: `admin`
   - Password: `password`
3. 初回ログイン後、パスワード変更が求められます

**トラブルシューティング**:
- ログインできない場合は、ブラウザのキャッシュをクリアしてください
- `curl -u admin:password http://localhost:8092/artifactory/api/system/ping` でAPIが応答するか確認できます

## C/C++リポジトリの設定

### Conanリポジトリの作成

1. Artifactory UIにログイン
2. "Administration" → "Repositories" → "Repositories"
3. "Add Repositories" → "Local Repository"
4. Package Type: "Conan"を選択
5. Repository Key: `conan-local`などの名前を入力
6. "Save & Finish"をクリック

### 基本的なConan設定

```bash
# Conanリモートの追加
conan remote add artifactory http://localhost:8081/artifactory/api/conan/conan-local

# 認証情報の設定
conan user -p <password> -r artifactory admin
```

## よく使うコマンド

### サービスの起動
```bash
docker compose up -d
```

### サービスの停止
```bash
docker compose down
```

### ログの確認
```bash
docker compose logs -f
```

### データの完全削除（注意: すべてのデータが削除されます）
```bash
docker compose down -v
```

### サービスの再起動
```bash
docker compose restart
```

## パフォーマンス改善（WSL + Docker）

以下の設定で体感速度が改善します：

- **WSL上のLinuxファイルシステムで実行**（/mnt/c などのWindows側は遅くなりがち）
- Docker Desktopのリソース設定で **CPU/メモリ割当を増やす**
- ArtifactoryのJVMヒープを増やす（run.shで設定済み）

run.shに以下の最適化が入っています：

- `--cpus=4` / `--memory=6g`
- `EXTRA_JAVA_OPTIONS=-Xms1g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200`

必要に応じて値を増減してください。

## データの永続化

以下のDockerボリュームにデータが保存されます：

- `artifactory_data`: Artifactoryのデータとアーティファクト
- `postgres_data`: PostgreSQLのデータベース

## トラブルシューティング

### Artifactoryが起動しない

1. メモリ不足の確認：
```bash
docker stats
```

2. ログの確認：
```bash
docker compose logs artifactory
```

3. サービスの再起動：
```bash
docker compose restart
```

### データベース接続エラー

PostgreSQLが完全に起動するまで待ってから、Artifactoryを再起動してください：

```bash
docker compose restart artifactory
```

## ポート情報

- `8081`: Artifactory Web UI / API
- `8082`: Artifactory Router (内部通信用)

## ライセンス

このDocker Compose設定はMITライセンスで提供されています。
JFrog Artifactory Community Editionは、JFrogのライセンス条項に従います。

## 参考リンク

- [JFrog Artifactory Documentation](https://jfrog.com/help/r/jfrog-artifactory-documentation)
- [Conan Documentation](https://docs.conan.io/)
- [JFrog Docker Images](https://releases-docker.jfrog.io/)
