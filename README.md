# Artifactory Community Edition for C/C++

Conan 向けの Artifactory C++ CE と PostgreSQL を Docker Compose で起動します。
ルートの `docker-compose.yml` を使用してください。

大規模 C++ 開発向けの提案は [Visual Studio・Conan・Artifactory 運用フロー](docs/cpp-conan-artifactory-workflow.md) を参照してください。

## 起動

Docker Engine と Docker Compose v2 が必要です。現設定はローカル検証向けで、
Artifactory のメモリ上限は 4 GiB、JVM ヒープ上限は 2 GiB です。
ホストには PostgreSQL・OS 分の余裕も確保してください。
運用環境では [JFrog の要件](https://docs.jfrog.com/installation/docs/general-system-requirements)
に合わせてリソースを見直してください。

```bash
cp .env.example .env  # 初回のみ。既存の .env は上書きしない
```

`.env` の `DB_PASSWORD` に任意の強いパスワードを設定します。未設定では起動しません。
`DB_NAME` と `DB_USER` は必要に応じて変更できます。

```bash
mkdir -p .volumes/artifactory .volumes/postgres
sudo chown -R 1030:1030 .volumes/artifactory
docker compose up -d
docker compose logs -f artifactory
```

初期化には数分かかります。`All services started successfully` が起動完了の目安です。

```bash
bash check-status.sh
```

このスクリプトは Router のヘルスチェックに失敗すると非ゼロで終了します。
`healthy` でもブラウザのログイン成功までは保証しないため、初回はログインも確認してください。

## ログインと Conan

- UI: http://localhost:8092/ui/
- 初期認証: `admin` / `password`。ログイン後に管理者パスワードを変更してください。
- DB 接続用の `DB_PASSWORD` と UI のパスワードは別です。
- ホストの `8092` は Router の `8082`、`8091` は Artifactory の `8081` に対応します。

UI で Local リポジトリを作成し、Package Type を `Conan`、名前を `conan-local` にします。
[Conan 2](https://docs.conan.io/2/reference/commands/remote.html) の設定例:

```bash
conan remote add artifactory http://localhost:8092/artifactory/api/conan/conan-local
conan remote login artifactory admin
```

パスワードはプロンプトで入力します。

## 停止・設定変更

```bash
docker compose down              # データを保持して停止
docker compose up -d             # 起動・Compose 設定変更の反映
docker compose logs --tail 100 artifactory
docker stats --no-stream
```

環境変数の変更は `docker compose restart` だけでは反映されません。

`JF_JFCONNECT_ENABLED=false` は、CE に含まれない JFConnect への問い合わせを止めます。
無効化しないと `First-time entitlement fetch failed` / HTTP 404 が繰り返され、
ログインで待ち続ける場合があります。
[同様の報告と回避策](https://github.com/jfrog/charts/issues/2233)があります。
設定は Compose の環境変数に集約しています。

## データと更新時の注意

- `.volumes/artifactory/`: 設定・鍵・アーティファクト（コンテナの UID/GID `1030:1030` に書き込み権限が必要）
- `.volumes/postgres/`: PostgreSQL のデータ（所有者はコンテナの初期化時に設定）

リポジトリ内の `.volumes/` をコンテナに直接マウントします。Git の管理対象外です。
`docker compose down -v` でもこのディレクトリのデータは削除されません。
既存の名前付きボリュームから切り替える場合は、両サービスを停止し、
所有者・権限を保持してそれぞれのデータを上記ディレクトリへコピーしてから起動してください。
空のディレクトリをマウントすると新規環境として初期化されます。

Artifactory は `latest`、PostgreSQL は `17-alpine` を使用します（ダイジェスト指定なし）。
PostgreSQL は [Artifactory のサポート範囲](https://docs.jfrog.com/installation/docs/artifactory-database-requirements)
に合わせてメジャー番号を指定し、17 系の最新パッチを利用します。
イメージの取得・更新は `docker compose pull`、反映は `docker compose up -d` です。
更新前はサービスを停止して `.volumes/` 全体と `.env` を所有者・権限ごとバックアップし、
復元できることを確認してください。DB 更新後はイメージだけ戻しても復旧できない場合があります。
PostgreSQL のメジャーバージョン変更には別途 DB 移行が必要です。

既存 DB に対して `.env` の `DB_PASSWORD` / `DB_USER` / `DB_NAME` を変更しても、
DB 内の認証情報や DB 名は変わりません。先に DB 側を変更し、Compose の設定と揃えてください。

現在のポート設定は全インターフェースに HTTP で公開します。
ローカル限定ならポート設定を `127.0.0.1:8091:8081` と
`127.0.0.1:8092:8082` に変更してください。
他の端末から利用する運用では HTTPS とアクセス制限を用意してください。
