"""Help Menu's migration contract against the original committed pipeline."""

import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = "9afa060525167f7ac657798506e302157ded4580"


def original(path):
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)


def migration_revision():
    commits = subprocess.check_output(
        ["git", "rev-list", "--reverse", f"{BASE}..HEAD"], cwd=ROOT, text=True
    ).splitlines()
    return commits[0] if commits else None


class RepositoryContractTests(unittest.TestCase):
    def test_existing_coordinated_authority_and_original_triggers(self):
        bump = original(".github/workflows/bump-version.yml").decode()
        header = bump.split("name:", 1)[0]
        self.assertIn("MARKETING_VERSION/CURRENT_PROJECT_VERSION", header)
        self.assertIn("CFBundleShortVersionString/CFBundleVersion", header)
        release = original(".github/workflows/release.yml").decode()
        triggers = release.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
        self.assertIn("  push:\n    tags:", triggers)
        self.assertIn("  workflow_dispatch:", triggers)
        self.assertNotIn("pull_request", triggers)
        self.assertNotIn("branches:", triggers)

    def test_no_intake_increment_or_native_prebuilt_dependency_edits(self):
        # Compare migration changes, not later legitimate helper-generated bumps.
        revision = migration_revision()
        changed = subprocess.check_output(
            ["git", "diff", "--name-only", BASE, *([revision] if revision else []), "--"],
            cwd=ROOT, text=True
        ).splitlines()
        self.assertTrue(all(path.startswith(".github/") or path == "README.md"
                            for path in changed), changed)

    def test_original_native_intent_and_secrets_preserved(self):
        current = (ROOT / ".github/workflows/release.yml").read_text()
        old = original(".github/workflows/release.yml").decode()
        secret = r"\$\{\{ secrets\.([A-Z_]+) \}\}"
        self.assertEqual(set(re.findall(secret, current)), set(re.findall(secret, old)))
        for line in (
            'PRODUCT_NAME: Help Menu', "MACOS_DEPLOYMENT_TARGET: '11.5'",
            'BASE_DIR: test',
            'msbuild "%PRODUCT_NAME%.sln" /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=v143 /p:WindowsTargetPlatformVersion=10.0 /m',
            '-configuration Default \\',
            'ARCHS="arm64 x86_64" \\',
            'ONLY_ACTIVE_ARCH=NO \\',
            'CODE_SIGNING_ALLOWED=NO \\',
            'CONFIGURATION_BUILD_DIR="$PWD/$PLUGINS_DIR" \\',
            'codesign --verify --deep --strict --verbose=2 "$BUNDLE_PATH"',
            'xcrun stapler staple "$DMG_PATH"',
        ):
            self.assertIn(line, old)
            self.assertIn(line, current)
        self.assertIn('if grep -qw "i386"', current)
        self.assertIn('path = "\\{0,1\\}\\(a\\|lib\\)/', current)
        self.assertIn('"${CONTENTS}"/MacOS/*.dylib', current)
        self.assertIn('"${CONTENTS}/Resources/manifest.json"', current)
        self.assertIn('"${CONTENTS}/Resources/constants.xlf"', current)

    def test_original_source_modes_bytes_and_copy_destinations(self):
        revision = migration_revision()
        for name in (
            "Help Menu.xcodeproj/project.pbxproj", "Info.plist",
            "English.lproj/InfoPlist.strings", "Help Menu.vcxproj",
        ):
            actual = (subprocess.check_output(["git", "show", f"{revision}:{name}"], cwd=ROOT)
                      if revision else (ROOT / name).read_bytes())
            self.assertEqual(actual, original(name), name)
        self.assertEqual((ROOT / "Info.plist").stat().st_mode & 0o777, 0o755)
        self.assertEqual((ROOT / "English.lproj/InfoPlist.strings").stat().st_mode & 0o777,
                         0o755)
        project = (ROOT / "Help Menu.xcodeproj/project.pbxproj").read_text()
        self.assertIn('dstPath = "";\n\t\t\tdstSubfolderSpec = 7;', project)


if __name__ == "__main__":
    unittest.main()
