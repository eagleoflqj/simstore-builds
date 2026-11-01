"""Catalog types, validation, and deterministic merging of release fragments."""
from __future__ import annotations

import re
from typing import TypedDict

from schema import (Source, ValidationError, app_id, git_revision, mapping,
                    os_version, release_version, string, validate_source, version_key)

CatalogError = ValidationError


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
        identifier = app_id(app.get('id'), 'app.id')
        name = string(app.get('name'), f'{identifier}.name')
        bundle = string(app.get('bundleID'), f'{identifier}.bundleID')
        if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle):
            raise CatalogError(f'{identifier}: invalid Bundle ID')
        raw_versions = app.get('versions')
        if not isinstance(raw_versions, list) or not raw_versions:
            raise CatalogError(f'{identifier}.versions must be a nonempty array')
        versions: list[AppVersion] = []
        for raw_version in raw_versions:
            record = mapping(raw_version, f'{identifier} version')
            version = release_version(record.get('version'), 'version')
            minimum = string(record.get('minSimulatorOS'), 'minSimulatorOS')
            os_version(minimum, 'minSimulatorOS')
            digest = string(record.get('sha256'), 'sha256')
            if not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise CatalogError('Expected a SHA-256 digest')
            size = record.get('size')
            if not isinstance(size, int) or isinstance(size, bool) or size <= 0:
                raise CatalogError('Archive size must be a positive integer')
            source = validate_source(record.get('source'))
            recipe = git_revision(record.get('recipeRevision'), 'recipeRevision')
            versions.append({'version': version, 'minSimulatorOS': minimum, 'sha256': digest,
                             'size': size, 'source': source,
                             'recipeRevision': recipe})
        apps.append({'id': identifier, 'name': name, 'bundleID': bundle, 'versions': versions})
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
