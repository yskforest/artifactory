# Artifactory Community Edition for C/C++

Conan 向けの Artifactory C++ CE と PostgreSQL を Docker Compose で起動します。
自己署名証明書を使う NGINX を入口にし、HTTPS（443番）で公開します。

大規模 C++ 開発向けの提案は [Visual Studio・Conan・Artifactory 運用フロー](docs/cpp-conan-artifactory-workflow.md) を参照してください。
自己署名証明書による HTTPS 化は [設定手順](docs/https-patterns.md) にまとめています。

## クイックリファレンス

```bash
# --- 初回セットアップ ---
bash setup.sh                            # .env 作成、ボリューム準備、自己署名証明書の作成
# ※ 起動前に .env の DB_PASSWORD（社内利用時は HTTPS_HOSTNAME も）を設定

# --- 起動・状態確認・停止 ---
docker compose up -d                     # バックグラウンドで起動・設定変更の反映
docker compose logs -f artifactory       # 初期化・起動ログの追跡
bash check-status.sh                     # コンテナ状態と Router ヘルスチェック
docker stats --no-stream                 # リソース使用量の確認
docker compose restart nginx             # NGINX の再起動（テンプレート変更・Artifactory 再作成時）
docker compose down                      # データを保持して停止
```

## 起動

Docker Engine と Docker Compose v2 が必要です。現設定はローカル検証向けで、
Artifactory のメモリ上限は 4 GiB、JVM ヒープ上限は 2 GiB です。
ホストには PostgreSQL・OS 分の余裕も確保してください。
運用環境では [JFrog の要件](https://docs.jfrog.com/installation/docs/general-system-requirements)
に合わせてリソースを見直してください。

初回のみ `setup.sh` を実行します。以下の処理をまとめて行います（既存の `.env` や証明書は上書きしません）。

- `.env` がない場合、`.env.example` から作成
- `.volumes/artifactory` と `.volumes/postgres` の作成および `1030:1030` の権限設定（`sudo` を使用）
- `.env` の `HTTPS_HOSTNAME`（未設定時は `localhost`）または第1引数で指定した名前を使い、`.volumes/nginx/certs/` に `server.key`、`server.crt`、`server.cer` を作成

```bash
bash setup.sh              # localhost または .env の HTTPS_HOSTNAME で作成
# bash setup.sh 接続するDNS名  # 社内 DNS 名を直接指定して作成する場合
```

OpenSSL 3 を使用します。証明書の配布・Windows への信頼登録は [HTTPS 手順](docs/https-patterns.md) を参照してください。
共有するのは `server.crt`（Conan 用）や `server.cer`（Windows 登録用）のみで、秘密鍵の `server.key` はサーバーに保管します。

`.env` の `DB_PASSWORD` に任意の強いパスワードを設定します。未設定では起動しません。
`DB_NAME` と `DB_USER` は必要に応じて変更できます。
`HTTPS_HOSTNAME` は証明書と一致する接続先の DNS 名に設定します（初期値は `localhost`）。
`HTTPS_PORT` は公開する HTTPS ポート番号です（初期値は `443`）。別のポート（例: `8443`）で公開する場合は `.env` で変更してください（証明書の再作成は不要です）。
チーム利用では社内 DNS 名に変更し、各端末からサーバーの IP へ名前解決できるようにしてください。
IP アドレスではなく DNS 名で接続する構成です。

```bash
docker compose up -d
docker compose logs -f artifactory
```

初期化には数分かかります。Artifactory が healthy になった後、NGINX が起動します。
`HTTPS_PORT`（初期値443番）が他のサービスで使用されていないことを確認してください。

```bash
bash check-status.sh
```

このスクリプトは Router のヘルスチェックに失敗すると非ゼロで終了します。
`healthy` でもブラウザのログイン成功までは保証しないため、初回はログインも確認してください。

## ログインと Conan

- UI: https://localhost/ui/（社内利用やポート変更時は `https://HTTPS_HOSTNAME:HTTPS_PORT/ui/`）
- 初期認証: `admin` / `password`。ログイン後に管理者パスワードを変更してください。
- DB 接続用の `DB_PASSWORD` と UI のパスワードは別です。
- 公開するのは NGINX の `HTTPS_PORT`（初期値443番）のみです。Artifactory の8081/8082、PostgreSQL は直接公開しません。

UI で Local リポジトリを作成し、Package Type を `Conan`、名前を `conan-local` にします。
[Conan 2](https://docs.conan.io/2/reference/commands/remote.html) の設定例:

Conan の `global.conf` に、配布した証明書のパスを設定します（Windows の例）。
既存の証明書バンドルを使用している場合は、この証明書を追加したバンドルを指定してください。

```ini
core.net.http:cacert_path=C:/company/certs/server.crt
```

```bash
conan remote add artifactory https://localhost/artifactory/api/conan/conan-local
conan remote login artifactory admin
```

パスワードはプロンプトで入力します。社内利用では URL の `localhost` を接続する DNS 名へ変更します。
自己署名でも証明書検証を有効にし、`--insecure` で回避しないでください。
既存 remote の URL は `conan remote update artifactory --url=https://接続名/artifactory/api/conan/conan-local` で更新します。

## 停止・設定変更

```bash
docker compose down              # データを保持して停止
docker compose up -d             # 起動・Compose 設定変更の反映
docker compose logs --tail 100 artifactory
docker stats --no-stream
```

環境変数の変更は `docker compose restart` だけでは反映されません。
NGINX の設定テンプレートを変更した場合、または Artifactory を再作成した場合は、
`docker compose restart nginx` を実行して設定・転送先の名前解決を更新します。

証明書の有効期限は10年（3650日）です。期限の確認と更新（延長）は以下の手順で行います。

```bash
# 有効期限の確認（notAfter が満了日時）
openssl x509 -in .volumes/nginx/certs/server.crt -noout -dates

# 証明書の再作成（延長）と NGINX への反映
rm -f .volumes/nginx/certs/server.{key,crt,cer}
bash setup.sh
docker compose exec -T nginx nginx -t && docker compose exec -T nginx nginx -s reload
```

再作成後は、新しい `server.crt` / `server.cer` をクライアント端末へ再配布して信頼登録してください。

`JF_JFCONNECT_ENABLED=false` は、CE に含まれない JFConnect への問い合わせを止めます。
無効化しないと `First-time entitlement fetch failed` / HTTP 404 が繰り返され、
ログインで待ち続ける場合があります。
[同様の報告と回避策](https://github.com/jfrog/charts/issues/2233)があります。
設定は Compose の環境変数に集約しています。

## データと更新時の注意

- `.volumes/artifactory/`: 設定・鍵・アーティファクト（コンテナの UID/GID `1030:1030` に書き込み権限が必要）
- `.volumes/postgres/`: PostgreSQL のデータ（所有者はコンテナの初期化時に設定）
- `.volumes/nginx/certs/`: 自己署名証明書と秘密鍵

リポジトリ内の `.volumes/` をコンテナに直接マウントします。Git の管理対象外です。
`docker compose down -v` でもこのディレクトリのデータは削除されません。
既存の名前付きボリュームから切り替える場合は、両サービスを停止し、
所有者・権限を保持してそれぞれのデータを上記ディレクトリへコピーしてから起動してください。
空のディレクトリをマウントすると新規環境として初期化されます。

Artifactory は `latest`、PostgreSQL は `17-alpine`、NGINX は `stable-alpine` を使用します（ダイジェスト指定なし）。
PostgreSQL は [Artifactory のサポート範囲](https://docs.jfrog.com/installation/docs/artifactory-database-requirements)
に合わせてメジャー番号を指定し、17 系の最新パッチを利用します。
イメージの取得・更新は `docker compose pull`、反映は `docker compose up -d` です。
更新前はサービスを停止して `.volumes/` 全体と `.env` を所有者・権限ごとバックアップし、
復元できることを確認してください。DB 更新後はイメージだけ戻しても復旧できない場合があります。
PostgreSQL のメジャーバージョン変更には別途 DB 移行が必要です。

既存 DB に対して `.env` の `DB_PASSWORD` / `DB_USER` / `DB_NAME` を変更しても、
DB 内の認証情報や DB 名は変わりません。先に DB 側を変更し、Compose の設定と揃えてください。

現在のポート設定は全インターフェースの `HTTPS_PORT`（初期値443番）に公開します。
ローカル限定なら NGINX のポート設定を `127.0.0.1:${HTTPS_PORT:-443}:443` に変更してください。
チーム利用ではファイアウォール等で接続元を制限してください。
