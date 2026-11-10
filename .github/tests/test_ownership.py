"""Compile real sources and the complete unmodified SDK; never load the plugin in 4D."""

import os
from pathlib import Path
import platform
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / ".github/tests/ownership"
SOURCE = Path(os.environ.get("OWNERSHIP_SOURCE_ROOT", ROOT)).resolve()


@unittest.skipUnless(platform.system() == "Darwin", "macOS engine-boundary harness")
class OwnershipTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.binary = Path(cls.temp.name) / "ownership"
        sdk = SOURCE / "4D Plugin API"
        flags = ["clang++", "-std=c++17", "-g", "-O1",
                 "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
                 "-Wno-deprecated-declarations", "-Wno-multichar",
                 "-I", str(sdk), "-I", str(sdk / "Classes"),
                 "-I", str(SOURCE / "support")]
        objects = []
        sources = [sdk / "4DPluginAPI.c", SOURCE / "support/4DPlugin-JSON.cpp",
                   sdk / "Classes/C_TEXT.cpp", sdk / "Classes/ARRAY_TEXT.cpp",
                   sdk / "Classes/C_BLOB.cpp", sdk / "Classes/C_LONGINT.cpp",
                   SOURCE / "4DPlugin-Help-Menu.cpp", HARNESS / "engine.mm"]
        for i, source in enumerate(sources):
            output = Path(cls.temp.name) / f"{i}.o"
            command = flags + ["-x", "objective-c++", "-c", str(source), "-o", str(output)]
            if source.name in ("4DPlugin-Help-Menu.cpp", "engine.mm"):
                command += ["-I", str(HARNESS)]
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
            objects.append(str(output))
        result = subprocess.run(flags + objects + ["-framework", "Foundation", "-framework",
                       "CoreFoundation", "-framework", "CoreGraphics", "-o",
                       str(cls.binary)], capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_contracts(self):
        for mode in ("scalar", "mismatch", "failed-get", "handoffs", "stringify",
                     "command-handle-failure", "command-failure", "arrays",
                     "content", "setters", "dispatcher"):
            for fixture in range(4):
                for null_empty in range(2):
                    with self.subTest(mode=mode, fixture=fixture, null_empty=null_empty):
                        result = subprocess.run(
                            [str(self.binary), mode, str(fixture), str(null_empty)],
                            env={**os.environ, "ASAN_OPTIONS": "detect_leaks=0",
                                 "UBSAN_OPTIONS": "halt_on_error=1"},
                            capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
