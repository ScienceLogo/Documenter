import unittest
from importlib.resources import files


class PackageDataTest(unittest.TestCase):
    def test_racket_entry_point_is_bundled(self):
        main = files("sciencelogo_documenter").joinpath("racket", "main.rkt")
        self.assertTrue(main.is_file())


if __name__ == "__main__":
    unittest.main()
