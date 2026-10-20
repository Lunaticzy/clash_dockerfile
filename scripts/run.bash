#!/usr/bin/env bash
set -uo pipefail

# clash 运行目录, 也是持久化目录(由 volume 挂载):
# 配置 config.yaml / 运行状态 cache.db / 面板 ui / Country.mmdb 都在这里
ClashDir="/root/conf"
# 镜像内置资源(挂载会遮蔽 /root/conf, 启动时从这里补齐)
AssetsDir="/opt/clash-assets"
ConfFile="$ClashDir/config.yaml"
UiDir="$ClashDir/ui"
UiStamp="$UiDir/.metacubexd-version"

mkdir -p "$ClashDir"

# 面板: 版本不符或缺失时用镜像内置版本铺设, 否则保留(允许用户自行替换)
if [[ "$(cat "$UiStamp" 2>/dev/null)" != "${METACUBEXD_VERSION:-}" ]]; then
  echo "铺设内置面板 ${METACUBEXD_VERSION:-unknown} ..."
  rm -rf "$UiDir"
  cp -r "$AssetsDir/ui" "$UiDir"
  printf '%s' "${METACUBEXD_VERSION:-}" > "$UiStamp"
fi

# 地理库: 缺失时补齐, 已存在则保留(允许用户自行替换)
[ -e "$ClashDir/Country.mmdb" ] || cp "$AssetsDir/Country.mmdb" "$ClashDir/Country.mmdb"

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
# 配置与 cache.db 都在运行目录内, 无需额外设置 SAFE_PATHS
exec clash -d $ClashDir -f $ConfFile
