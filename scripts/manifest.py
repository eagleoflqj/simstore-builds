#!/usr/bin/env python3
"""Read and validate an app recipe without evaluating YAML objects or aliases."""
from __future__ import annotations

import argparse
from collections.abc import Hashable
import json
from pathlib import Path
import re
import sys
from typing import TypedDict, cast
from urllib.parse import urlsplit

import yaml


class ManifestError(ValueError):
    pass


class Source(TypedDict):
    repository: str
    version: str
    revision: str
    license: str


class Build(TypedDict):
    script: str
    deploymentTarget: str
    stripSymbols: bool


class Compatibility(TypedDict):
    minSimulatorOS: str


class RequiredManifest(TypedDict):
    id: str
    name: str
    source: Source
    build: Build


class Manifest(RequiredManifest, total=False):
    compatibility: Compatibility


class ManifestLoader(yaml.SafeLoader):
    def compose_node(self, parent: yaml.Node | None, index: int | yaml.Node | None) -> yaml.Node | None:
        if self.check_event(yaml.AliasEvent):
            raise ManifestError('YAML aliases are not allowed')
        # PyYAML also passes mapping key nodes and None; its stubs only accept int.
        return super().compose_node(parent, index)  # type: ignore[arg-type]

    def construct_mapping(self, node: yaml.Node, deep: bool = False) -> dict[Hashable, object]:
        if not isinstance(node, yaml.MappingNode):
            raise ManifestError('YAML mappings must contain key/value pairs')
        result: dict[Hashable, object] = {}
        for key_node, value_node in node.value:
            if key_node.tag != 'tag:yaml.org,2002:str':
                raise ManifestError('YAML mapping keys must be strings')
            key = cast(str, self.construct_object(key_node, deep=deep))
            if key in result:
                raise ManifestError('Duplicate YAML mapping key')
            result[key] = self.construct_object(value_node, deep=deep)
        return result


def mapping(value: object, required: tuple[str, ...], context: str,
            optional: tuple[str, ...] = ()) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ManifestError(f'{context} must be a mapping')
    for key in required:
        if key not in value:
            raise ManifestError(f'{context}.{key} is required')
    unknown = value.keys() - set(required) - set(optional)
    if unknown:
        raise ManifestError(f"{context}: unknown fields {', '.join(sorted(unknown))}")
    return cast('dict[str, object]', value)


def string(value: object, context: str) -> str:
    if not isinstance(value, str) or not value.strip() or value != value.strip() or re.search(r'[\r\n\x00]', value):
        raise ManifestError(f'{context} must be a nonempty string')
    return value


def os_version(value: object, context: str) -> tuple[int, int, int]:
    value = string(value, context)
    if not re.fullmatch(r'[1-9]\d*(?:\.\d+){0,2}', value):
        raise ManifestError(f'{context} must be an OS version string')
    parts = tuple(map(int, value.split('.')))
    padded = parts + (0,) * (3 - len(parts))
    return padded[0], padded[1], padded[2]


def load_manifest(path: str | Path) -> Manifest:
    path = Path(path).absolute()
    try:
        documents = list(yaml.load_all(path.read_text(), Loader=ManifestLoader))
    except yaml.YAMLError as e:
        raise ManifestError(str(e)) from e
    if len(documents) != 1:
        raise ManifestError('Expected exactly one YAML document')
    data = mapping(documents[0], ('id', 'name', 'source', 'build'), 'manifest', ('compatibility',))
    app_id = string(data['id'], 'id')
    if not re.fullmatch(r'[a-z][a-z0-9-]*', app_id):
        raise ManifestError('id must contain lowercase letters, digits or hyphens')
    if app_id != path.parent.name:
        raise ManifestError('id must match the application directory')
    string(data['name'], 'name')

    source = mapping(data['source'], ('repository', 'version', 'revision', 'license'), 'source')
    if not isinstance(source['license'], str) or not source['license'].strip():
        raise ManifestError('source.license must be a nonempty string')
    repository = string(source['repository'], 'source.repository')
    try:
        url = urlsplit(repository)
        valid_repository = url.scheme == 'https' and url.hostname and url.path and '@' not in url.netloc
    except ValueError:
        valid_repository = False
    if not valid_repository or re.search(r'[\s?#]', repository):
        raise ManifestError('source.repository must be an HTTPS repository URL without credentials/query/fragment')
    release_version = string(source['version'], 'source.version')
    if not re.fullmatch(r'v?(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)', release_version):
        raise ManifestError('source.version must be a stable [v]MAJOR.MINOR.PATCH version without leading zeros')
    revision = string(source['revision'], 'source.revision')
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ManifestError('source.revision must be a full 40-character lowercase Git commit')

    build = mapping(data['build'], ('script', 'deploymentTarget'), 'build', ('stripSymbols',))
    build.setdefault('stripSymbols', True)
    if not isinstance(build['stripSymbols'], bool):
        raise ManifestError('build.stripSymbols must be a boolean')
    script = string(build['script'], 'build.script')
    if Path(script).is_absolute() or any(part in ('.', '..') for part in script.split('/')):
        raise ManifestError('build.script must stay inside the application directory')
    directory = path.parent.resolve(strict=True)
    target = (directory / script).resolve(strict=True)
    if not target.is_relative_to(directory) or not target.is_file():
        raise ManifestError('build.script must be a file inside the application directory')
    deployment = os_version(build['deploymentTarget'], 'build.deploymentTarget')

    if 'compatibility' in data:
        compatibility = mapping(data['compatibility'], ('minSimulatorOS',), 'compatibility')
        minimum = os_version(compatibility['minSimulatorOS'], 'compatibility.minSimulatorOS')
        if minimum < deployment:
            raise ManifestError('minSimulatorOS must not be below build.deploymentTarget')
    return cast(Manifest, data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--field', help='Print one string or boolean field without shell evaluation')
    args = parser.parse_args()
    try:
        data = load_manifest(args.manifest)
        if args.field:
            value: object = data
            for key in args.field.split('.'):
                if not isinstance(value, dict) or key not in value:
                    raise ManifestError(f'Unknown field: {args.field}')
                value = value[key]
            if not isinstance(value, (str, bool)):
                raise ManifestError('--field requires a string or boolean scalar')
            print(json.dumps(value) if isinstance(value, bool) else value)
        else:
            print(json.dumps(data, indent=2))
    except (ManifestError, OSError) as e:
        print(f'Manifest FAILED: {e}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
