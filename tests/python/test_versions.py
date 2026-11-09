import unittest

from sciencelogo_documenter import versions
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

    def test_the_version_names_the_language_version(self):
        from sciencelogo_documenter import __version__

        language = versions.SCIENCELOGO_RELEASE.removeprefix("v")
        self.assertEqual(".".join(__version__.split(".")[:2]), language)

    def test_sciencelogo_is_pinned_to_a_release(self):
        self.assertIn(f"/releases/download/{versions.SCIENCELOGO_RELEASE}/", versions.SCIENCELOGO_URL)
        self.assertEqual(len(versions.SCIENCELOGO_CHECKSUM), 40)


if __name__ == "__main__":
    unittest.main()
