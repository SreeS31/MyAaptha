"""Read-only preview boundary tests; no customer state is read or changed."""
import threading
import unittest
from functools import partial
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import urlopen
from launch_board_server import BoardHandler, ROOT

class PreviewBoundaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=ThreadingHTTPServer(('127.0.0.1',0),partial(BoardHandler,directory=str(ROOT)))
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start()
        cls.base=f'http://127.0.0.1:{cls.server.server_port}'
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join()
    def test_board_redirect_and_evidence_document(self):
        with urlopen(self.base+'/') as response:
            self.assertEqual(response.status,200)
            self.assertIn(b'MyAaptha Launch Board',response.read())
            self.assertEqual(response.headers['Cache-Control'],'no-store')
        with urlopen(self.base+'/docs/launch-board/STATUS-2026-10-17.md') as response:
            self.assertEqual(response.status,200)
    def test_private_and_traversal_paths_are_not_served(self):
        for path in ['/.git/config','/.tools/preview/database.txt','/docs/../.tools/preview/database.txt','/docs/%2e%2e/.git/config','/docs/']:
            with self.subTest(path=path):
                with self.assertRaises(HTTPError) as error:urlopen(self.base+path)
                self.assertEqual(error.exception.code,404)
    def test_source_evidence_allowed(self):
        with urlopen(self.base+'/backend/spring-boot-app/src/main/java/com/myaaptha/domain/timeline/TimelineController.java') as response:
            self.assertEqual(response.status,200)

if __name__=='__main__':unittest.main()
