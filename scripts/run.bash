#!/usr/bin/env bash
set -uo pipefail

# clash 运行目录(镜像内置: Country.mmdb / ui)
ClashDir="/root/conf"
# 配置文件(持久化目录, 由 volume 挂载)
ConfFile="/root/data/config.yaml"

# 首次下载; 失败且本地已有配置时沿用旧配置启动, 否则重试
until dl-clash-conf "$ConfFile"; do
  if [[ -s "$ConfFile" ]]; then
    echo "配置下载失败, 沿用已有配置: $ConfFile"
    break
  fi
  echo "配置下载失败且本地无可用配置, ${RETRY_INTERVAL}s 后重试..."
  sleep "$RETRY_INTERVAL"
done

# 启动定时下载配置文件(输出到容器日志, 便于观察更新是否成功)
if [[ -n "${UPDATE_INTERVAL:-}" ]]
then
  nohup bash -c "while true; do sleep $UPDATE_INTERVAL; update-clash-conf $ConfFile; done" &
fi

# 启动代理
# cache.db 存运行状态(节点选择 profile.store-selected / fake-ip / etag 等),
# mihomo 默认写在运行目录, 容器重建(如升级镜像)会丢; 软链到持久化目录保住节点选择
ln -sf "$(dirname "$ConfFile")/cache.db" "$ClashDir/cache.db"

# SAFE_PATHS: 允许 RESTful API 读写配置目录, 否则热重载会被拒绝(path is not subpath of home directory)
export SAFE_PATHS="$(dirname "$ConfFile"):$ClashDir"
exec clash -d $ClashDir -f $ConfFile
