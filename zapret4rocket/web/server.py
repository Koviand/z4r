#!/usr/bin/env python3
"""
Minimal HTTP server for z4r web panel.
Serves index.html and /api/status, /api/restart, /api/stop, /api/check.
Usage: server.py [--port PORT] [--bind 127.0.0.1|0.0.0.0] [--auth user:pass]
"""
import argparse
import base64
import json
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

# Defaults
WEB_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_DIR = os.path.join(WEB_DIR, "scripts")
PORT = 17681
BIND = "0.0.0.0"
AUTH = None  # "user:pass" for Basic Auth, or None


def run_script(name, args=None):
    path = os.path.join(SCRIPTS_DIR, name)
    if not os.path.isfile(path) or not os.access(path, os.X_OK):
        return None, "script not found"
    try:
        cmd = [path]
        if args:
            cmd.extend(args)
        out = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=WEB_DIR,
            env={**os.environ, "PATH": os.environ.get("PATH", "/usr/bin:/bin")},
        )
        return out.stdout.strip() if out.stdout else "", out.returncode
    except subprocess.TimeoutExpired:
        return None, "timeout"
    except Exception as e:
        return None, str(e)


def api_status():
    out, ret = run_script("status.sh")
    if out and ret == 0:
        return 200, out
    return 500, json.dumps({"ok": False, "error": out or "status script failed"})


def api_action(action):
    out, _ = run_script("actions.sh", [action])
    if out:
        try:
            json.loads(out)
            return 200, out
        except json.JSONDecodeError:
            pass
    return 500, json.dumps({"ok": False, "error": out or "action failed"})


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.serve_index()
        elif self.path == "/api/status":
            self.serve_api_status()
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/api/restart":
            self.serve_api_action("restart")
        elif self.path == "/api/stop":
            self.serve_api_action("stop")
        elif self.path == "/api/check":
            self.serve_api_action("check")
        else:
            self.send_error(404)

    def auth_required(self):
        if not AUTH:
            return True
        auth_header = self.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Basic "):
            return False
        try:
            decoded = base64.b64decode(auth_header[6:]).decode("utf-8")
            return decoded == AUTH
        except Exception:
            return False

    def send_auth_required(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="z4r"')
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"error":"auth required"}')

    def serve_index(self):
        if not self.auth_required():
            self.send_auth_required()
            return
        index_path = os.path.join(WEB_DIR, "index.html")
        if not os.path.isfile(index_path):
            self.send_error(404)
            return
        with open(index_path, "rb") as f:
            data = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(data))
        self.end_headers()
        self.wfile.write(data)

    def serve_api_status(self):
        if not self.auth_required():
            self.send_auth_required()
            return
        code, body = api_status()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def serve_api_action(self, action):
        if not self.auth_required():
            self.send_auth_required()
            return
        code, body = api_action(action)
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def log_message(self, format, *args):
        # Quiet by default; override to log
        pass


def main():
    global PORT, BIND, AUTH
    parser = argparse.ArgumentParser(description="z4r web panel server")
    parser.add_argument("--port", type=int, default=17681, help="Port (default 17681)")
    parser.add_argument("--bind", default="0.0.0.0", help="Bind address (default 0.0.0.0)")
    parser.add_argument("--auth", default=None, help="HTTP Basic Auth: user:pass")
    parser.add_argument("--config", default=None, help="Config file with BIND= and AUTH= (optional)")
    args = parser.parse_args()
    PORT = args.port
    BIND = args.bind
    AUTH = args.auth

    if args.config and os.path.isfile(args.config):
        for line in open(args.config, encoding="utf-8", errors="replace"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("BIND="):
                BIND = line.split("=", 1)[1].strip() or BIND
            elif line.startswith("AUTH="):
                AUTH = line.split("=", 1)[1].strip() or None

    server = HTTPServer((BIND, PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
