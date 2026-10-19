FROM alpine:3.20

ARG CLASH_VERSION="v1.19.32"
ARG METACUBEXD_VERSION="v1.273.1"
# 可选: 替换 apk 软件源镜像(国内构建可传 mirrors.aliyun.com 等加速)
ARG APK_MIRROR=""


ADD https://ghfast.top/https://github.com/MetaCubeX/mihomo/releases/download/$CLASH_VERSION/mihomo-linux-amd64-compatible-$CLASH_VERSION.gz /opt/clash-linux-amd64-$CLASH_VERSION.gz
ADD https://fastly.jsdelivr.net/gh/Dreamacro/maxmind-geoip@release/Country.mmdb /root/conf/Country.mmdb
ADD https://ghfast.top/https://github.com/MetaCubeX/metacubexd/releases/download/$METACUBEXD_VERSION/compressed-dist.tgz /root/compressed-dist.tgz
COPY ./scripts/run.bash /bin/run
COPY ./scripts/dl-clash-conf.bash /bin/dl-clash-conf
COPY ./scripts/update-clash-conf.bash /bin/update-clash-conf
COPY ./scripts/update-yaml.rb  /bin/update-yaml.rb

# 配置文件地址
ENV CONF_URL=http://test.com
# 配置文件更新频率
ENV UPDATE_INTERVAL=86400
# 启动时配置下载失败的重试间隔
ENV RETRY_INTERVAL=30
# 面板版本, 用于生成 external-ui-url(保证自动下载的面板与镜像内置版本一致)
ENV METACUBEXD_VERSION=$METACUBEXD_VERSION
# 核心版本, 用于生成订阅请求的 User-Agent(与 mihomo 自身请求保持一致)
ENV CLASH_VERSION=$CLASH_VERSION
# RESTful API 地址, 可为空
ENV EXTERNAL_BIND="127.0.0.1"
ENV EXTERNAL_PORT="9090"
# RESTful API 鉴权
ENV EXTERNAL_SECRET=""

RUN if [ -n "$APK_MIRROR" ]; then \
      sed -i "s|dl-cdn.alpinelinux.org|$APK_MIRROR|g" /etc/apk/repositories; \
    fi \
    && apk -U --no-cache add wget \
    curl \
    bash \
    ruby \
    tzdata \
    && gzip -d /opt/clash-linux-amd64-$CLASH_VERSION.gz \
    && chmod +x /opt/clash-linux-amd64-$CLASH_VERSION \
    && ln -s /opt/clash-linux-amd64-$CLASH_VERSION /bin/clash \
    && chmod +x /bin/run \
    && chmod +x /bin/update-clash-conf \
    && chmod +x /bin/dl-clash-conf \
    && chmod +x /bin/update-yaml.rb \
    && mkdir -p /root/data \
    && mkdir /root/conf/ui \
    && tar xf /root/compressed-dist.tgz -C /root/conf/ui \
    && rm /root/compressed-dist.tgz

ENTRYPOINT ["run"]
