#!/usr/bin/env bash

# 下载配置文件
ConfFile=$1
ConfPath=$(dirname "$ConfFile")
mkdir -p "$ConfPath"
wget -O "$ConfFile" "$CONF_URL"
if [ $? -ne 0 ]; then
  echo "config file download fail"
  exit 1
fi

if [[ ! -z "$DEFAULT_BACKEND" ]]
then
  echo "修改管理面板默认后端..."
  sed -i "s|http://127.0.0.1:9090|$DEFAULT_BACKEND|g" /root/ui/assets/Setup-*.js
fi

# 调用 Ruby 脚本来更新配置文件
update-yaml.rb "$ConfFile"

echo "Configuration file updated successfully."