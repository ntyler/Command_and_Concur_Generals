"""J launcher contract: failed preparation never starts an engine callable."""
import importlib.util
import json
import subprocess
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('continuous_route_launcher', ROOT / 'tools/run_continuous_route_observation.py')
LAUNCHER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LAUNCHER)


class RouteLaunchGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'repo'
        self.output = self.root / 'validation-output'
        self.output.mkdir(parents=True)
        self.engine = self.base / 'fake-engine.exe'
        self.engine.write_bytes(b'fake engine, never executed')
        for name in (*LAUNCHER.REQUIRED, 'scripts/rts_unit.gd', 'project.godot'):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('test-only producer ' + name, encoding='utf-8')
        self.fixture = self.root / 'tests/fixtures/unit13_predeadlock.json'
        self.fixture.parent.mkdir(parents=True)
        self.fixture.write_bytes(LAUNCHER.FIXTURE.read_bytes())
        stack = ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(patch.object(LAUNCHER, 'SOURCE_SHA', LAUNCHER.sha(self.root / 'scripts/rts_unit.gd')))
        stack.enter_context(patch.object(LAUNCHER, 'ENGINE_SHA', LAUNCHER.sha(self.engine)))
        stack.enter_context(patch.object(LAUNCHER.shutil, 'which', return_value='fake-pwsh-never-executed'))
        stack.enter_context(patch.object(LAUNCHER, 'source_paths', side_effect=self.inventory))
        self.launch = Mock(return_value=subprocess.CompletedProcess(['fake'], 0, 'fake stdout', ''))

    def inventory(self, root):
        return sorted(str(path.relative_to(root)).replace('\\', '/') for path in root.rglob('*')
                      if path.is_file() and 'validation-output' not in path.relative_to(root).parts)

    def execute(self, mode='observe', prefix=None, **kwargs):
        names = {'parse': 'm501j-parser-1', 'validate': 'm501j-validate-1', 'observe': 'm501j-observe-1'}
        arguments = {'launch': self.launch, 'fixture_path': self.fixture, 'engine': self.engine, 'root': self.root}
        arguments.update(kwargs)
        return LAUNCHER.execute(mode, prefix or self.output / names.get(mode, 'm501j-observe-1'), **arguments)

    def blocked(self, *args, **kwargs):
        with self.assertRaises((OSError, ValueError, KeyError, TypeError)):
            self.execute(*args, **kwargs)
        self.launch.assert_not_called()
        self.assertFalse((self.output / 'm501j-observation-slot.json').exists())

    def receipt(self, mode, name):
        """Mock producer evidence; no engine is involved in any test."""
        prefix = self.output / name
        source = Path(str(prefix) + '-source')
        producers = LAUNCHER.producer_manifest(self.root)
        for entry in producers:
            target = source / entry['File']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((self.root / entry['File']).read_bytes())
        Path(str(prefix) + '-inputs.json').write_text('{}')
        Path(str(prefix) + '-stdout.txt').write_text('mock successful validation')
        Path(str(prefix) + '-stderr.txt').write_text('')
        receipt = {'mode': mode, 'exit_code': 0, 'engine_sha256': LAUNCHER.ENGINE_SHA,
                   'source_sha256': LAUNCHER.SOURCE_SHA, 'fixture_sha256': LAUNCHER.FIXTURE_SHA,
                   'producer_manifest': producers, 'retained_source': str(source),
                   'inputs_sha256': LAUNCHER.sha(str(prefix) + '-inputs.json'),
                   'stdout_sha256': LAUNCHER.sha(str(prefix) + '-stdout.txt'),
                   'stderr_sha256': LAUNCHER.sha(str(prefix) + '-stderr.txt')}
        path = Path(str(prefix) + '-invocation.json')
        LAUNCHER.write_json(path, receipt, True)
        return path

    def gates(self):
        self.receipt('parse', 'm501j-parser-1')
        self.receipt('validate', 'm501j-validate-1')
        LAUNCHER.write_json(self.output / 'm501j-validate-1-result.json', {
            'mode': 'validate', 'checks': 12, 'failures': 0, 'capture_complete': True,
            'footer': {'complete': True}, 'cluster_commands': 0, 'cluster_physics_steps': 0,
            'live_field': False})
        stream = self.output / 'm501j-validate-1.jsonl'
        stream.write_text('mock stream, independent validator tested separately')
        LAUNCHER.write_json(self.output / 'm501j-validate-1-independent-report.json', {
            'capture_valid': True, 'gameplay_pass': True, 'exit_code': 0, 'file_sha256': LAUNCHER.sha(stream)})

    def mutate(self, name, **values):
        path = self.output / name
        record = LAUNCHER.load(path)
        record.update(values)
        LAUNCHER.write_json(path, record)

    def test_missing_fixture_never_launches(self):
        self.blocked(mode='parse', fixture_path=self.output / 'missing.json')

    def test_modified_fixture_never_launches(self):
        self.fixture.write_text('{"units":[]}')
        self.blocked(mode='parse')

    def test_malformed_fixture_never_launches_even_if_digest_matches(self):
        self.fixture.write_text('{ malformed JSON')
        with patch.object(LAUNCHER, 'FIXTURE_SHA', LAUNCHER.sha(self.fixture)):
            self.blocked(mode='parse')

    def test_malformed_unit_entries_never_launch(self):
        fixture = LAUNCHER.load(self.fixture)
        fixture['units'][1] = None
        LAUNCHER.write_json(self.fixture, fixture)
        with patch.object(LAUNCHER, 'FIXTURE_SHA', LAUNCHER.sha(self.fixture)):
            self.blocked(mode='parse')

    def test_nonfinite_vector_never_launches(self):
        fixture = LAUNCHER.load(self.fixture)
        fixture['units'][0]['position'] = [1, 2, float('nan')]
        self.fixture.write_text(json.dumps(fixture))
        with patch.object(LAUNCHER, 'FIXTURE_SHA', LAUNCHER.sha(self.fixture)):
            self.blocked(mode='parse')

    def test_missing_engine_never_launches(self):
        self.blocked(mode='parse', engine=self.output / 'missing.exe')

    def test_production_change_never_launches(self):
        (self.root / 'scripts/rts_unit.gd').write_text('changed')
        self.blocked(mode='parse')

    def test_unknown_mode_never_launches(self):
        self.blocked(mode='repair')

    def test_unbudgeted_prefix_never_launches(self):
        self.blocked(mode='observe', prefix=self.output / 'm501j-observe-2')

    def test_existing_prefix_never_launches(self):
        (self.output / 'm501j-parser-1-failed.txt').write_text('preserve')
        self.blocked(mode='parse')

    def test_missing_source_never_launches(self):
        (self.root / 'tests/continuous_route_checks.gd').unlink()
        self.blocked(mode='parse')

    def test_missing_wrapper_runtime_never_launches(self):
        with patch.object(LAUNCHER.shutil, 'which', return_value=None):
            self.blocked(mode='parse')

    def test_parser2_requires_failed_parser1(self):
        self.blocked(mode='parse', prefix=self.output / 'm501j-parser-2')

    def test_parser2_cannot_repeat_successful_parser1(self):
        self.receipt('parse', 'm501j-parser-1')
        self.blocked(mode='parse', prefix=self.output / 'm501j-parser-2')

    def test_validate_requires_successful_parser(self):
        self.blocked(mode='validate')

    def test_observe_requires_precluster_validation(self):
        self.receipt('parse', 'm501j-parser-1')
        self.blocked()

    def test_failed_precluster_validation_never_launches(self):
        self.gates()
        self.mutate('m501j-validate-1-invocation.json', exit_code=1)
        self.blocked()

    def test_incomplete_precluster_capture_never_launches(self):
        self.gates()
        self.mutate('m501j-validate-1-result.json', capture_complete=False)
        self.blocked()

    def test_validation_with_cluster_movement_never_launches(self):
        self.gates()
        self.mutate('m501j-validate-1-result.json', cluster_physics_steps=1)
        self.blocked()

    def test_validation_with_live_field_never_launches(self):
        self.gates()
        self.mutate('m501j-validate-1-result.json', live_field=True)
        self.blocked()

    def test_missing_independent_report_never_launches(self):
        self.gates()
        (self.output / 'm501j-validate-1-independent-report.json').unlink()
        self.blocked()

    def test_independent_gameplay_failure_never_launches(self):
        self.gates()
        self.mutate('m501j-validate-1-independent-report.json', gameplay_pass=False)
        self.blocked()

    def test_changed_validation_stream_never_launches(self):
        self.gates()
        (self.output / 'm501j-validate-1.jsonl').write_text('altered')
        self.blocked()

    def test_stale_producer_never_launches(self):
        self.gates()
        (self.root / 'tests/continuous_route_checks.gd').write_text('changed after validation')
        self.blocked()

    def test_added_producer_never_launches(self):
        self.gates()
        (self.root / 'tests/new_probe.gd').write_text('new after validation')
        self.blocked()

    def test_changed_retained_source_never_launches(self):
        self.gates()
        (self.output / 'm501j-validate-1-source/tests/continuous_route_checks.gd').write_text('altered retained evidence')
        self.blocked()

    def test_changed_validation_stdout_never_launches(self):
        self.gates()
        (self.output / 'm501j-validate-1-stdout.txt').write_text('altered')
        self.blocked()

    def test_spent_slot_never_launches(self):
        self.gates()
        slot = self.output / 'm501j-observation-slot.json'
        LAUNCHER.write_json(slot, {'attempts': 1}, True)
        with self.assertRaises(ValueError):
            self.execute()
        self.launch.assert_not_called()
        self.assertEqual(LAUNCHER.load(slot), {'attempts': 1})

    def test_preparation_write_failure_never_launches(self):
        with patch.object(LAUNCHER, 'write_json', side_effect=OSError('disk unavailable')):
            self.blocked(mode='parse')

    def test_source_copy_failure_never_launches(self):
        with patch.object(LAUNCHER.shutil, 'copy2', side_effect=OSError('source copy failed')):
            self.blocked(mode='parse')

    def test_parser_calls_fixed_check_only_runner_without_consuming_observation(self):
        self.assertEqual(self.execute('parse'), 0)
        self.launch.assert_called_once()
        receipt = LAUNCHER.load(self.output / 'm501j-parser-1-invocation.json')
        self.assertIn('--check-only', receipt['command_argv'])
        self.assertIn('--continuous-route-mode=validate', receipt['command_argv'])
        self.assertEqual(receipt['observation_slots_spent'], 0)
        self.assertFalse((self.output / 'm501j-observation-slot.json').exists())

    def test_observation_consumes_exactly_one_slot_before_callable(self):
        self.gates()
        def inspect_launch(*args, **kwargs):
            slot = LAUNCHER.load(self.output / 'm501j-observation-slot.json')
            self.assertEqual(slot['attempts'], 1)
            self.assertTrue(Path(slot['invocation_path']).is_file())
            return subprocess.CompletedProcess(args[0], 0, 'completed', '')
        self.launch.side_effect = inspect_launch
        self.assertEqual(self.execute(), 0)
        self.launch.assert_called_once()
        receipt = LAUNCHER.load(self.output / 'm501j-observe-1-invocation.json')
        self.assertEqual(receipt['observation_slots_spent'], 1)
        self.assertIn('--continuous-route-mode=observe', receipt['command_argv'])
        self.assertEqual(receipt['timeout_seconds'], 240)
        with self.assertRaises(ValueError):
            self.execute()
        self.launch.assert_called_once()

    def test_launch_failure_retains_consumed_slot_and_failed_receipt(self):
        self.gates()
        self.launch.side_effect = OSError('failed to start wrapper')
        self.assertEqual(self.execute(), 2)
        receipt = LAUNCHER.load(self.output / 'm501j-observe-1-invocation.json')
        self.assertEqual(receipt['observation_slots_spent'], 1)
        self.assertEqual(receipt['exit_code'], 2)
        self.assertIn('failed to start wrapper', receipt['launch_error'])
        self.assertTrue((self.output / 'm501j-observation-slot.json').exists())
        self.launch.assert_called_once()

    def test_timeout_is_failure_without_retry(self):
        self.gates()
        self.launch.return_value = subprocess.CompletedProcess(['fake'], 124, 'partial capture', 'external timeout')
        self.assertEqual(self.execute(), 124)
        receipt = LAUNCHER.load(self.output / 'm501j-observe-1-invocation.json')
        self.assertTrue(receipt['external_timeout'])
        self.assertEqual(receipt['observation_slots_spent'], 1)
        self.launch.assert_called_once()


if __name__ == '__main__':
    unittest.main(verbosity=2)
