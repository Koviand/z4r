#!/usr/bin/env python3
# Минимальный HTTP-сервер для веб-панели zeefeer.
# Раздаёт index.html и вызывает api.sh для /api/*.
# Запуск: python3 server.py [port]
# По умолчанию порт 17682 (терминал ttyd — 17681).

import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

WEB_DIR = os.path.dirname(os.path.abspath(__file__))
API_SCRIPT = os.path.join(WEB_DIR, 'api.sh')
ZAPRET_DIR = os.environ.get('ZAPRET_DIR', '/opt/zapret')


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # тихий лог

    def send_json(self, body, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body.encode('utf-8'))

    def send_file(self, path, content_type='text/html'):
        try:
            with open(path, 'rb') as f:
                data = f.read()
        except OSError:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', len(data))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split('?')[0].rstrip('/') or '/'
        if path.startswith('/api'):
            action = (path[5:].lstrip('/') or 'status').split('/')[0]
            env = os.environ.copy()
            env['ZAPRET_DIR'] = ZAPRET_DIR
            env['QUERY_STRING'] = action
            try:
                out = subprocess.run(
                    ['sh', API_SCRIPT],
                    cwd=WEB_DIR,
                    env=env,
                    capture_output=True,
                    timeout=10,
                    text=True,
                )
                body = (out.stdout or out.stderr or '{"message":"error"}').strip()
                if not body.startswith('{'):
                    body = '{"message":"' + body.replace('"', '\\"') + '"}'
                self.send_json(body)
            except Exception as e:
                self.send_json('{"ok":false,"message":"' + str(e).replace('"', '\\"') + '"}', 500)
            return
        if path == '/' or path == '/index.html':
            self.send_file(os.path.join(WEB_DIR, 'index.html'))
            return
        self.send_error(404)

    def do_POST(self):
        path = self.path.split('?')[0].rstrip('/')
        if not path.startswith('/api'):
            self.send_error(404)
            return
        action = (path[5:].lstrip('/') or 'status').split('/')[0]
        env = os.environ.copy()
        env['ZAPRET_DIR'] = ZAPRET_DIR
        env['QUERY_STRING'] = action
        try:
            out = subprocess.run(
                ['sh', API_SCRIPT],
                cwd=WEB_DIR,
                env=env,
                capture_output=True,
                timeout=15,
                text=True,
            )
            body = (out.stdout or out.stderr or '{"message":"error"}').strip()
            if not body.startswith('{'):
                body = '{"message":"' + body.replace('"', '\\"') + '"}'
            self.send_json(body)
        except Exception as e:
            self.send_json('{"ok":false,"message":"' + str(e).replace('"', '\\"') + '"}', 500)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 17682
    if not os.path.isfile(API_SCRIPT):
        sys.stderr.write('api.sh not found in %s\n' % WEB_DIR)
        sys.exit(1)
    try:
        os.chmod(API_SCRIPT, 0o755)
    except OSError:
        pass
    server = HTTPServer(('0.0.0.0', port), Handler)
    server.serve_forever()


if __name__ == '__main__':
    main()
