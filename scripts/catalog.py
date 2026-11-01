"""Catalog types, validation, and deterministic merging of release fragments."""
from __future__ import annotations

import re
from typing import TypedDict, cast


class Source(TypedDict):
    repository: str
    revision: str
    license: str


class AppVersion(TypedDict):
    version: str
    minSimulatorOS: str
    sha256: str
    size: int
    source: Source
    recipeRevision: str


class App(TypedDict):
    id: str
    name: str
    bundleID: str
    versions: list[AppVersion]


class Index(TypedDict):
    schemaVersion: int
    apps: list[App]


class CatalogError(ValueError):
    pass


def version_key(value: str) -> tuple[int, int, int]:
    if not re.fullmatch(r'(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)', value):
        raise CatalogError(f'Invalid release version: {value!r}')
    major, minor, patch = map(int, value.split('.'))
    return major, minor, patch


def mapping(value: object, context: str) -> dict[str, object]:
    if not isinstance(value, dict) or not all(isinstance(key, str) for key in value):
        raise CatalogError(f'{context} must be an object')
    return cast('dict[str, object]', value)


def string(value: object, context: str) -> str:
    if not isinstance(value, str) or not value.strip() or value != value.strip() or re.search(r'[\r\n\x00]', value):
        raise CatalogError(f'{context} must be a nonempty string')
    return value


def validate_index(value: object) -> Index:
    data = mapping(value, 'index')
    if type(data.get('schemaVersion')) is not int or data['schemaVersion'] != 1:
        raise CatalogError('Expected schemaVersion 1')
    raw_apps = data.get('apps')
    if not isinstance(raw_apps, list):
        raise CatalogError('index.apps must be an array')
    apps: list[App] = []
    for raw_app in raw_apps:
        app = mapping(raw_app, 'app')
        app_id = string(app.get('id'), 'app.id')
        if not re.fullmatch(r'[a-z][a-z0-9-]*', app_id):
            raise CatalogError(f'Invalid app id: {app_id!r}')
        name = string(app.get('name'), f'{app_id}.name')
        bundle = string(app.get('bundleID'), f'{app_id}.bundleID')
        if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle):
            raise CatalogError(f'{app_id}: invalid Bundle ID')
        raw_versions = app.get('versions')
        if not isinstance(raw_versions, list) or not raw_versions:
            raise CatalogError(f'{app_id}.versions must be a nonempty array')
        versions: list[AppVersion] = []
        for raw_version in raw_versions:
            record = mapping(raw_version, f'{app_id} version')
            release_version = string(record.get('version'), 'version')
            version_key(release_version)
            minimum = string(record.get('minSimulatorOS'), 'minSimulatorOS')
            if not re.fullmatch(r'[1-9]\d*(?:\.\d+){0,2}', minimum):
                raise CatalogError('Invalid minSimulatorOS')
            digest = string(record.get('sha256'), 'sha256')
            if not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise CatalogError('Expected a SHA-256 digest')
            size = record.get('size')
            if not isinstance(size, int) or isinstance(size, bool) or size <= 0:
                raise CatalogError('Archive size must be a positive integer')
            source = mapping(record.get('source'), 'source')
            license_name = source.get('license')
            if not isinstance(license_name, str) or not license_name.strip():
                raise CatalogError('source.license must be a nonempty string')
            repository = string(source.get('repository'), 'source.repository')
            if not repository.startswith('https://') or re.search(r'\s', repository):
                raise CatalogError('Expected an HTTPS source repository')
            revision = string(source.get('revision'), 'source.revision')
            recipe = string(record.get('recipeRevision'), 'recipeRevision')
            if not re.fullmatch(r'[0-9a-f]{40}', revision) or not re.fullmatch(r'[0-9a-f]{40}', recipe):
                raise CatalogError('Expected full source and recipe Git commits')
            versions.append({'version': release_version, 'minSimulatorOS': minimum, 'sha256': digest,
                             'size': size, 'source': {'repository': repository, 'revision': revision, 'license': license_name},
                             'recipeRevision': recipe})
        apps.append({'id': app_id, 'name': name, 'bundleID': bundle, 'versions': versions})
    return {'schemaVersion': 1, 'apps': apps}


def merge_indexes(indexes: list[Index]) -> Index:
    entries: dict[str, dict[str, tuple[str, AppVersion]]] = {}
    bundles: dict[str, str] = {}
    for index in indexes:
        for app in index['apps']:
            app_id = app['id']
            if app_id in bundles and bundles[app_id] != app['bundleID']:
                raise CatalogError(f'{app_id}: conflicting Bundle IDs')
            bundles[app_id] = app['bundleID']
            versions = entries.setdefault(app_id, {})
            for record in app['versions']:
                value = (app['name'], record)
                previous = versions.get(record['version'])
                if previous is not None and previous != value:
                    raise CatalogError(f'{app_id}/{record["version"]}: conflicting version records')
                versions[record['version']] = value
    apps: list[App] = []
    for app_id, records in sorted(entries.items()):
        ordered = sorted(records, key=version_key, reverse=True)
        apps.append({'id': app_id, 'name': records[ordered[0]][0], 'bundleID': bundles[app_id],
                     'versions': [records[release][1] for release in ordered]})
    return {'schemaVersion': 1, 'apps': apps}
