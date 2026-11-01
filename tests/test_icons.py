"""Exercise primary icon selection and PNG export with real image files."""
from __future__ import annotations

import hashlib
from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from icons import export_icon, image_size, primary_icon


def write_png(path: Path, size: int) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))

    header = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    pixels = (b'\x00' + b'\x20\x80\xff\xff' * size) * size
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) +
                     chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b''))


class IconTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        self.app = self.root / 'Example.app'
        self.app.mkdir()
        self.info: dict[str, object] = {
            'CFBundleIcons': {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['Phone']}},
            'CFBundleIcons~ipad': {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['Tablet']}},
        }
        self.write_info()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_info(self) -> None:
        (self.app / 'Info.plist').write_bytes(plistlib.dumps(self.info))

    def test_largest_primary_icon_excludes_alternate_and_unrelated_images(self) -> None:
        self.info['CFBundleIcons'] = {
            'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['Phone']},
            'CFBundleAlternateIcons': {'Other': {'CFBundleIconFiles': ['Other']}},
        }
        self.info['CFBundleIconFiles'] = ['Legacy']
        self.write_info()
        for name, size in [('Phone@2x.png', 24), ('Phone@3x.png', 36), ('Tablet@2x~ipad.png', 48),
                           ('Other.png', 96), ('PhoneDark.png', 96), ('Legacy.png', 96)]:
            write_png(self.app / name, size)
        self.assertEqual(primary_icon(self.app), self.app / 'Tablet@2x~ipad.png')

    def test_legacy_icon_keys_and_explicit_png_names(self) -> None:
        write_png(self.app / 'Legacy.png', 24)
        options: list[dict[str, object]] = [{'CFBundleIconFiles': ['Legacy.png']}, {'CFBundleIconFile': 'Legacy.png'}]
        for info in options:
            with self.subTest(info=info):
                self.info = info
                self.write_info()
                self.assertEqual(primary_icon(self.app), self.app / 'Legacy.png')

    def test_export_preserves_bundle_contents_and_dimensions(self) -> None:
        write_png(self.app / 'Phone@2x.png', 24)
        before = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in self.app.iterdir()}
        output = self.root / 'artifacts/icon.png'
        export_icon(self.app, output)
        self.assertEqual(image_size(output), (24, 24))
        self.assertTrue(output.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'))
        self.assertEqual(before, {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                  for path in self.app.iterdir()})

    def test_missing_primary_png_does_not_select_an_unrelated_image(self) -> None:
        write_png(self.app / 'Other.png', 24)
        (self.app / 'Assets.car').write_bytes(b'asset catalog')
        with self.assertRaisesRegex(ValueError, 'No primary PNG icon'):
            export_icon(self.app, self.root / 'artifacts/icon.png')
        self.assertFalse((self.root / 'artifacts').exists())

    def test_escaping_icon_paths_and_symlinks_are_rejected(self) -> None:
        outside = self.root / 'Outside.png'
        write_png(outside, 24)
        for name in ['../Outside.png', str(outside)]:
            with self.subTest(name=name):
                self.info = {'CFBundleIconFiles': [name]}
                self.write_info()
                with self.assertRaisesRegex(ValueError, 'escapes'):
                    primary_icon(self.app)
        self.info = {'CFBundleIconFiles': ['Linked']}
        self.write_info()
        (self.app / 'Linked.png').symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'escapes'):
            primary_icon(self.app)

    def test_output_inside_bundle_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, 'outside'):
            export_icon(self.app, self.app / 'icon.png')

    def test_corrupt_primary_image_is_rejected(self) -> None:
        (self.app / 'Phone.png').write_bytes(b'invalid image')
        with self.assertRaises((ValueError, subprocess.CalledProcessError)):
            export_icon(self.app, self.root / 'artifacts/icon.png')
        self.assertFalse((self.root / 'artifacts').exists())


if __name__ == '__main__':
    unittest.main()
