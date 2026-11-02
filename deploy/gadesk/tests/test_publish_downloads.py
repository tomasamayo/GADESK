import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'publish-downloads.py'
FILES = [
    'GADESK-1.5.1-android-arm64-build71.apk',
    'GADESK-1.5.1-macos-arm64-build71.dmg',
    'GADESK-1.5.1-macos-arm64-build71.pkg',
    'GADESK-1.5.1-x86_64-build71-install.exe',
    'GADESK-1.5.1-x86_64-build71.msi',
    'GADESK-1.5.1-build71-source.tar.gz',
]


class PublicationTest(unittest.TestCase):
    def test_incomplete_release_preserves_current_manifest(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'downloads.json').write_text('previous release')
            (root / FILES[0]).write_bytes(b'candidate')
            result = subprocess.run([sys.executable, str(SCRIPT), folder], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((root / 'downloads.json').read_text(), 'previous release')
            self.assertFalse((root / 'SHA256SUMS').exists())

    def test_complete_release_lists_five_immutable_artifacts_and_source(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in FILES:
                (root / name).write_bytes(name.encode())
            subprocess.run([sys.executable, str(SCRIPT), folder], check=True, capture_output=True)
            manifest = json.loads((root / 'downloads.json').read_text())
            self.assertEqual({item['file'] for item in manifest}, set(FILES[:5]))
            self.assertEqual(len((root / 'SHA256SUMS').read_text().splitlines()), 6)


if __name__ == '__main__':
    unittest.main()
