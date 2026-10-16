#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo ".env を作成しました。DB_PASSWORD（必要に応じて HTTPS_HOSTNAME）を確認・設定してください。"
fi

mkdir -p .volumes/artifactory .volumes/postgres
sudo chown -R 1030:1030 .volumes/artifactory

cert_dir=".volumes/nginx/certs"
key_file="${cert_dir}/server.key"
crt_file="${cert_dir}/server.crt"
cer_file="${cert_dir}/server.cer"

env_host=$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?HTTPS_HOSTNAME=[[:space:]]*([^#[:space:]]*).*/\2/p' .env | tail -n 1)
env_host="${env_host#\"}"
env_host="${env_host%\"}"
env_host="${env_host#\'}"
env_host="${env_host%\'}"

tls_host="${1:-${HTTPS_HOSTNAME:-${env_host:-localhost}}}"

if [[ -z "${tls_host}" || "${tls_host}" =~ [[:space:],/\'\"\\] ]]; then
  echo "エラー: 不正なホスト名です: ${tls_host}" >&2
  exit 1
fi

if [[ "${tls_host}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || "${tls_host}" == *:* ]]; then
  san_entry="IP:${tls_host}"
else
  san_entry="DNS:${tls_host}"
fi

umask 077
mkdir -p "${cert_dir}"

if [[ -e "${key_file}" || -e "${crt_file}" || -e "${cer_file}" ]]; then
  echo "エラー: ${cert_dir} に既存の証明書または鍵が存在します。上書きせずに終了します。" >&2
  exit 1
fi

openssl req -x509 -newkey rsa:3072 -sha256 -noenc -days 365 \
  -keyout "${key_file}" \
  -out "${crt_file}" \
  -subj "/CN=${tls_host}" \
  -addext "subjectAltName=${san_entry}" \
  -addext 'basicConstraints=critical,CA:FALSE' \
  -addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
  -addext 'extendedKeyUsage=serverAuth'

chmod 644 "${crt_file}"

openssl x509 -in "${crt_file}" -outform DER -out "${cer_file}"
chmod 644 "${cer_file}"

echo
openssl x509 -in "${crt_file}" \
  -noout -subject -dates -ext subjectAltName -fingerprint -sha256
