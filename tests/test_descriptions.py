"""Refresh localized catalog descriptions without rebuilding release archives."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import update_index as updater
from catalog import CatalogError, validate_index
from update_index import load_description
from test_catalog import fragment
from test_update_index import release


class DescriptionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / 'description.yaml'
        self.descriptions = {'en': 'An example application.', 'zh-Hans': '示例应用。'}
        self.path.write_text(json.dumps(self.descriptions))

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def read_description(self, path: Path) -> dict[str, str]:
        self.assertEqual(path.name, 'description.yaml')
        self.assertEqual(path.parent.name, 'example')
        return load_description(self.path)

    def test_loads_all_translations(self) -> None:
        self.assertEqual(load_description(self.path), self.descriptions)

    def test_duplicate_translations_are_rejected(self) -> None:
        self.path.write_text('en: Example.\nen: Another description.\n')
        with self.assertRaisesRegex(CatalogError, 'Duplicate YAML'):
            load_description(self.path)

    def test_english_fallback_is_required(self) -> None:
        self.path.write_text('zh-Hans: 示例应用。\n')
        with self.assertRaisesRegex(CatalogError, 'en is required'):
            load_description(self.path)

    def test_collection_adds_current_descriptions_without_mutating_fragment(self) -> None:
        data = fragment()
        original = copy.deepcopy(data)
        with patch.object(updater, 'api_json', return_value=data), \
             patch.object(updater, 'load_description', side_effect=self.read_description):
            index = updater.collect_index([release()])
        self.assertEqual(index['apps'][0]['description'], self.descriptions)
        self.assertEqual(index['apps'][0]['versions'], data['apps'][0]['versions'])
        self.assertEqual(validate_index(index, require_descriptions=True), index)
        self.assertEqual(data, original)

    def test_updating_translation_only_changes_catalog_description(self) -> None:
        data = fragment()
        with patch.object(updater, 'api_json', return_value=data), \
             patch.object(updater, 'load_description', side_effect=self.read_description):
            before = updater.collect_index([release()])
            self.descriptions['zh-Hans'] = '更新后的示例应用描述。'
            self.path.write_text(json.dumps(self.descriptions))
            after = updater.collect_index([release()])
        self.assertNotEqual(before['apps'][0]['description'], after['apps'][0]['description'])
        self.assertEqual(after['apps'][0].pop('description'), self.descriptions)
        before['apps'][0].pop('description')
        self.assertEqual(before, after)
        self.assertNotIn('description', data['apps'][0])

    def test_missing_description_does_not_overwrite_existing_catalog(self) -> None:
        self.path.unlink()
        output = self.path.with_name('index.json')
        output.write_text('Previous catalog')
        with patch.object(updater, 'api_json', return_value=fragment()), \
             patch.object(updater, 'list_releases', return_value=[release()]), \
             patch.object(updater, 'load_description', side_effect=self.read_description):
            with self.assertRaises(FileNotFoundError):
                updater.generate_index(output)
        self.assertEqual(output.read_text(), 'Previous catalog')


if __name__ == '__main__':
    unittest.main()
