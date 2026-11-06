#!/usr/bin/env python3
"""Prepare Readest's native metadata and production frontend assets."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
from typing import Any


def prepare_info(app: Path) -> None:
    tauri = app / 'src-tauri'
    config = json.loads((tauri / 'tauri.conf.json').read_text())
    package = json.loads((app / 'package.json').read_text())
    native_info = tauri / 'gen/apple/Readest_iOS/Info.plist'
    orientations = ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft',
                    'UIInterfaceOrientationLandscapeRight']
    info: dict[str, Any] = {
        'CFBundleDisplayName': config['productName'],
        'CFBundleExecutable': '$(EXECUTABLE_NAME)',
        'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
        'CFBundleInfoDictionaryVersion': '6.0',
        'CFBundleName': config['productName'],
        'CFBundlePackageType': 'APPL',
        'LSRequiresIPhoneOS': True,
        'UILaunchStoryboardName': 'LaunchScreen',
        'UIRequiredDeviceCapabilities': ['arm64', 'metal'],
        'UISupportedInterfaceOrientations': orientations,
        'UISupportedInterfaceOrientations~ipad': [*orientations, 'UIInterfaceOrientationPortraitUpsideDown'],
    }
    for source in (native_info, tauri / 'Info.plist', tauri / config['bundle']['iOS']['infoPlist']):
        if source.exists():
            info.update(plistlib.loads(source.read_bytes()))
    info['CFBundleShortVersionString'] = package['version']
    info['CFBundleVersion'] = package['version']
    info['CFBundleDocumentTypes'] = [
        {'CFBundleTypeExtensions': association['ext'], 'LSItemContentTypes': association['contentTypes'],
         'CFBundleTypeName': association['name'], 'CFBundleTypeRole': association['role'],
         'LSHandlerRank': association['rank']}
        for association in config['bundle']['fileAssociations']
    ]
    native_info.write_bytes(plistlib.dumps(info, sort_keys=False))


def strip_source_maps(app: Path) -> None:
    directory = app / 'out/_next/static'
    if not directory.is_dir():
        raise FileNotFoundError(directory)
    removed = 0
    for path in directory.rglob('*'):
        if path.name.endswith('.js.map'):
            path.unlink()
            removed += 1
        elif path.is_file() and path.suffix == '.js':
            original = path.read_text()
            stripped = re.sub(r'\n//# sourceMappingURL=[^\n]*', '', original)
            if stripped != original:
                path.write_text(stripped)
    print(f'Removed {removed} local JavaScript source maps.')


def prepare_bundle(app: Path) -> None:
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    for extension in app.rglob('*.appex'):
        path = extension / 'Info.plist'
        metadata = plistlib.loads(path.read_bytes())
        for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
            metadata[key] = info[key]
        path.write_bytes(plistlib.dumps(metadata, sort_keys=False))
    framework = app / 'Frameworks/Sentry.framework'
    if framework.is_dir():
        # Xcode embeds a codeless framework with an iOS 100 stub for this static SDK.
        # Keep its privacy manifest as a resource bundle; Sentry's code is in the app.
        stub = framework / 'Sentry'
        symbols = subprocess.check_output(['xcrun', 'nm', '-arch', 'arm64', '-gUj', str(stub)], text=True)
        if set(symbols.splitlines()) - {'__mh_dylib_header'}:
            raise ValueError('Expected the codeless Sentry framework placeholder')
        for bundle in (app, *app.rglob('*.appex')):
            binary = bundle / plistlib.loads((bundle / 'Info.plist').read_bytes())['CFBundleExecutable']
            dependencies = subprocess.check_output(['xcrun', 'otool', '-L', str(binary)], text=True)
            if '@rpath/Sentry.framework/Sentry' in dependencies:
                raise ValueError('Sentry must be linked statically before removing its placeholder')
        resources = app / 'SentryResources.bundle'
        if resources.exists():
            shutil.rmtree(resources)
        shutil.copytree(framework, resources, ignore=shutil.ignore_patterns('Sentry', '_CodeSignature'))
        metadata = plistlib.loads((resources / 'Info.plist').read_bytes())
        metadata.pop('CFBundleExecutable', None)
        metadata.pop('MinimumOSVersion', None)
        metadata['CFBundlePackageType'] = 'BNDL'
        (resources / 'Info.plist').write_bytes(plistlib.dumps(metadata, sort_keys=False))
        shutil.rmtree(framework)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('frontend', 'bundle'))
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    if args.phase == 'frontend':
        prepare_info(args.app)
        strip_source_maps(args.app)
    else:
        prepare_bundle(args.app)


if __name__ == '__main__':
    main()
