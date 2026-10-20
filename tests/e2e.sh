#!/usr/bin/env bash
# 端到端验收脚本
#
# 用一个模拟机场订阅服务端, 覆盖以下场景:
#   1. 订阅不可用且无本地配置 -> 重试, 不启动 clash
#   2. 机场后台开启订阅 -> 自动恢复并启动
#   3. 订阅请求的 User-Agent 与核心版本一致
#   4. 面板内置且默认后端生效, 不触发自动下载
#   5. 运行中订阅失效 -> 保留配置, 不破坏, 不重启
#   6. 订阅恢复且内容变化 -> 热重载生效
#   7. 订阅不可用时重启容器 -> 沿用旧配置启动
#   8. 节点记忆: 配置重载与容器重建后仍记住所选节点
#
# 依赖: docker, python3, curl
# 用法:
#   tests/e2e.sh                    # 镜像不存在时自动构建
#   tests/e2e.sh --build            # 强制重新构建
#   IMAGE=clash:latest tests/e2e.sh --no-build
#
# 环境变量:
#   IMAGE        被测镜像 (默认 clash-e2e:local)
#   APK_MIRROR   构建时传给 Dockerfile 的 apk 源镜像

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")
FIXTURES="$SCRIPT_DIR/fixtures"

IMAGE=${IMAGE:-clash-e2e:local}
APK_MIRROR=${APK_MIRROR:-}
DO_BUILD=auto

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) DO_BUILD=yes; shift ;;
    --no-build) DO_BUILD=no; shift ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

for bin in docker python3 curl; do
  command -v "$bin" >/dev/null || { echo "缺少依赖: $bin" >&2; exit 2; }
done

WORK=$(mktemp -d)
NAME="clash-e2e-$$"
MOCK_PID=""
PASS=0
FAIL=0

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1
  [[ -n "$MOCK_PID" ]] && kill "$MOCK_PID" >/dev/null 2>&1
  # 挂载目录里的文件由容器内 root 创建, 需借容器身份清理
  docker run --rm --entrypoint sh -v "$WORK:/w" "$IMAGE" -c 'rm -rf /w/* /w/.[!.]*' >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

ck() { # ck <描述> <期望> <实际>
  if [[ "$2" == "$3" ]]; then
    echo "  PASS  $1"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $1 (期望=$2 实际=$3)"; FAIL=$((FAIL + 1))
  fi
}
ckge() { # ckge <描述> <最少出现次数> <实际出现次数>
  if [[ "$3" -ge "$2" ]]; then
    echo "  PASS  $1 ($3>=$2)"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $1 (期望>=$2 实际=$3)"; FAIL=$((FAIL + 1))
  fi
}

free_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()'
}

# --- 准备镜像 ---
if [[ "$DO_BUILD" == "yes" ]] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "== 构建镜像 $IMAGE =="
  build_args=()
  [[ -n "$APK_MIRROR" ]] && build_args+=(--build-arg "APK_MIRROR=$APK_MIRROR")
  if ! docker build "${build_args[@]}" -t "$IMAGE" "$REPO_ROOT"; then
    echo "镜像构建失败" >&2; exit 1
  fi
fi

# --- 准备模拟服务端 ---
MOCK_PORT=$(free_port)
API_PORT=$(free_port)
PROXY_PORT=$(free_port)
MODE_FILE="$WORK/mode"
UA_FILE="$WORK/last_ua.txt"
GATEWAY=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}')

python3 "$SCRIPT_DIR/mock-subscription-server.py" \
  --port "$MOCK_PORT" --fixtures "$FIXTURES" \
  --mode-file "$MODE_FILE" --ua-file "$UA_FILE" &
MOCK_PID=$!

for _ in $(seq 1 50); do
  curl -s -o /dev/null "http://127.0.0.1:$MOCK_PORT/" && break
  sleep 0.1
done

API="http://127.0.0.1:$API_PORT"
SUBSCRIPTION="http://$GATEWAY:$MOCK_PORT/sub"
CONF_DIR="$WORK/conf"

echo "镜像=$IMAGE 订阅地址=$SUBSCRIPTION API=$API"

start() {
  docker rm -f "$NAME" >/dev/null 2>&1
  docker run -d --name "$NAME" \
    -e "CONF_URL=$SUBSCRIPTION" \
    -e UPDATE_INTERVAL=4 -e RETRY_INTERVAL=2 \
    -e EXTERNAL_BIND=0.0.0.0 -e EXTERNAL_PORT=9090 \
    -e DEFAULT_BACKEND=http://192.168.1.10:9090 \
    -e TZ=Asia/Shanghai \
    -p "$API_PORT:9090" -p "$PROXY_PORT:7890" \
    -v "$CONF_DIR:/root/conf" "$IMAGE" >/dev/null
}

echo "== 场景1: 订阅不可用 + 无本地配置 -> 重试, 不启动 clash =="
rm -rf "$CONF_DIR"; mkdir -p "$CONF_DIR"
echo html > "$MODE_FILE"
start; sleep 7
ck "未生成配置文件" "0" "$([[ -f "$CONF_DIR/config.yaml" ]] && echo 1 || echo 0)"
ck "内置资源已同步到挂载目录" "1" "$([[ -f "$CONF_DIR/Country.mmdb" && -f "$CONF_DIR/ui/index.html" ]] && echo 1 || echo 0)"
ckge "日志含重试提示" 1 "$(docker logs "$NAME" 2>&1 | grep -c '本地无可用配置')"
ck "clash 未监听 API" "000" "$(curl -s -o /dev/null -m 2 -w '%{http_code}' "$API/version")"

echo "== 场景2: 机场后台开启订阅 -> 自动恢复并启动 =="
echo a > "$MODE_FILE"; sleep 8
ck "配置已落盘" "1" "$([[ -f "$CONF_DIR/config.yaml" ]] && echo 1 || echo 0)"
ck "配置文件属主 root" "root" "$(stat -c %U "$CONF_DIR/config.yaml")"
ck "clash API 可用" "200" "$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$API/version")"
ckge "时区为 CST" 1 "$(docker exec "$NAME" date | grep -c CST)"
ckge "配置含 test-node-1" 1 "$(grep -c test-node-1 "$CONF_DIR/config.yaml")"

echo "== 场景3: 订阅请求的 User-Agent =="
CORE_VERSION=$(docker exec "$NAME" printenv CLASH_VERSION)
ck "容器内 CLASH_VERSION 非空" "1" "$([[ -n "$CORE_VERSION" ]] && echo 1 || echo 0)"
ck "UA 与核心版本一致" "clash.meta/$CORE_VERSION" "$(cat "$UA_FILE")"
ck "UA 非旧硬编码值" "0" "$(grep -c 'v1.18.0' "$UA_FILE" || true)"

echo "== 场景4: 面板 =="
ck "UI 首页可访问" "200" "$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$API/ui/")"
ck "config.js 可访问" "200" "$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$API/ui/config.js")"
ckge "config.js 含默认后端" 1 "$(curl -s -m 3 "$API/ui/config.js" | grep -c 'http://192.168.1.10:9090')"
ck "面板已内置(目录非空)" "1" "$(docker exec "$NAME" sh -c '[ -n "$(ls -A /root/conf/ui)" ] && echo 1 || echo 0')"
ckge "自动下载被跳过" 1 "$(docker logs "$NAME" 2>&1 | grep -c 'UI already exists')"
ckge "配置含 external-ui-url" 1 "$(grep -c 'metacubexd/releases/download/' "$CONF_DIR/config.yaml")"

echo "== 场景5: 运行中订阅失效 -> 保留配置, 不破坏, 不重启 =="
echo html > "$MODE_FILE"; sleep 10
ckge "配置未被覆盖" 1 "$(grep -c test-node-1 "$CONF_DIR/config.yaml")"
ck "无残留临时文件" "0" "$(ls "$CONF_DIR" | grep -c tmp || true)"
ck "clash 仍在运行" "200" "$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$API/version")"
ckge "日志含保留提示" 1 "$(docker logs "$NAME" 2>&1 | grep -c '保留当前配置')"

echo "== 场景6: 订阅恢复且内容变化 -> 热重载生效 =="
echo b > "$MODE_FILE"; sleep 10
ckge "配置已更新" 1 "$(grep -c test-node-2 "$CONF_DIR/config.yaml")"
ck "API 无 400" "0" "$(docker logs "$NAME" 2>&1 | grep -c 'curl: (22)')"
ckge "clash 已加载新节点" 1 "$(curl -s -m 3 "$API/proxies" | grep -c test-node-2)"
ck "旧节点已消失" "0" "$(curl -s -m 3 "$API/proxies" | grep -c test-node-1)"

echo "== 场景7: 订阅不可用时重启容器 -> 沿用旧配置启动 =="
echo html > "$MODE_FILE"
docker restart "$NAME" >/dev/null; sleep 6
ckge "沿用旧配置启动" 1 "$(docker logs "$NAME" 2>&1 | grep -c '沿用已有配置')"
ck "clash API 可用" "200" "$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$API/version")"
ckge "配置未被破坏" 1 "$(grep -c test-node-2 "$CONF_DIR/config.yaml")"

echo "== 场景8: 节点记忆 (profile.store-selected) =="
echo c > "$MODE_FILE"; sleep 10
ck "cache.db 位于持久化目录" "1" "$(docker exec "$NAME" sh -c '[ -f /root/conf/cache.db ] && echo 1 || echo 0')"
ckge "两个节点均已加载" 2 "$(curl -s -m 3 "$API/proxies" | grep -o 'test-node-[12]' | sort -u | wc -l)"

curl -s -m 3 -X PUT -H 'Content-Type: application/json' \
  -d '{"name":"test-node-2"}' "$API/proxies/PROXY" >/dev/null
sleep 1
ck "节点已切换" "test-node-2" "$(curl -s -m 3 "$API/proxies/PROXY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["now"])')"
ck "cache.db 已落盘到持久化目录" "1" "$([[ -s "$CONF_DIR/cache.db" ]] && echo 1 || echo 0)"

echo "  -- 8a: 配置重载后仍记住 --"
echo d > "$MODE_FILE"; sleep 10
ck "配置确实被重载(log-level 变化)" "warning" "$(curl -s -m 3 "$API/configs" | python3 -c 'import json,sys; print(json.load(sys.stdin)["log-level"])')"
ck "重载后仍记住节点" "test-node-2" "$(curl -s -m 3 "$API/proxies/PROXY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["now"])')"

echo "  -- 8b: 重建容器后仍记住 (等价于升级镜像) --"
docker rm -f "$NAME" >/dev/null 2>&1
start; sleep 8
ck "重建后仍记住节点" "test-node-2" "$(curl -s -m 3 "$API/proxies/PROXY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["now"])')"

echo
echo "结果: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
