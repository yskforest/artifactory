#!/bin/bash

echo "Artifactory管理者パスワードのリセット"
echo "======================================"
echo ""
echo "コンテナ内でパスワードをリセットします..."

docker exec -it artifactory bash -c '
cd /opt/jfrog/artifactory/var/etc/access
if [ -f "bootstrap.creds" ]; then
    echo "ブートストラップ認証情報:"
    cat bootstrap.creds
else
    echo "bootstrap.credsファイルが見つかりません"
fi
'

echo ""
echo "上記の認証情報を使ってログインしてください"
