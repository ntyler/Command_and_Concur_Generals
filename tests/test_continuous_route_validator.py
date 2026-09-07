"""J-only offline evidence profile checks; all row fixtures are synthetic data."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


I = module('i_contract_profile_tests', ROOT / 'tests/test_continuous_capture_validator.py')
J = module('j_contract_profile_tests', ROOT / 'tools/validate_continuous_route_capture.py')


def records(mode='synthetic_contract', count=2):
    result = I.records(mode, count)
    result[0]['limits']['max_bytes'] = J.MAX_BYTES
    return result


def route(settling=180):
    result = records('route', 1)
    for order, at in ((1, 11), (2, 12)):
        for unit_id in range(1, 51):
            point = I.state(unit_id)['assigned']
            result.append({'type': 'event', 'frame': at, 'kind': 'move_command_result', 'id': unit_id,
                           'details': {'accepted': True, 'requested_destination': point},
                           'after': {'id': unit_id, 'order': order, 'assigned': point}})
        result.append(I.frame(at, order=order))
    result.extend(I.frame(at, order=2) for at in range(13, 13 + settling))
    return result


class ContinuousRouteProfileTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='continuous-j-offline-')
        self.path = Path(self.directory.name) / 'capture.jsonl'

    def tearDown(self):
        self.directory.cleanup()

    def check_capture(self, items=None, mode='synthetic_contract', footer=None, raw=None):
        self.path.write_bytes(raw if raw is not None else I.encode(items if items is not None else records(), footer))
        return J.validate_capture(self.path, mode, 'a' * 64, 'b' * 64)

    def failure(self, result, code, integrity=False):
        self.assertEqual(result['exit_code'], 2 if integrity else 1, result)
        self.assertEqual(result['capture_valid'], not integrity, result)
        self.assertIn(code, {r['code'] for r in result['capture_errors' if integrity else 'gameplay_failures']}, result)

    def test_profile_namespace_isolated_from_original_I(self):
        self.assertEqual(I.VALIDATOR.MAX_BYTES, 1073741824)
        self.assertEqual(J.CONTRACT.MAX_BYTES, 4294967296)
        result = self.check_capture()
        self.assertEqual(result['exit_code'], 0, result)
        self.assertEqual(result['limits']['max_bytes'], 4294967296)
        self.assertEqual(I.VALIDATOR.MAX_BYTES, 1073741824)
        self.failure(self.check_capture(I.records()), 'limits', True)
        self.path.write_bytes(I.encode(I.records()))
        self.assertEqual(I.VALIDATOR.validate_capture(self.path, 'synthetic_contract')['exit_code'], 0)

    def test_parked_adapter_receipt(self):
        self.assertEqual(self.check_capture(records('parked_wiring'), 'parked_wiring')['exit_code'], 0)
        self.failure(self.check_capture(records('parked_wiring'), 'parked_wiring', {'precluster_teardown': False}), 'precluster_boundary', True)

    def test_exact_original_step_threshold(self):
        items = records()
        items[-1]['rows'][0]['callbacks'] = [I.callback(step=5/60 + .001 - 1e-9)]
        self.assertEqual(self.check_capture(items)['exit_code'], 0)
        items[-1]['rows'][0]['callbacks'] = [I.callback(step=5/60 + .001 + 1e-9)]
        self.failure(self.check_capture(items), 'actual_step_excess')

    def test_wrong_delta_ordinary_gameplay_failure(self):
        items = records()
        callback = I.callback()
        callback['movement_calls'][0]['delta'] = 1/30
        items[-1]['rows'][0]['callbacks'] = [callback]
        self.failure(self.check_capture(items), 'movement_delta')

    def test_stamp_contradiction_remains_integrity_failure(self):
        items = records()
        callback = I.callback()
        callback['movement_calls'][0]['movement_frame_changed'] = False
        items[-1]['rows'][0]['callbacks'] = [callback]
        self.failure(self.check_capture(items), 'contradictory_stamp', True)

    def test_digest_and_truncation_still_rejected(self):
        raw = I.encode(records())
        self.failure(self.check_capture(raw=raw.replace(b'offline-contract', b'changed-contract', 1)), 'artifact_digest', True)
        self.failure(self.check_capture(raw=raw.rsplit(b'\n', 2)[0] + b'\n'), 'missing_footer', True)

    def test_missing_middle_frame_and_participant_rejected(self):
        items = records(count=3)
        items.pop(2)
        self.failure(self.check_capture(items), 'frame_gap_or_onset', True)
        items = records()
        items[-1]['rows'].pop()
        self.failure(self.check_capture(items), 'participant_coverage', True)

    def test_route_exact_180_ticks_still_required(self):
        positive = self.check_capture(route(), 'route')
        self.assertEqual(positive['exit_code'], 0, positive)
        self.assertEqual(positive['stats']['settling_frames'], 180)
        self.failure(self.check_capture(route(179), 'route'), 'arrival_and_180_tick_settling')

    def test_original_settling_velocity_threshold(self):
        items = route()
        items[-1]['rows'][0]['state']['velocity'] = [.001, 0., 0.]
        self.failure(self.check_capture(items, 'route'), 'settling_velocity')

    def test_original_separation_predicate(self):
        items = route()
        for item in items:
            if item.get('type') == 'frame' and item['frame'] >= 12:
                second = item['rows'][1]['state']
                second['position'] = [2.5, 0., 0.]
                second['assigned'] = [2.5, 0., 0.]
            elif item.get('kind') == 'move_command_result' and item['id'] == 2 and item['frame'] == 12:
                item['details']['requested_destination'] = [2.5, 0., 0.]
                item['after']['assigned'] = [2.5, 0., 0.]
        self.failure(self.check_capture(items, 'route'), 'settling_separation')

    def test_gameplay_receipt_presence_and_failure(self):
        items = route()
        self.failure(self.check_capture(items, 'route', {'gameplay': None}), 'inherited_gameplay_receipt', True)
        self.failure(self.check_capture(items, 'route', {'gameplay': {'checks': 32, 'failures': 1}}), 'inherited_gameplay_failures')

    def test_authority_and_required_commands_unchanged(self):
        items = route()
        items[-1]['rows'][0]['state']['assigned'] = [99., 0., 0.]
        self.failure(self.check_capture(items, 'route'), 'accepted_goal_authority')
        self.failure(self.check_capture(records('route'), 'route'), 'cluster_public_commands')

    def test_profile_does_not_relax_frame_limit(self):
        items = records()
        items[0]['limits']['max_frames'] = 10001
        self.failure(self.check_capture(items), 'limits', True)

    def test_cli_profile_and_original_source_hash(self):
        self.path.write_bytes(I.encode(records()))
        output = self.path.with_suffix('.report.json')
        call = subprocess.run([sys.executable, '-B', str(ROOT/'tools/validate_continuous_route_capture.py'), str(self.path),
                               '--expected-mode', 'synthetic_contract', '--expected-source-sha256', 'a'*64,
                               '--expected-fixture-sha256', 'b'*64, '--output', str(output)], capture_output=True, text=True)
        self.assertEqual(call.returncode, 0, call.stderr)
        result = json.loads(output.read_text())
        self.assertEqual(result['capture_profile'], 'm501j_4gib_evidence_storage')
        self.assertEqual(len(result['inherited_validator_sha256']), 64)
        self.assertEqual(I.VALIDATOR.MAX_BYTES, 1073741824)


if __name__ == '__main__':
    unittest.main(verbosity=2)
