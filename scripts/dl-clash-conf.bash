#!/usr/bin/env bash
# 下载并更新配置文件
# 先下载到临时文件并校验, 通过后才替换正式配置;
# 这样下载失败(订阅被机场禁用 / 返回 HTML 错误页 / 网络不通)时不会破坏已有配置
set -uo pipefail

ConfFile=$1
ConfPath=$(dirname "$ConfFile")
mkdir -p "$ConfPath"

TmpFile="${ConfFile}.tmp"
rm -f "$TmpFile"

# User-Agent 与 mihomo 自身请求一致(config.go: GlobalUA = "clash.meta/" + Version)
# 部分机场按 UA 下发不同配置, 版本过旧可能拿到降级/异常订阅
UA="clash.meta${CLASH_VERSION:+/${CLASH_VERSION}}"

if ! wget --user-agent="$UA" -O "$TmpFile" "${CONF_URL:-}"; then
  rm -f "$TmpFile"
  echo "config file download fail"
  exit 1
fi

# 校验: 必须是合法 YAML, 且包含非空的 proxies 或 proxy-providers
if ! ruby -ryaml -e '
  d = YAML.load_file(ARGV[0])
  ok = d.is_a?(Hash) && (
    (d["proxies"].is_a?(Array) && !d["proxies"].empty?) ||
    (d["proxy-providers"].is_a?(Hash) && !d["proxy-providers"].empty?)
  )
  exit(ok ? 0 : 1)
' "$TmpFile"; then
  rm -f "$TmpFile"
  echo "downloaded file is not a valid clash config"
  exit 1
fi

if [[ -n "${DEFAULT_BACKEND:-}" ]]
then
  echo "修改管理面板默认后端..."
  # metacubexd v1.215.0+ 由 config.js 提供默认后端(v1.220.0 起不再有 assets/Setup-*.js)
  cat > /root/conf/ui/config.js <<EOF
window.__METACUBEXD_CONFIG__ = {
  defaultBackendURL: '$DEFAULT_BACKEND',
  githubToken: '',
}
EOF
fi

# 调用 Ruby 脚本来更新配置文件
if ! update-yaml.rb "$TmpFile"; then
  rm -f "$TmpFile"
  echo "update-yaml.rb failed"
  exit 1
fi

mv -f "$TmpFile" "$ConfFile"

echo "Configuration file updated successfully."
