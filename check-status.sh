#!/bin/bash

echo "=== Artifactoryのステータス確認 ==="
echo ""

# コンテナのステータス
echo "1. コンテナステータス:"
docker compose ps

echo ""
echo "2. ヘルスチェック:"
curl -s http://localhost:8092/router/api/v1/system/health | jq . 2>/dev/null || curl -s http://localhost:8092/router/api/v1/system/health

echo ""
echo "3. システム情報:"
curl -s http://localhost:8092/router/api/v1/system/ping 2>/dev/null || echo "まだ起動中です..."

echo ""
echo "4. 最新のログ（最後の20行）:"
docker compose logs --tail=20 artifactory | grep -E "(INFO|WARN|ERROR|Started)"

echo ""
echo "=== アクセスURL ==="
echo "Artifactory UI: http://localhost:8091"
echo "デフォルト認証: admin / password"
