import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from sciencelogo_documenter import publish


def git(*args, cwd):
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout


class PublishTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.site = self.tmp / "site"
        (self.site / "stages").mkdir(parents=True)
        (self.site / "index.html").write_text("<p>overview</p>")
        (self.site / "stages" / "one.html").write_text("<p>one</p>")

    def test_dir_target_copies_the_site(self):
        dest = self.tmp / "out"
        publish.publish("dir", self.site, folder=dest)
        self.assertEqual((dest / "stages" / "one.html").read_text(), "<p>one</p>")

    def test_dir_target_needs_a_folder(self):
        with self.assertRaises(publish.PublishError):
            publish.publish("dir", self.site)

    def test_gitlab_pages_uses_the_public_folder(self):
        cwd = os.getcwd()
        os.chdir(self.tmp)
        try:
            where = publish.publish("gitlab-pages", self.site)
        finally:
            os.chdir(cwd)
        self.assertEqual(where, "public")
        self.assertTrue((self.tmp / "public" / "index.html").is_file())

    def test_github_pages_folder_disables_jekyll(self):
        dest = self.tmp / "_site"
        publish.publish("github-pages", self.site, folder=dest)
        self.assertTrue((dest / ".nojekyll").is_file())

    def test_an_unbuilt_site_is_refused(self):
        with self.assertRaises(publish.PublishError):
            publish.publish("dir", self.tmp / "missing", folder=self.tmp / "out")

    def test_pages_branch_pushes_only_the_site(self):
        remote = self.tmp / "remote.git"
        git("init", "-q", "--bare", str(remote), cwd=self.tmp)
        repo = self.tmp / "workflow"
        repo.mkdir()
        git("init", "-q", cwd=repo)
        git("config", "user.name", "Test", cwd=repo)
        git("config", "user.email", "test@example.org", cwd=repo)
        (repo / "workflow.rkt").write_text("#lang sciencelogo\n")
        git("add", "-A", cwd=repo)
        git("commit", "-q", "-m", "workflow", cwd=repo)
        git("remote", "add", "origin", str(remote), cwd=repo)
        before = git("rev-parse", "HEAD", cwd=repo)

        cwd = os.getcwd()
        os.chdir(repo)
        try:
            publish.publish("pages-branch", self.site, branch="pages")
        finally:
            os.chdir(cwd)

        files = git("ls-tree", "-r", "--name-only", "pages", cwd=remote).split()
        self.assertEqual(sorted(files), [".nojekyll", "index.html", "stages/one.html"])
        self.assertEqual(git("rev-parse", "HEAD", cwd=repo), before)
        self.assertEqual(git("log", "-1", "--format=%an", "pages", cwd=remote).strip(), "Test")


if __name__ == "__main__":
    unittest.main()
