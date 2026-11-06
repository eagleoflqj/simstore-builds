#!/usr/bin/env python3
"""Normalize, optionally strip, and re-sign a staging App Bundle."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import plistlib
import shutil
import stat
import tempfile

from validate import MACH_MAGICS, run, validate


def preserve_sentry_resources(app: Path, binaries: list[Path]) -> None:
    """Retain static Sentry's privacy resources without Xcode's iOS 100 placeholder."""
    framework = app / 'Frameworks/Sentry.framework'
    if not framework.is_dir():
        return
    metadata = plistlib.loads((framework / 'Info.plist').read_bytes())
    if metadata.get('MinimumOSVersion') != '100.0':
        return
    stub = framework / 'Sentry'
    symbols = run('xcrun', 'nm', '-arch', 'arm64', '-Uj', str(stub))
    if set(symbols.splitlines()) - {'__mh_dylib_header'}:
        raise ValueError('Expected the codeless Sentry framework placeholder')
    for binary in binaries:
        if binary != stub and '@rpath/Sentry.framework/Sentry' in run('xcrun', 'otool', '-L', str(binary)):
            raise ValueError('Sentry must be linked statically before removing its placeholder')
    resources = app / 'SentryResources.bundle'
    if resources.exists():
        raise ValueError('Sentry resource bundle already exists')
    shutil.copytree(framework, resources, ignore=shutil.ignore_patterns('Sentry', '_CodeSignature'))
    metadata.pop('CFBundleExecutable', None)
    metadata.pop('MinimumOSVersion', None)
    metadata['CFBundlePackageType'] = 'BNDL'
    (resources / 'Info.plist').write_bytes(plistlib.dumps(metadata, sort_keys=False))
    shutil.rmtree(framework)
    print('Preserved static Sentry privacy resources without its codeless framework placeholder')


def prepare(app: str | Path, strip_symbols: bool = False) -> None:
    app = Path(app).resolve(strict=True)
    if app.suffix != '.app' or not app.is_dir():
        raise ValueError('Expected an existing .app directory')
    binary_paths: list[Path] = []
    for path in sorted(app.rglob('*')):
        if path.is_symlink() and not path.resolve().is_relative_to(app):
            raise ValueError(f'Symlink escapes bundle: {path}')
        if not path.is_file():
            continue
        with path.open('rb') as f:
            magic = f.read(4)
        if magic not in MACH_MAGICS:
            continue
        binary_paths.append(path)
        architectures = set(run('xcrun', 'lipo', '-archs', str(path)).split())
        if 'arm64' not in architectures or architectures - {'arm64', 'x86_64', 'i386'}:
            raise ValueError(f'Unexpected architecture(s): {path}')
        if magic == bytes.fromhex('cffaedfe'):
            continue
        # Prebuilt Simulator frameworks may include 32/64-bit Intel slices. Flutter's
        # lipo -extract arm64 can also leave a fat header with just one slice.
        mode = stat.S_IMODE(path.stat().st_mode)
        fd, temporary = tempfile.mkstemp(prefix='.thin-', dir=path.parent)
        os.close(fd)
        try:
            run('xcrun', 'lipo', str(path), '-thin', 'arm64', '-output', temporary)
            os.chmod(temporary, mode)
            os.replace(temporary, path)
        finally:
            Path(temporary).unlink(missing_ok=True)
        print(f'Normalized thin arm64: {path.relative_to(app)}')

    preserve_sentry_resources(app, binary_paths)
    _, binaries, _ = validate(app)
    if strip_symbols:
        for relative in binaries:
            path = app / relative
            before = path.stat().st_size
            # Check both tables separately; nm's dyld-symbol merge is slow on large SDKs.
            symbols = set(run('xcrun', 'nm', '-gUjp', '--no-dyldinfo', str(path)).splitlines())
            exports = run('xcrun', 'dyld_info', '-exports', str(path))
            run('xcrun', 'strip', '-S', '-x', str(path))
            if (symbols != set(run('xcrun', 'nm', '-gUjp', '--no-dyldinfo', str(path)).splitlines())
                    or exports != run('xcrun', 'dyld_info', '-exports', str(path))):
                raise ValueError(f'Strip changed global defined symbols or dyld exports: {relative}')
            print(f'Stripped {relative}: {before} -> {path.stat().st_size} bytes')
        validate(app)
    bundles = sorted([*app.rglob('*.framework'), *app.rglob('*.appex'), *app.rglob('*.app')],
                     key=lambda p: len(p.parts), reverse=True)
    # Embedded Simulator entitlements survive thinning; preserve signing metadata too.
    for path in [*(app / binary for binary in binaries), *bundles, app]:
        run('codesign', '--force', '--sign', '-', '--timestamp=none',
            '--preserve-metadata=identifier,entitlements,flags', str(path))
    run('codesign', '--verify', '--deep', '--strict', str(app))
    print('Ad-hoc signatures verified for the complete bundle')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--strip', action='store_true', help='Remove native debug/local symbols; preserve globals')
    parser.add_argument('--output', type=Path, help='Copy to a new .app directory before processing; must not exist')
    args = parser.parse_args()
    app = args.app
    if args.output:
        source = app.resolve(strict=True)
        target = args.output.resolve()
        if target.suffix != '.app' or target.exists() or target.is_relative_to(source):
            parser.error('--output must be a new .app outside the input bundle')
        if source.suffix != '.app' or not source.is_dir():
            parser.error('Expected an existing .app directory')
        target.parent.mkdir(parents=True, exist_ok=True)
        run('ditto', str(source), str(target))
        app = target
    prepare(app, strip_symbols=args.strip)
