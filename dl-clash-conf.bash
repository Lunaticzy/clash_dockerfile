#!/usr/bin/env bash
# 下载配置文件

ConfFile=$1
ConfPath=`dirname $ConfFile`
mkdir -p $ConfPath
wget -O $ConfFile  "$CONF_URL"
# 若文件下载失败, 则返回并报错
if [ $? -ne 0 ];
then
  echo "config file download fail"
  exit $?
fi



# 写入 API端口
if [[ ! -z "$EXTERNAL_BIND" && ! -z "$EXTERNAL_PORT" ]]
then
  # echo "external-controller: $EXTERNAL_BIND:$EXTERNAL_PORT" >> $ConfFile
  sed -i "s/external-controller.*/external-controller: ${EXTERNAL_BIND}:${EXTERNAL_PORT}/g" $ConfFile
fi
# 鉴权信息
if [[ ! -z "$EXTERNAL_SECRET" ]]
then
  echo "secret: \"$EXTERNAL_SECRET\"" >> $ConfFile
fi
# 必须开启局域网连接, 否则外部无法连接
# echo "allow-lan: true" >> $ConfFile
sed -i 's/allow-lan.*/allow-lan: true/g' $ConfFile

# 启用mixed-port
sed -i 's/port: 7890/mixed-port: 7890/g' $ConfFile
