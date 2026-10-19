#!/usr/bin/env bash
# 更新配置文件
set -uo pipefail
ConfFile=$1

# 未配置 RESTful API 则无法热重载
if [[ -z "${EXTERNAL_BIND:-}" || -z "${EXTERNAL_PORT:-}" ]]
then
  exit 0
fi
# 下载文件(失败时已有配置不会被破坏)
if ! dl-clash-conf "$ConfFile"; then
  echo "配置更新失败, 保留当前配置"
  exit 1
fi
# 文件下载成功, 进行更新
if [[ -n "${EXTERNAL_SECRET:-}" ]]
then
  curl -fsS -H "Authorization: Bearer $EXTERNAL_SECRET" -X PUT -d "{\"path\": \"$ConfFile\"}" "127.0.0.1:$EXTERNAL_PORT/configs?force=true"
else
  curl -fsS -X PUT -d "{\"path\": \"$ConfFile\"}" "127.0.0.1:$EXTERNAL_PORT/configs?force=true"
fi
