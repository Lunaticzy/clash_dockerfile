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

# 调用 Ruby 脚本来更新配置文件
update_config.rb "$ConfFile"

echo "Configuration file updated successfully."