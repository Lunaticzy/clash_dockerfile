# 根据订阅地址自动更新与运行的 Clash 镜像

## 使用方法

1. **修改订阅地址**：将 `CONF_URL` 环境变量设置为您的 Clash 订阅地址。
2. **配置环境变量**：根据您的需求配置其他环境变量。
3. **启动服务**：运行 `docker-compose up` 命令来启动 Clash 服务。

## docker-compose.yml 示例

```yaml
version: '3.8'
services:
  clash:
    image: 9527tech/clash:latest  # 确保使用最新版本的镜像
    container_name: clash
    ports:
      - "7890:7890" # 用于代理的端口 mixed-port
      - "9090:9090" # RESTful API 端口
    environment:
      - CONF_URL=https://your-subscription-url  # 替换为您的订阅地址
      - EXTERNAL_BIND=0.0.0.0
      - EXTERNAL_PORT=9090
      - TZ=Asia/Shanghai
      - DEFAULT_BACKEND=http://your-default-backend-ip:9090 # 端口同 EXTERNAL_PORT
    restart: unless-stopped
```

### 注意事项

- 确保将 `https://your-subscription-url` 替换为您的实际订阅地址。
- `DEFAULT_BACKEND` 用于 UI 中的默认后端地址，如果您不需要修改 UI 中的默认后端，可以忽略此环境变量。
- 要使用 Clash 的 RESTful API，请确保您的其他软件配置了正确的端口（本例中为 `9090`）。

## 访问管理 UI

要使用 Clash 自带的管理 UI，请访问以下地址：

```
http://<您的服务器IP>:9090/ui
```

请将 `<您的服务器IP>` 替换为您服务器的实际 IP 地址。

