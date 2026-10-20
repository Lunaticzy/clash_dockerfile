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
    volumes:
      - ./data:/root/data # 持久化配置文件
    restart: unless-stopped
```

### 注意事项

- 确保将 `https://your-subscription-url` 替换为您的实际订阅地址。
- `DEFAULT_BACKEND` 用于 UI 中的默认后端地址，如果您不需要修改 UI 中的默认后端，可以忽略此环境变量。
- 要使用 Clash 的 RESTful API，请确保您的其他软件配置了正确的端口（本例中为 `9090`）。

## 配置文件持久化

配置文件保存在容器内的 `/root/data/config.yaml`，通过 `./data:/root/data` 挂载到宿主机。这样即使订阅地址临时不可用（例如机场要求先在后台手动开启订阅、订阅到期、网络故障），容器重启后仍可用上一次成功下载的配置启动，不会因为拉不到配置而无法运行。

下载行为：

- 先下载到临时文件并校验（必须是合法 YAML 且含非空 `proxies` / `proxy-providers`），通过后才替换正式配置。**下载失败或内容异常时不会覆盖已有配置。**
- 启动时若下载失败但本地已有配置，直接沿用旧配置启动。
- 启动时若下载失败且本地无配置，每 `RETRY_INTERVAL` 秒重试一次（默认 30 秒），机场后台开启订阅后会自动恢复。
- 运行期间按 `UPDATE_INTERVAL` 定时更新，更新失败时保留当前配置、不触发热重载。
- 订阅请求的 `User-Agent` 为 `clash.meta/<核心版本>`（如 `clash.meta/v1.19.32`），与 mihomo 自身请求所用 UA 一致。部分机场按 UA 下发不同配置，因此该值随 `CLASH_VERSION` 构建参数自动跟随，不再硬编码。

## 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `CONF_URL` | `http://test.com` | 订阅地址 |
| `UPDATE_INTERVAL` | `86400` | 配置更新间隔（秒），留空则不定时更新 |
| `RETRY_INTERVAL` | `30` | 启动时下载失败的重试间隔（秒） |
| `EXTERNAL_BIND` | `127.0.0.1` | RESTful API 监听地址 |
| `EXTERNAL_PORT` | `9090` | RESTful API 端口 |
| `EXTERNAL_SECRET` | 空 | RESTful API 鉴权密钥 |
| `DEFAULT_BACKEND` | 空 | UI 中的默认后端地址 |
| `TZ` | 空 | 时区，如 `Asia/Shanghai` |

## 访问管理 UI

要使用 Clash 自带的管理 UI，请访问以下地址：

```
http://<您的服务器IP>:9090/ui
```

请将 `<您的服务器IP>` 替换为您服务器的实际 IP 地址。

### 面板版本与默认后端

镜像内置 [metacubexd](https://github.com/MetaCubeX/metacubexd) 面板，版本由构建参数 `METACUBEXD_VERSION` 固定，**不依赖运行时下载**。

- 设置 `DEFAULT_BACKEND` 后，启动时会写入 `/root/conf/ui/config.js`：

  ```js
  window.__METACUBEXD_CONFIG__ = {
    defaultBackendURL: 'http://your-default-backend-ip:9090',
    githubToken: '',
  }
  ```

  这是 metacubexd **v1.215.0+** 的配置方式。旧版本（v1.220.0 之前打包产物中的 `assets/Setup-*.js`）已不再使用，因此 `METACUBEXD_VERSION` 不应低于 `v1.215.0`。

  该值不只是预填输入框：浏览器首次打开面板（本地无已保存后端）时会**自动连接**，直接进入概览页，无需手动点 Connect。已保存的后端不可达时也会回落到它。

  > `DEFAULT_BACKEND` 必须是**浏览器**能访问到的地址，不是容器内能访问到的地址。填 `127.0.0.1:9090` 或容器名只在浏览器与容器同机时才成立；跨机访问要填宿主机 IP 或对外域名。

- mihomo 自身也支持自动下载面板（`external-ui-url`，仅在 `external-ui` 目录为空时触发）。镜像已内置面板，启动日志会显示 `UI already exists, skip downloading`，不会覆盖内置版本。若你用一个空目录挂载覆盖 `/root/conf/ui`，mihomo 会按 `external-ui-url` 下载——该地址已被固定为与镜像相同的 `METACUBEXD_VERSION`，保证版本一致。

## 自行构建镜像

```bash
# 国内网络建议指定 apk 软件源镜像加速(默认使用官方源)
docker build --build-arg APK_MIRROR=mirrors.aliyun.com -t clash:latest .
```

可用的构建参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `CLASH_VERSION` | `v1.19.32` | mihomo 版本 |
| `METACUBEXD_VERSION` | `v1.273.1` | metacubexd 面板版本（不得低于 `v1.215.0`） |
| `APK_MIRROR` | 空 | 替换 apk 软件源主机名，如 `mirrors.aliyun.com`（实测 `mirrors.ustc.edu.cn` 会 302 跳回官方 CDN，无效） |

## 端到端测试

`tests/e2e.sh` 用一个模拟机场订阅服务端（`tests/mock-subscription-server.py`）驱动真实容器，覆盖下载降级、持久化、热重载、面板与 UA 等行为：

```bash
APK_MIRROR=mirrors.aliyun.com tests/e2e.sh          # 镜像不存在时自动构建
tests/e2e.sh --build                                # 强制重新构建
IMAGE=clash:latest tests/e2e.sh --no-build          # 测已有镜像
```

依赖 `docker`、`python3`、`curl`。脚本自行挑选空闲端口、自动探测 docker 网桥网关，退出时清理容器与临时目录；全部通过退出码为 0。

覆盖场景：

| 场景 | 断言要点 |
| --- | --- |
| 订阅不可用 + 无本地配置 | 不生成配置、不启动 clash、按 `RETRY_INTERVAL` 重试 |
| 机场后台开启订阅 | 自动恢复、配置落盘、API 可用、时区生效 |
| 订阅请求 UA | 等于 `clash.meta/<容器内 CLASH_VERSION>` |
| 面板 | UI 与 `config.js` 可访问、默认后端已写入、跳过自动下载 |
| 运行中订阅失效 | 配置未被覆盖、无残留临时文件、clash 不重启 |
| 订阅恢复且内容变化 | 配置更新、热重载无 400、新旧节点正确切换 |
| 订阅不可用时重启 | 沿用旧配置启动，配置未被破坏 |

