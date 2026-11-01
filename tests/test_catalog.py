"""Validate catalog contracts and preserve app history in a stable order."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from catalog import CatalogError, Index, merge_indexes, validate_index


def fragment(app_id: str = 'example', version: str = '1.2.3', name: str = 'Example') -> Index:
    return {'schemaVersion': 1, 'apps': [{
        'id': app_id, 'name': name, 'bundleID': f'org.simstore.{app_id}', 'versions': [{
            'version': version, 'minSimulatorOS': '16.0', 'sha256': 'c' * 64, 'size': 123,
            'source': {'repository': 'https://example.com/app', 'revision': 'a' * 40, 'license': 'MIT'},
            'recipeRevision': 'b' * 40,
        }],
    }]}


class CatalogTests(unittest.TestCase):
    def test_valid_fragment_round_trip(self) -> None:
        data = fragment()
        self.assertEqual(validate_index(json.loads(json.dumps(data))), data)

    def test_legacy_extra_fields_are_not_propagated(self) -> None:
        data = json.loads(json.dumps(fragment()))
        data['apps'][0]['versions'][0].update(buildNumber='7', downloadURL='https://example.com/old')
        self.assertEqual(validate_index(data), fragment())

    def test_merge_preserves_history_and_sorts_versions_numerically(self) -> None:
        fragments = [fragment('beta', '1.9.0', 'Old name'), fragment('alpha', '2.0.0'),
                     fragment('beta', '1.10.0', 'New name'), fragment('beta', '1.0.0')]
        original = copy.deepcopy(fragments)
        merged = merge_indexes(fragments)
        self.assertEqual([app['id'] for app in merged['apps']], ['alpha', 'beta'])
        self.assertEqual([record['version'] for record in merged['apps'][1]['versions']],
                         ['1.10.0', '1.9.0', '1.0.0'])
        self.assertEqual(merged['apps'][1]['name'], 'New name')
        self.assertEqual(merged, merge_indexes(list(reversed(fragments))))
        self.assertEqual(fragments, original)

    def test_identical_versions_are_deduplicated(self) -> None:
        self.assertEqual(merge_indexes([fragment(), fragment()]), fragment())

    def test_conflicting_versions_fail(self) -> None:
        other = fragment()
        other['apps'][0]['versions'][0]['sha256'] = 'd' * 64
        with self.assertRaisesRegex(CatalogError, 'conflicting version records'):
            merge_indexes([fragment(), other])

    def test_conflicting_bundle_ids_fail(self) -> None:
        other = fragment(version='2.0.0')
        other['apps'][0]['bundleID'] = 'org.other.app'
        with self.assertRaisesRegex(CatalogError, 'conflicting Bundle IDs'):
            merge_indexes([fragment(), other])

    def test_empty_repository_has_an_empty_catalog(self) -> None:
        empty: Index = {'schemaVersion': 1, 'apps': []}
        self.assertEqual(merge_indexes([]), empty)
        self.assertEqual(validate_index(empty), empty)

    def test_invalid_schema_and_containers_fail(self) -> None:
        data: object
        for data in (None, [], {'schemaVersion': True, 'apps': []}, {'schemaVersion': 2, 'apps': []},
                     {'schemaVersion': 1, 'apps': {}}):
            with self.subTest(data=data), self.assertRaises(CatalogError):
                validate_index(data)

    def test_invalid_records_fail(self) -> None:
        for field, value in (('version', 'v1.2.3'), ('version', '01.2.3'), ('version', '1.2.3-rc1'),
                             ('sha256', 'bad'), ('size', True), ('size', 0), ('size', '123'),
                             ('minSimulatorOS', '16.beta'), ('recipeRevision', 'main')):
            with self.subTest(field=field, value=value):
                data = json.loads(json.dumps(fragment()))
                data['apps'][0]['versions'][0][field] = value
                with self.assertRaises(CatalogError):
                    validate_index(data)

    def test_missing_fields_and_invalid_source_fail(self) -> None:
        for field in ('version', 'minSimulatorOS', 'sha256', 'size', 'source', 'recipeRevision'):
            with self.subTest(field=field):
                data = json.loads(json.dumps(fragment()))
                del data['apps'][0]['versions'][0][field]
                with self.assertRaises(CatalogError):
                    validate_index(data)
        data = fragment()
        data['apps'][0]['versions'][0]['source']['revision'] = 'main'
        with self.assertRaises(CatalogError):
            validate_index(data)

    def test_source_license_is_required_and_nonempty(self) -> None:
        value: object
        for value in (None, '', '  ', 1, False, [], {}):
            with self.subTest(value=value):
                data = json.loads(json.dumps(fragment()))
                data['apps'][0]['versions'][0]['source']['license'] = value
                with self.assertRaisesRegex(CatalogError, 'source.license'):
                    validate_index(data)
        data = json.loads(json.dumps(fragment()))
        del data['apps'][0]['versions'][0]['source']['license']
        with self.assertRaisesRegex(CatalogError, 'source.license'):
            validate_index(data)

    def test_source_license_is_preserved_without_spdx_validation(self) -> None:
        for value in ('MIT OR Apache-2.0', 'Project custom license', '  custom license\n'):
            with self.subTest(value=value):
                data = fragment()
                data['apps'][0]['versions'][0]['source']['license'] = value
                self.assertEqual(validate_index(data), data)


if __name__ == '__main__':
    unittest.main()
