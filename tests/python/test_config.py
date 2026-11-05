import tempfile
import unittest
from pathlib import Path

from sciencelogo_documenter import config


class ConfigTest(unittest.TestCase):
    def write(self, text: str) -> Path:
        folder = Path(tempfile.mkdtemp())
        path = folder / config.CONFIG_NAME
        path.write_text(text)
        return path

    def test_defaults_without_a_file(self):
        settings, warnings = config.load(None)
        self.assertEqual(settings["booklet"]["paper"], "a4")
        self.assertEqual(settings["fonts"]["text"], "Atkinson Hyperlegible Next")
        self.assertEqual(warnings, [])

    def test_the_file_overrides_only_what_it_sets(self):
        path = self.write('[booklet]\npaper = "us-letter"\n[colours.light]\nlink = "#003366"\n')
        settings, warnings = config.load(path)
        self.assertEqual(settings["booklet"]["paper"], "us-letter")
        self.assertEqual(settings["booklet"]["body_size"], "10.5pt")
        self.assertEqual(settings["colours"]["light"]["link"], "#003366")
        self.assertEqual(settings["colours"]["light"]["text"], "#1a1a1a")
        self.assertEqual(warnings, [])

    def test_unknown_settings_are_reported(self):
        settings, warnings = config.load(self.write("[layout]\ncolumns = 2\n"))
        self.assertIn("unknown setting 'layout.columns' is ignored", warnings)

    def test_low_contrast_is_reported(self):
        _, warnings = config.load(self.write('[colours.light]\ntext = "#aaaaaa"\n'))
        self.assertTrue(any("colours.light.text" in w and "below 4.5:1" in w for w in warnings))

    def test_standard_colours_pass_the_contrast_check(self):
        settings, _ = config.load(None)
        for mode in ("light", "dark"):
            for key in ("text", "muted", "link"):
                ratio = config.contrast(settings["colours"][mode][key], settings["colours"][mode]["background"])
                self.assertGreaterEqual(ratio, 4.5, f"{mode}.{key}")

    def test_logos_are_resolved_against_the_file(self):
        path = self.write('[site]\nlogo = "logo.png"\n')
        (path.parent / "logo.png").write_bytes(b"png")
        settings, _ = config.load(path)
        self.assertEqual(settings["site"]["logo"], str((path.parent / "logo.png").resolve()))

    def test_a_missing_logo_is_an_error(self):
        with self.assertRaises(config.ConfigError):
            config.load(self.write('[booklet]\nlogo = "missing.png"\n'))

    def test_invalid_toml_is_an_error(self):
        with self.assertRaises(config.ConfigError):
            config.load(self.write("[booklet\n"))


if __name__ == "__main__":
    unittest.main()
