FROM alpine:3.9

ARG CLASH_VERSION="v1.18.0"
ARG METACUBEXD_VERSION="v1.134.0"
ARG YQ_VERSION="v4.40.5"

ADD https://github.com/MetaCubeX/mihomo/releases/download/$CLASH_VERSION/mihomo-linux-amd64-compatible-$CLASH_VERSION.gz /opt/clash-linux-amd64-$CLASH_VERSION.gz
ADD https://cdn.jsdelivr.net/gh/Dreamacro/maxmind-geoip@release/Country.mmdb /root/conf/Country.mmdb
ADD https://github.com/MetaCubeX/metacubexd/releases/download/$METACUBEXD_VERSION/compressed-dist.tgz /root/compressed-dist.tgz
ADD https://github.com/mikefarah/yq/releases/download/$YQ_VERSION/yq_linux_amd64 /bin/yq
COPY ./run.bash /bin/run
COPY ./dl-clash-conf.bash /bin/dl-clash-conf
COPY ./update-clash-conf.bash /bin/update-clash-conf
# COPY sources.list /etc/apt/

# 配置文件地址
ENV CONF_URL http://test.com
# 配置文件更新频率
ENV UPDATE_INTERVAL 86400
# RESTful API 地址, 可为空
ENV EXTERNAL_BIND "127.0.0.1"
ENV EXTERNAL_PORT "9090"
# RESTful API 鉴权
ENV EXTERNAL_SECRET ""

RUN apk -U --no-cache add wget \
    curl \
    bash \
    && gzip -d /opt/clash-linux-amd64-$CLASH_VERSION.gz \
    && chmod +x /opt/clash-linux-amd64-$CLASH_VERSION \
    && ln -s /opt/clash-linux-amd64-$CLASH_VERSION /bin/clash \
    && chmod +x /bin/run \
    && chmod +x /bin/update-clash-conf \
    && chmod +x /bin/dl-clash-conf \
    && chmod +x /bin/yq \
    && mkdir /root/ui \
    && tar xf /root/compressed-dist.tgz -C /root/ui \
    && rm /root/compressed-dist.tgz

ENTRYPOINT ["run"]
