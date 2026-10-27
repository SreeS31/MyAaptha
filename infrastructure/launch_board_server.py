"""Loopback-only launch board preview with an explicit public-file allowlist."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit
import argparse

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = [ROOT / p for p in ('docs', 'backend/spring-boot-app/src/main/java',
    'backend/spring-boot-app/src/test', 'backend/spring-boot-app/src/main/resources/db/migration',
    'ai/agent-service/tests', 'mobile/flutter-app/lib')]

class BoardHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path == '/':
            self.send_response(302)
            self.send_header('Location', '/docs/launch-board/index.html')
            self.end_headers()
            return
        super().do_GET()

    def send_head(self):
        requested = (ROOT / unquote(urlsplit(self.path).path).lstrip('/')).resolve()
        if not any(requested.is_relative_to(base.resolve()) for base in ALLOWED) or not requested.is_file():
            self.send_error(404, 'Not a preview document')
            return None
        return super().send_head()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        super().end_headers()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=4317)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error('Use a port between 1024 and 65535.')
    with ThreadingHTTPServer(('127.0.0.1', args.port), partial(BoardHandler, directory=str(ROOT))) as server:
        print(f'Launch board: http://127.0.0.1:{args.port}', flush=True)
        server.serve_forever()

if __name__ == '__main__':
    main()
