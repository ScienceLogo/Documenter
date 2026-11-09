"""End-to-end builds. They need a Racket with `sciencelogo`, named by the
SCIENCELOGO_DOCUMENTER_RACKET environment variable (the `bin` folder)."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from sciencelogo_documenter.build import BuildError, build

ROOT = Path(__file__).resolve().parents[2]
EXAMPLE = ROOT / "examples" / "pendulum" / "workflow.rkt"


@unittest.skipUnless(os.environ.get("SCIENCELOGO_DOCUMENTER_RACKET"), "needs SCIENCELOGO_DOCUMENTER_RACKET")
class BuildTest(unittest.TestCase):
    def test_example_builds_a_site_with_the_booklet(self):
        out = Path(tempfile.mkdtemp())
        site = build(EXAMPLE, out)
        self.assertEqual(site, out / "site")
        self.assertTrue((site / "index.html").is_file())
        self.assertTrue((site / "stages" / "observe.html").is_file())
        self.assertEqual((site / "booklet.pdf").read_bytes()[:5], b"%PDF-")
        for page in site.rglob("*.html"):
            text = page.read_text()
            self.assertNotIn(str(ROOT), text)
            self.assertNotIn(".rkt", text)

    def test_an_invalid_workflow_stops_the_build(self):
        folder = Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q"], cwd=folder, check=True)
        entry = folder / "workflow.rkt"
        entry.write_text("#lang sciencelogo\nstage Broken by nobody from state []\nend stage with state []\n")
        out = folder / "out"
        with self.assertRaises(BuildError) as error:
            build(entry, out)
        self.assertIn("unknown performer nobody", str(error.exception))
        self.assertFalse(out.exists())

    def test_a_workflow_outside_git_builds(self):
        folder = Path(tempfile.mkdtemp())
        (folder / "stage.rkt").write_text('#lang sciencelogo\nstage Only about "The only stage."\n')
        entry = folder / "workflow.rkt"
        entry.write_text('#lang sciencelogo\nworkflow "Outside Git"\ninclude "stage.rkt"\n')
        site = build(entry, folder / "out")
        self.assertTrue((site / "stages" / "only.html").is_file())


if __name__ == "__main__":
    unittest.main()
