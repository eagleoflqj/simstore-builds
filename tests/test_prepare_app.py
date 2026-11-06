from __future__ import annotations

from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

from prepare_app import preserve_sentry_resources


class SentryResourcesTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.app = Path(temporary.name) / 'Example.app'
        self.framework = self.app / 'Frameworks/Sentry.framework'
        self.framework.mkdir(parents=True)
        self.metadata = {
            'CFBundleIdentifier': 'io.sentry.Sentry',
            'CFBundleExecutable': 'Sentry',
            'CFBundlePackageType': 'FMWK',
            'MinimumOSVersion': '100.0',
        }
        self.write_metadata()
        (self.framework / 'Sentry').write_bytes(b'placeholder')
        (self.framework / 'PrivacyInfo.xcprivacy').write_bytes(b'privacy manifest')
        signature = self.framework / '_CodeSignature'
        signature.mkdir()
        (signature / 'CodeResources').write_bytes(b'old signature')
        self.resources = self.app / 'SentryResources.bundle'
        self.binaries = [self.app / 'Example', self.framework / 'Sentry']

    def write_metadata(self) -> None:
        (self.framework / 'Info.plist').write_bytes(plistlib.dumps(self.metadata))

    def test_preserves_resources_and_removes_only_the_placeholder(self) -> None:
        with patch('prepare_app.run', return_value=''):
            preserve_sentry_resources(self.app, self.binaries)
        self.assertFalse(self.framework.exists())
        self.assertEqual((self.resources / 'PrivacyInfo.xcprivacy').read_bytes(), b'privacy manifest')
        metadata = plistlib.loads((self.resources / 'Info.plist').read_bytes())
        self.assertEqual(metadata['CFBundleIdentifier'], self.metadata['CFBundleIdentifier'])
        self.assertEqual(metadata['CFBundlePackageType'], 'BNDL')
        self.assertNotIn('CFBundleExecutable', metadata)
        self.assertNotIn('MinimumOSVersion', metadata)
        self.assertFalse((self.resources / 'Sentry').exists())
        self.assertFalse((self.resources / '_CodeSignature').exists())

    def test_keeps_real_code_and_frameworks_referenced_by_other_binaries(self) -> None:
        for symbols, dependencies in (('_sentry_real_code', ''), ('', '@rpath/Sentry.framework/Sentry')):
            with self.subTest(symbols=symbols, dependencies=dependencies):
                def command(*args: str) -> str:
                    return symbols if args[1] == 'nm' else dependencies

                with patch('prepare_app.run', side_effect=command), self.assertRaises(ValueError):
                    preserve_sentry_resources(self.app, self.binaries)
                self.assertTrue(self.framework.is_dir())
                self.assertFalse(self.resources.exists())

    def test_leaves_normal_sentry_frameworks_unchanged(self) -> None:
        self.metadata['MinimumOSVersion'] = '16.0'
        self.write_metadata()
        with patch('prepare_app.run') as command:
            preserve_sentry_resources(self.app, self.binaries)
        command.assert_not_called()
        self.assertTrue(self.framework.is_dir())

    def test_does_not_overwrite_an_existing_resource_bundle(self) -> None:
        self.resources.mkdir()
        marker = self.resources / 'existing-resource'
        marker.write_bytes(b'preserve me')
        with patch('prepare_app.run', return_value=''), self.assertRaises(ValueError):
            preserve_sentry_resources(self.app, self.binaries)
        self.assertEqual(marker.read_bytes(), b'preserve me')
        self.assertTrue(self.framework.is_dir())
