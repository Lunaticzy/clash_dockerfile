#!/usr/bin/env python3
"""模拟机场订阅服务端, 供 e2e.sh 使用。

通过一个 mode 文件在运行期切换响应内容, 用来复现机场的几种状态:

    a     返回 fixtures/sub-a.yaml (含 test-node-1)
    b     返回 fixtures/sub-b.yaml (含 test-node-2)
    403   返回 HTTP 403
    html  返回 HTTP 200 + HTML 页面 (模拟"请先登录后台开启订阅")
    其它  同 html

同时把每次请求收到的 User-Agent 写入 ua 文件, 供断言使用。
"""

import argparse
import http.server
import pathlib
import socketserver

HTML_BODY = (
    "<html><head><title>Subscription</title></head>"
    "<body>请先登录机场后台点击开启订阅</body></html>"
)

FIXTURES = {
    "a": "sub-a.yaml",
    "b": "sub-b.yaml",
}


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "MockSubscription/1.0"

    def do_GET(self):
        cfg = self.server.cfg
        cfg.ua_file.write_text(self.headers.get("User-Agent", "<none>"))

        mode = cfg.mode_file.read_text().strip()
        if mode in FIXTURES:
            body = (cfg.fixtures / FIXTURES[mode]).read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/yaml")
        elif mode == "403":
            body = b"forbidden"
            self.send_response(403)
            self.send_header("Content-Type", "text/plain")
        else:
            body = HTML_BODY.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html")

        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=18080)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--fixtures", type=pathlib.Path, required=True)
    parser.add_argument("--mode-file", type=pathlib.Path, required=True)
    parser.add_argument("--ua-file", type=pathlib.Path, required=True)
    args = parser.parse_args()

    args.mode_file.parent.mkdir(parents=True, exist_ok=True)
    args.mode_file.write_text("html")

    with Server((args.host, args.port), Handler) as httpd:
        httpd.cfg = args
        httpd.serve_forever()


if __name__ == "__main__":
    main()
