#!/usr/bin/env python3
"""Normalize, optionally strip, and re-sign a staging App Bundle."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import stat
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from validate import MACH_MAGICS, run, validate


def prepare(app: str | Path, strip_symbols: bool = False) -> None:
    app = Path(app).resolve(strict=True)
    if app.suffix != '.app' or not app.is_dir():
        raise ValueError('Expected an existing .app directory')
    for path in sorted(app.rglob('*')):
        if path.is_symlink() and not path.resolve().is_relative_to(app):
            raise ValueError(f'Symlink escapes bundle: {path}')
        if not path.is_file():
            continue
        with path.open('rb') as f:
            magic = f.read(4)
        if magic not in MACH_MAGICS:
            continue
        if run('xcrun', 'lipo', '-archs', str(path)).split() != ['arm64']:
            raise ValueError(f'Unexpected architecture(s): {path}')
        if magic == bytes.fromhex('cffaedfe'):
            continue
        # Flutter's lipo -extract arm64 keeps a fat header with just one slice.
        # Use -thin only after verifying there are no other architectures.
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

    _, binaries, _ = validate(app)
    if strip_symbols:
        for relative in binaries:
            path = app / relative
            before = path.stat().st_size
            # Keep exported symbols required by Dart FFI/dlsym and native plugins.
            exports = set(run('xcrun', 'nm', '-gUj', str(path)).splitlines())
            run('xcrun', 'strip', '-S', '-x', str(path))
            if exports != set(run('xcrun', 'nm', '-gUj', str(path)).splitlines()):
                raise ValueError(f'Strip changed global defined symbols: {relative}')
            print(f'Stripped {relative}: {before} -> {path.stat().st_size} bytes')
        validate(app)
    bundles = sorted([*app.rglob('*.framework'), *app.rglob('*.appex')],
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
        validate(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        run('ditto', str(source), str(target))
        app = target
    prepare(app, strip_symbols=args.strip)
