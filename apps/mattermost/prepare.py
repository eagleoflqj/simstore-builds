#!/usr/bin/env python3
"""Prepare release assets and a Simulator framework for the Rust math engine."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import plistlib
import shutil
import subprocess


def prepare_rust(source: Path, deployment: str) -> None:
    package = source / 'node_modules/ratex-react-native'
    library = package / 'ios/RaTeX.xcframework/ios-arm64_x86_64-simulator'
    native = source.parent / 'native'
    framework = native / 'RaTeXFFI.framework'
    framework.mkdir(parents=True, exist_ok=True)
    archive = native / 'libratex_ffi.a'
    subprocess.run(['xcrun', 'lipo', str(library / 'libratex_ffi.a'), '-thin', 'arm64',
                    '-output', str(archive)], check=True)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    # Isolate Rust's personality routine so the app's compact unwind table fits.
    subprocess.run(['xcrun', 'clang', '-dynamiclib', '-target', f'arm64-apple-ios{deployment}-simulator',
                    '-isysroot', sdk, '-Xlinker', '-force_load', '-Xlinker', str(archive),
                    '-install_name', '@rpath/RaTeXFFI.framework/RaTeXFFI', '-framework', 'Security', '-lc++',
                    '-o', str(framework / 'RaTeXFFI')], check=True)
    (framework / 'Headers').mkdir(exist_ok=True)
    shutil.copy2(library / 'Headers/ratex.h', framework / 'Headers/ratex.h')
    (framework / 'Modules').mkdir(exist_ok=True)
    (framework / 'Modules/module.modulemap').write_text(
        'framework module RaTeXFFI {\n  umbrella header "ratex.h"\n  export *\n}\n')
    version: str = json.loads((package / 'package.json').read_text())['version']
    (framework / 'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier': 'org.ratex.ffi', 'CFBundleName': 'RaTeXFFI', 'CFBundleExecutable': 'RaTeXFFI',
        'CFBundlePackageType': 'FMWK', 'CFBundleShortVersionString': version, 'CFBundleVersion': version,
        'CFBundleSupportedPlatforms': ['iPhoneSimulator'], 'DTPlatformName': 'iphonesimulator',
        'MinimumOSVersion': deployment,
    }))
    output = package / 'ios/RaTeXFFI.xcframework'
    if output.exists():
        shutil.rmtree(output)
    subprocess.run(['xcodebuild', '-create-xcframework', '-framework', str(framework),
                    '-output', str(output)], check=True)


def prepare(source: Path, name: str) -> None:
    assets = source / 'dist/assets'
    catalog = source / 'dist/Images.xcassets'
    shutil.copytree(source / 'ios/Mattermost/Images.xcassets', catalog, dirs_exist_ok=True)
    shutil.copytree(assets / 'release/icons/ios', catalog / 'AppIcon.appiconset', dirs_exist_ok=True)
    for image in ('SplashBackground', 'SplashIcon'):
        shutil.copytree(assets / f'release/splash_screen/ios/{image}.imageset',
                        catalog / f'{image}.imageset', dirs_exist_ok=True)
    for path in sorted((assets / 'i18n').glob('*.json')):
        translations: dict[str, str | None] = json.loads(path.read_text())
        strings: dict[str, list[str]] = {'InfoPlist': [], 'Localizable': []}
        for key, value in translations.items():
            if not value:
                continue
            target = 'Localizable'
            if key.startswith('mobile.ios.plist.'):
                target = 'InfoPlist'
                key = key.rsplit('.', 1)[1]
            value = value.replace('{applicationName}', name)
            strings[target].append(f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(value, ensure_ascii=False)};')
        directory = source / 'dist/i18n' / f'{path.stem}.lproj'
        directory.mkdir(parents=True, exist_ok=True)
        for target, lines in strings.items():
            (directory / f'{target}.strings').write_text('\n'.join(lines) + '\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('name')
    parser.add_argument('deployment')
    args = parser.parse_args()
    prepare(args.source, args.name)
    prepare_rust(args.source, args.deployment)


if __name__ == '__main__':
    main()
