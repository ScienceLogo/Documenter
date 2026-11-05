import unittest
from importlib.resources import files

PACKAGE = files("sciencelogo_documenter")


class PackageDataTest(unittest.TestCase):
    def test_racket_program_is_bundled(self):
        for name in ("main.rkt", "extract.rkt", "html.rkt", "typst.rkt"):
            self.assertTrue(PACKAGE.joinpath("racket", name).is_file(), name)

    def test_static_files_are_bundled(self):
        for name in ("site.css", "site.js", "template.typ"):
            self.assertTrue(PACKAGE.joinpath("static", name).is_file(), name)

    def test_fonts_are_bundled_with_their_licences(self):
        fonts = PACKAGE.joinpath("fonts")
        self.assertTrue(fonts.joinpath("atkinson-hyperlegible-next", "AtkinsonHyperlegibleNext-Regular.ttf").is_file())
        self.assertTrue(fonts.joinpath("atkinson-hyperlegible-mono", "AtkinsonHyperlegibleMono-Regular.ttf").is_file())
        for family in ("atkinson-hyperlegible-next", "atkinson-hyperlegible-mono"):
            self.assertTrue(fonts.joinpath(family, "OFL.txt").is_file(), family)
        for family in ("ibm-plex-serif", "ibm-plex-sans"):
            self.assertTrue(fonts.joinpath(family, "LICENSE.txt").is_file(), family)


if __name__ == "__main__":
    unittest.main()
