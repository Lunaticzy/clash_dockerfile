#!/usr/bin/env bash

ConfFile="/root/conf/config.yaml"

dl-clash-conf $ConfFile
# 启动定时下载配置文件
if [[ ! -z "$UPDATE_INTERVAL" ]]
then
  nohup bash -c "while true; do sleep $UPDATE_INTERVAL; update-clash-conf $ConfFile; done" >> /dev/null 2>&1 &
fi

# 启动代理
ConfPath=`dirname $ConfFile`
exec clash -d $ConfPath -f $ConfFile

