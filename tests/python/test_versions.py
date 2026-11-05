import unittest

from sciencelogo_documenter.versions import racket_tarball


class VersionsTest(unittest.TestCase):
    def test_linux_tarball_is_pinned(self):
        url, sha256 = racket_tarball("x86_64-linux")
        self.assertTrue(url.startswith("https://"))
        self.assertTrue(url.endswith(".tgz"))
        self.assertEqual(len(sha256), 64)

    def test_unknown_platform(self):
        with self.assertRaises(ValueError):
            racket_tarball("no-such-platform")


if __name__ == "__main__":
    unittest.main()
