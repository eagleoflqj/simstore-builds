#!/usr/bin/env python3
"""Install and launch an app on an available compatible iOS Simulator."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
from typing import TypedDict

from validate import InvalidBundle, OSVersion, check_manifest, validate, version


class Runtime(TypedDict):
    identifier: str
    version: str
    isAvailable: bool


class Device(TypedDict):
    udid: str
    state: str
    isAvailable: bool


class Simulators(TypedDict):
    runtimes: list[Runtime]
    devices: dict[str, list[Device]]


def select_device(simulators: Simulators, minimum: OSVersion) -> tuple[str, bool]:
    candidates: list[tuple[OSVersion, bool, str]] = []
    for runtime in simulators['runtimes']:
        if not runtime['isAvailable'] or '.iOS-' not in runtime['identifier']:
            continue
        runtime_version = version(runtime['version'])
        if runtime_version < minimum:
            continue
        for device in simulators['devices'].get(runtime['identifier'], []):
            if device['isAvailable']:
                candidates.append((runtime_version, device['state'] == 'Booted', device['udid']))
    if not candidates:
        raise ValueError('No available iOS Simulator meets the app minimum')
    _, booted, udid = max(candidates)
    return udid, booted


def smoke_test(app: Path, manifest_path: Path | None = None) -> None:
    app = app.resolve(strict=True)
    info, _, minimum = validate(app)
    if manifest_path:
        minimum = version(check_manifest(manifest_path, info, minimum))
    simulators: Simulators = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '--json'], text=True))
    udid, booted = select_device(simulators, minimum)
    if not booted:
        subprocess.run(['xcrun', 'simctl', 'boot', udid], check=True)
    try:
        subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], check=True, timeout=180)
        subprocess.run(['bash', str(Path(__file__).with_name('smoke-test.sh')), str(app), udid],
                       check=True, timeout=180)
    finally:
        if not booted:
            subprocess.run(['xcrun', 'simctl', 'shutdown', udid], check=False)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--manifest', type=Path, help='Honor an additional manifest compatibility minimum')
    args = parser.parse_args()
    try:
        smoke_test(args.app, args.manifest)
    except (InvalidBundle, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'Simulator smoke test FAILED: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
