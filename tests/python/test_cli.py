import contextlib
import io
import unittest

from sciencelogo_documenter import __version__
from sciencelogo_documenter.cli import main


class CliTest(unittest.TestCase):
    def test_version(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as exit_:
            main(["--version"])
        self.assertEqual(exit_.exception.code, 0)
        self.assertEqual(out.getvalue().strip(), f"sciencelogo-documenter {__version__}")

    def test_command_is_required(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as exit_:
            main([])
        self.assertEqual(exit_.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
