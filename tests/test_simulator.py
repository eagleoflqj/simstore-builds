"""Select only available iOS devices compatible with the app's actual minimum."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from simulator import Simulators, select_device, smoke_test


class SimulatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.simulators: Simulators = {
            'runtimes': [
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-17-0', 'version': '17.0', 'isAvailable': True},
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0', 'version': '27.0', 'isAvailable': True},
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.tvOS-28-0', 'version': '28.0', 'isAvailable': True},
            ],
            'devices': {
                'com.apple.CoreSimulator.SimRuntime.iOS-17-0': [
                    {'udid': 'old', 'state': 'Booted', 'isAvailable': True}],
                'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [
                    {'udid': 'new', 'state': 'Shutdown', 'isAvailable': True}],
                'com.apple.CoreSimulator.SimRuntime.tvOS-28-0': [
                    {'udid': 'tv', 'state': 'Booted', 'isAvailable': True}],
            },
        }

    def test_selects_newest_compatible_ios_runtime(self) -> None:
        self.assertEqual(select_device(self.simulators, (17, 0, 0)), ('new', False))

    def test_prefers_booted_device_on_the_same_runtime(self) -> None:
        self.simulators['devices']['com.apple.CoreSimulator.SimRuntime.iOS-27-0'].append(
            {'udid': 'booted', 'state': 'Booted', 'isAvailable': True})
        self.assertEqual(select_device(self.simulators, (27, 0, 0)), ('booted', True))

    def test_skips_unavailable_devices(self) -> None:
        self.simulators['devices']['com.apple.CoreSimulator.SimRuntime.iOS-27-0'][0]['isAvailable'] = False
        self.assertEqual(select_device(self.simulators, (17, 0, 0)), ('old', True))

    def test_skips_unavailable_runtimes(self) -> None:
        self.simulators['runtimes'][1]['isAvailable'] = False
        self.assertEqual(select_device(self.simulators, (17, 0, 0)), ('old', True))

    def test_fails_if_no_compatible_ios_device_exists(self) -> None:
        with self.assertRaisesRegex(ValueError, 'No available iOS Simulator'):
            select_device(self.simulators, (28, 0, 0))

    def test_manifest_minimum_is_honored_before_booting(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Example.app'
            app.mkdir()
            with patch('simulator.validate', return_value=({'CFBundleIdentifier': 'org.simstore.example'}, [], (17, 0, 0))), \
                 patch('simulator.check_manifest', return_value='28.0'), \
                 patch('simulator.subprocess.check_output', return_value=json.dumps(self.simulators)), \
                 patch('simulator.subprocess.run') as run:
                with self.assertRaisesRegex(ValueError, 'No available iOS Simulator'):
                    smoke_test(app, Path(temporary) / 'manifest.yaml')
                run.assert_not_called()

    def test_failed_launch_propagates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Example.app'
            app.mkdir()
            with patch('simulator.validate', return_value=({'CFBundleIdentifier': 'org.simstore.example'}, [], (17, 0, 0))), \
                 patch('simulator.subprocess.check_output', return_value=json.dumps(self.simulators)), \
                 patch('simulator.subprocess.run') as run:
                run.side_effect = [subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 0),
                                   subprocess.CompletedProcess([], 0), subprocess.CalledProcessError(1, 'simctl launch')]
                with self.assertRaises(subprocess.CalledProcessError):
                    smoke_test(app)


if __name__ == '__main__':
    unittest.main()
