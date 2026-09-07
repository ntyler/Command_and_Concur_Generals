"""A failed preparation must never reach the engine launch callable."""
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('continuous_launcher', ROOT / 'tools/run_continuous_validation.py')
LAUNCHER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LAUNCHER)

class LaunchGateTests(unittest.TestCase):
    def blocked(self, mode='parked', **overrides):
        calls = []
        def launch(*args, **kwargs):
            calls.append((args, kwargs))
            self.fail('Engine callable reached after preparation failure')
        with self.assertRaises((ValueError, OSError)):
            LAUNCHER.execute(mode, ROOT / 'validation-output/m501i-launch-gate-must-not-exist', launch=launch, **overrides)
        self.assertEqual(calls, [])

    def test_missing_fixture_never_launches(self):
        self.blocked(fixture_path=ROOT / 'validation-output/absent-continuous-fixture.json')

    def test_changed_fixture_never_launches(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / 'fixture.json'
            fixture.write_text('{"units":[]}')
            self.blocked(fixture_path=fixture)

    def test_mechanism_mode_never_launches(self):
        self.blocked(mode='route')

    def test_missing_engine_never_launches(self):
        self.blocked(engine=ROOT / 'validation-output/no-such-godot.exe')

    def test_contract_preparation_exception_never_launches(self):
        with patch.object(LAUNCHER, 'preflight', return_value={}), patch.object(LAUNCHER, 'contract_inputs', side_effect=ValueError('missing retained callback inputs')):
            self.blocked(mode='contract')

    def test_existing_prefix_never_launches(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / 'validation-output').mkdir()
            (base / 'validation-output/m501i-launch-gate-must-not-exist-existing.txt').write_text('preserve')
            with self.assertRaises(ValueError):
                LAUNCHER.preflight('parked', base / 'validation-output/m501i-launch-gate-must-not-exist', root=base)

if __name__ == '__main__':
    unittest.main(verbosity=2)
