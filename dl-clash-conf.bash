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
  echo "使用监听端口: $EXTERNAL_PORT"
  yq -i '.external-controller = strenv(EXTERNAL_BIND) + ":" + strenv(EXTERNAL_PORT)' $ConfFile
fi

# 鉴权信息
if [[ ! -z "$EXTERNAL_SECRET" ]]
then
  yq -i '.secret = strenv(EXTERNAL_SECRET)' $ConfFile
fi


yq -i '.external-ui = "/root/ui"' $ConfFile


if [[ ! -z "$DEFAULT_BACKEND" ]]
then
  echo "修改管理面板默认后端..."
  sed -i "s|http://127.0.0.1:9090|$DEFAULT_BACKEND|g" /root/ui/assets/Setup-*.js
fi

# 关闭 IPv6
yq -i '.ipv6 = false' $ConfFile

# 必须开启局域网连接, 否则外部无法连接
echo "启用局域网连接..."
yq -i '.allow-lan = true' $ConfFile

# 启用mixed-port
echo "启用mixed-port..."
yq  -i '(.port | key) = "mixed-port"' $ConfFile
