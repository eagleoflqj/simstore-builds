"""Validate Simulator bundles with real clang-built fixtures."""
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location('validate', SCRIPTS / 'validate.py')
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class BundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='simstore-validator-')
        cls.base = Path(cls.temp.name)
        source = cls.base / 'fixture.c'
        source.write_text('int main(void) { return 0; }\n')
        for name, target, sdk in (
            ('simulator', 'arm64-apple-ios17.0-simulator', 'iphonesimulator'),
            ('device', 'arm64-apple-ios17.0', 'iphoneos'),
            ('macos', 'arm64-apple-macos14.0', 'macosx'),
        ):
            sdkpath = validator.run('xcrun', '--sdk', sdk, '--show-sdk-path')
            subprocess.run(['xcrun', 'clang', '-target', target, '-isysroot', sdkpath,
                            str(source), '-o', str(cls.base / name)], check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.work = tempfile.TemporaryDirectory(dir=self.base)
        self.app = Path(self.work.name) / 'Fixture.app'
        self.app.mkdir()
        shutil.copy2(self.base / 'simulator', self.app / 'Fixture')
        self.info = dict(CFBundleIdentifier='org.simstore.fixture', CFBundleExecutable='Fixture',
                         CFBundleShortVersionString='1.0', CFBundleVersion='1',
                         MinimumOSVersion='17.0', CFBundleSupportedPlatforms=['iPhoneSimulator'])
        self.write_info()

    def tearDown(self):
        self.work.cleanup()

    def write_info(self):
        with (self.app / 'Info.plist').open('wb') as f:
            plistlib.dump(self.info, f)

    def test_real_arm64_simulator_accepted(self):
        info, binaries, minimum = validator.validate(self.app)
        self.assertEqual(info['CFBundleIdentifier'], 'org.simstore.fixture')
        self.assertEqual(binaries, [Path('Fixture')])
        self.assertEqual(minimum, (17, 0, 0))

    def test_validation_without_manifest_needs_only_stdlib(self):
        result = subprocess.run([sys.executable, '-S', str(SCRIPTS / 'validate.py'), str(self.app)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_smoke_forwards_booted_and_udid_to_simctl(self):
        fake_bin = Path(self.work.name) / 'bin'
        fake_bin.mkdir()
        fake_xcrun = fake_bin / 'xcrun'
        fake_xcrun.write_text('''#!/bin/bash
if [[ $1 == simctl ]]; then
  printf '%s\\0' "$@" >> "$SIMSTORE_SMOKE_LOG"
  printf '\\n' >> "$SIMSTORE_SMOKE_LOG"
else
  exec "$SIMSTORE_REAL_XCRUN" "$@"
fi
''')
        fake_xcrun.chmod(0o755)
        log = Path(self.work.name) / 'simctl.log'
        env = dict(os.environ, PATH=f'{fake_bin}{os.pathsep}{os.environ["PATH"]}',
                   SIMSTORE_REAL_XCRUN=shutil.which('xcrun'), SIMSTORE_SMOKE_LOG=str(log))
        for target in ('booted', '00000000-0000-0000-0000-000000000001'):
            with self.subTest(target=target):
                log.unlink(missing_ok=True)
                result = subprocess.run(['bash', str(SCRIPTS / 'smoke-test.sh'), str(self.app), target],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = [[arg.decode() for arg in line.rstrip(b'\0').split(b'\0')]
                         for line in log.read_bytes().splitlines()]
                self.assertEqual(calls, [
                    ['simctl', 'install', target, str(self.app)],
                    ['simctl', 'launch', '--terminate-running-process', target, 'org.simstore.fixture'],
                ])

    def test_arm64_device_rejected_despite_simulator_plist(self):
        shutil.copy2(self.base / 'device', self.app / 'Fixture')
        with self.assertRaisesRegex(validator.InvalidBundle, 'IOSSIMULATOR'):
            validator.validate(self.app)

    def test_embedded_arm64_macos_binary_rejected(self):
        (self.app / 'Frameworks').mkdir()
        shutil.copy2(self.base / 'macos', self.app / 'Frameworks' / 'hidden.dylib')
        with self.assertRaisesRegex(validator.InvalidBundle, 'IOSSIMULATOR'):
            validator.validate(self.app)

    def test_missing_executable_rejected(self):
        (self.app / 'Fixture').unlink()
        with self.assertRaisesRegex(validator.InvalidBundle, 'executable missing'):
            validator.validate(self.app)

    def test_non_macho_executable_rejected(self):
        (self.app / 'Fixture').write_text('not a Mach-O')
        with self.assertRaisesRegex(validator.InvalidBundle, 'Missing Mach-O'):
            validator.validate(self.app)

    def test_minimum_required(self):
        del self.info['MinimumOSVersion']
        self.write_info()
        with self.assertRaisesRegex(validator.InvalidBundle, 'Invalid OS version'):
            validator.validate(self.app)

    def test_device_plist_rejected(self):
        self.info['CFBundleSupportedPlatforms'] = ['iPhoneOS']
        self.write_info()
        with self.assertRaisesRegex(validator.InvalidBundle, 'iPhoneSimulator'):
            validator.validate(self.app)

    def test_executable_path_escape_rejected(self):
        self.info['CFBundleExecutable'] = '../simulator'
        self.write_info()
        with self.assertRaisesRegex(validator.InvalidBundle, 'invalid executable name'):
            validator.validate(self.app)

    def test_symlink_escape_rejected(self):
        (self.app / 'outside').symlink_to(self.base / 'simulator')
        with self.assertRaisesRegex(validator.InvalidBundle, 'Symlink escapes'):
            validator.validate(self.app)

    def test_higher_embedded_minimum_reported(self):
        self.info['MinimumOSVersion'] = '16.0'
        self.write_info()
        self.assertEqual(validator.validate(self.app)[2], (17, 0, 0))

    def manifest(self, deployment='17.0', minimum=None):
        directory = Path(self.work.name) / 'example'
        directory.mkdir()
        (directory / 'build.sh').write_text('#!/bin/bash\n')
        path = directory / 'manifest.yaml'
        data = dict(
            id='example', name='Example',
            source=dict(repository='https://example.com/apps/example', version='v1.0.0', revision='a' * 40),
            build=dict(script='build.sh', deploymentTarget=deployment))
        if minimum is not None:
            data['compatibility'] = dict(minSimulatorOS=minimum)
        path.write_text(json.dumps(data))
        return path

    def test_manifest_uses_binary_floor_without_compatibility(self):
        info, _, minimum = validator.validate(self.app)
        self.assertEqual(validator.check_manifest(self.manifest(), info, minimum), '17.0')

    def test_manifest_accepts_higher_explicit_minimum(self):
        info, _, minimum = validator.validate(self.app)
        self.assertEqual(validator.check_manifest(self.manifest(minimum='27.0'), info, minimum), '27.0')

    def test_omitted_compatibility_keeps_embedded_binary_requirement(self):
        self.info['MinimumOSVersion'] = '16.0'
        self.write_info()
        info, _, minimum = validator.validate(self.app)
        self.assertEqual(validator.check_manifest(self.manifest(deployment='16.0'), info, minimum), '17.0')

    def test_manifest_rejects_app_version_drift(self):
        path = self.manifest()
        manifest = json.loads(path.read_text())
        manifest['source']['version'] = 'v2.0.0'
        path.write_text(json.dumps(manifest))
        info, _, minimum = validator.validate(self.app)
        with self.assertRaisesRegex(validator.InvalidBundle, 'App version.*differs'):
            validator.check_manifest(path, info, minimum)

    def test_manifest_rejects_deployment_drift(self):
        info, _, minimum = validator.validate(self.app)
        with self.assertRaisesRegex(validator.InvalidBundle, 'deployment target.*differs'):
            validator.check_manifest(self.manifest(deployment='16.0'), info, minimum)

    def test_manifest_rejects_understated_binary_minimum(self):
        self.info['MinimumOSVersion'] = '16.0'
        self.write_info()
        info, _, minimum = validator.validate(self.app)
        with self.assertRaisesRegex(validator.InvalidBundle, 'below an embedded binary'):
            validator.check_manifest(self.manifest(deployment='16.0', minimum='16.0'), info, minimum)


if __name__ == '__main__':
    unittest.main()
