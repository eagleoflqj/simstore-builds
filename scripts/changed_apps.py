#!/usr/bin/env python3
"""Select independent app jobs from changed paths or an explicit project id."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys


def select_projects(root: Path, paths: list[str], project_id: str = '') -> list[str]:
    available = {path.parent.name for path in (root / 'apps').glob('*/manifest.yaml')}
    if project_id:
        if project_id not in available:
            raise ValueError(f'Unknown project: {project_id}')
        return [project_id]
    return sorted({parts[1] for path in paths if len(parts := path.split('/')) >= 3
                   and parts[0] == 'apps' and parts[1] in available})


def changed_paths(root: Path, base: str, head: str, event: str) -> list[str]:
    if not base or set(base) == {'0'}:
        command = ['git', '-C', str(root), 'ls-tree', '-r', '--name-only', '-z', head, '--', 'apps/']
    else:
        comparison = f'{base}...{head}' if event == 'pull_request' else f'{base}..{head}'
        command = ['git', '-C', str(root), 'diff', '--name-only', '--no-renames', '-z', comparison, '--', 'apps/']
    output = subprocess.check_output(command)
    return [path.decode() for path in output.split(b'\0') if path]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--id', default='')
    parser.add_argument('--base', default='')
    parser.add_argument('--head', default='HEAD')
    parser.add_argument('--event', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        paths = [] if args.id else changed_paths(root, args.base, args.head, args.event)
        projects = select_projects(root, paths, args.id)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Project selection FAILED: {error}', file=sys.stderr)
        return 1
    print('projects=' + json.dumps(projects, separators=(',', ':')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
