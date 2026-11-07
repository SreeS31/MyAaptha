"""Run the browser verifier against an isolated, read-only loopback board server."""
from functools import partial
from http.server import ThreadingHTTPServer
import os
from pathlib import Path
import subprocess
import sys
from threading import Thread

from launch_board_server import BoardHandler

ROOT = Path(__file__).resolve().parents[1]


def main():
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(BoardHandler, directory=str(ROOT)))
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = dict(os.environ, BOARD_URL=f'http://127.0.0.1:{server.server_port}/docs/launch-board/index.html')
    try:
        result = subprocess.run(['node', str(ROOT / 'docs/launch-board/verify-board.cjs')],
                                cwd=ROOT, env=env, timeout=300)
        return result.returncode
    except FileNotFoundError:
        print('Install Node.js and the frontend Playwright dependencies before verifying the board.', file=sys.stderr)
        return 1
    except subprocess.TimeoutExpired:
        print('Launch-board verification timed out.', file=sys.stderr)
        return 1
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__':
    raise SystemExit(main())
