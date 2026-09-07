"""Fail-closed launcher for recorder validation only; no reproduction mode."""
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_SHA = 'd56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307'
SOURCE_SHA = '1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4'
ENGINE_SHA = 'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'
ENGINE = Path('C:/Users/Tyler/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe')
FIXTURE = ROOT / 'tests/fixtures/unit13_predeadlock.json'

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def vector(value):
    return isinstance(value, list) and len(value) == 3 and all(isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x) for x in value)

def preflight(mode, prefix, fixture_path=FIXTURE, engine=ENGINE, root=ROOT):
    """Pure validation before preparation/engine launch. Raises on any gap."""
    if mode not in {'parse', 'contract', 'parked'}:
        raise ValueError('Only parser, synthetic-contract and parked-wiring validation are allowed; no mechanism mode.')
    prefix = Path(prefix).resolve()
    output_root = (root / 'validation-output').resolve()
    if prefix.parent != output_root or not prefix.name.startswith('m501i-'):
        raise ValueError('Use a unique m501i- prefix directly inside validation-output.')
    if any(output_root.glob(prefix.name + '*')):
        raise ValueError('Prefix already exists; never overwrite an execution.')
    if sha(fixture_path) != FIXTURE_SHA:
        raise ValueError('Frozen fixture missing or modified.')
    fixture = load(fixture_path)
    units = fixture.get('units')
    if not isinstance(units, list) or len(units) != 50 or [u.get('id') for u in units] != list(range(1, 51)):
        raise ValueError('Fixture must contain all50 ordered original participants.')
    for unit in units:
        if not all(vector(unit.get(key)) for key in ['position', 'parking_goal', 'goal']):
            raise ValueError('Every exact fixture vector must be finite and complete.')
    if units[40]['goal'] != [28.5, 0.0, 17.5]:
        raise ValueError('Unit41 accepted goal identity changed.')
    if sha(root / 'scripts/rts_unit.gd') != SOURCE_SHA:
        raise ValueError('Validated production repair must remain unchanged.')
    if sha(engine) != ENGINE_SHA:
        raise ValueError('Engine identity changed or unavailable.')
    for name in ['tests/continuous_capture_checks.gd', 'tests/continuous_capture_recorder.gd', 'tests/continuous_capture_field.gd', 'tests/continuous_capture_probe.gd', 'tools/run-godot.ps1', 'tools/continuous_validation_bridge.ps1']:
        if not (root / name).is_file():
            raise ValueError('Missing required validation source: ' + name)
    # No artifact or engine is created by this preflight function.
    return fixture

def contract_inputs(fixture):
    """Actual retained E calls embedded as DATA in mock frames; no live actors."""
    source = ROOT / 'validation-output/m501e-current-mechanism-headless-1-capture.json'
    expected = '7943c3b375c726152e5e98d8e5f72200e1cd00f5c1636207dffbf33d150cd825'
    if sha(source) != expected:
        raise ValueError('Missing or changed retained contract input capture.')
    capture = load(source)
    records = {m['clock']['absolute_frame']: m['record'] for m in capture['motion_records'].values() if m['identity']['id'] == 41 and m['clock']['absolute_frame'] in [654, 655]}
    if set(records) != {654, 655}:
        raise ValueError('Required exact retained callback records unavailable.')
    frames = []
    for frame in [653, 654, 655]:
        rows = []
        for unit in fixture['units']:
            pos = unit['position']
            state = {'id': unit['id'], 'position': pos, 'assigned': pos, 'next_waypoint': pos, 'order': 0,
                     'moving': False, 'state': 'ARRIVED', 'radius': .34, 'priority': 1., 'requested_velocity': [0., 0., 0.],
                     'last_movement_frame': -1, 'elapsed': 0., 'stall': 0., 'recoveries': 0, 'recovery_target': [0., 0., 0.],
                     'movement_speed': 5., 'avoidance_enabled': True, 'velocity': [0., 0., 0.]}
            callbacks = []
            if unit['id'] == 41:
                rec = records.get(frame)
                observed = records[654]['before'] if rec is None else rec['after']
                state.update(position=observed['position'], assigned=unit['goal'], next_waypoint=[26.8499984741211, 0., 18.8499984741211], order=2, moving=True, state='TRAVELLING', radius=.24, requested_velocity=observed['requested_velocity'], last_movement_frame=observed['movement_frame'])
                if rec is not None:
                    callbacks.append(rec)
            rows.append({'id': unit['id'], 'instance_id': unit['id'], 'state': state, 'physics_observed': frame != 653, 'callbacks': callbacks, 'direct_movements': []})
        frames.append({'frame': frame, 'rows': rows})
    return {'fixture_sha256': FIXTURE_SHA, 'mode': 'synthetic_contract', 'provenance': 'Mock peer/frame rows for serializer validation; Eunit41 callbacks copied as exact data only. No live actor placement or regression.', 'reference_capture': source.name, 'reference_sha256': expected, 'frames': frames}

def execute(mode, prefix, launch=subprocess.run, fixture_path=FIXTURE, engine=ENGINE, root=ROOT):
    """The engine callable is unreachable until all preparation has succeeded."""
    fixture = preflight(mode, prefix, fixture_path, engine, root)
    pwsh = shutil.which('pwsh')
    if not pwsh:
        raise ValueError('Required audited wrapper runtime unavailable; engine not launched.')
    prefix = Path(prefix).resolve()
    inputs = contract_inputs(fixture) if mode == 'contract' else {'fixture_sha256': FIXTURE_SHA, 'fixture': fixture, 'mode': 'parked_wiring'}
    input_path = Path(str(prefix) + '-inputs.json')
    with input_path.open('x', encoding='utf-8') as stream:
        json.dump(inputs, stream, allow_nan=False)
    if load(input_path) != inputs:
        raise ValueError('Prepared input did not round-trip; engine not launched.')
    source_dir = Path(str(prefix) + '-source')
    source_dir.mkdir()
    (source_dir / '.gdignore').write_text('')
    paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard'], cwd=root, text=True).splitlines()
    manifest = []
    for name in sorted(set(paths)):
        path = root / name
        if not path.is_file():
            continue
        target = source_dir / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        digest = sha(path)
        if sha(target) != digest:
            raise ValueError('Source copy mismatch; engine not launched.')
        manifest.append({'File': name, 'SHA256': digest})
    # Launch the fixed runner directly with argument arrays; no shell chaining.
    arguments = [str(engine), '--headless', '--path', str(root), '--fixed-fps', '60', '--script', 'res://tests/continuous_capture_checks.gd', '--log-file', str(prefix) + '.log']
    if mode == 'parse':
        arguments.append('--check-only')
    arguments += ['--', '--continuous-mode=' + ('parked' if mode == 'parse' else mode), '--continuous-prefix=' + str(prefix), '--continuous-inputs=' + str(input_path)]
    invocation = {'mode': mode, 'command_argv': arguments, 'exact_display_command': subprocess.list2cmdline(arguments), 'engine_sha256': sha(engine), 'source_sha256': SOURCE_SHA, 'fixture_sha256': FIXTURE_SHA, 'inputs_sha256': sha(input_path), 'launcher_sha256': sha(__file__), 'source_manifest': manifest, 'retained_source': str(source_dir), 'started_utc': datetime.now(timezone.utc).isoformat(), 'timeout_seconds': 240, 'reproduction_slots_spent': 0, 'exit_code': None}
    invocation_path = Path(str(prefix) + '-invocation.json')
    invocation_path.write_text(json.dumps(invocation, indent=2) + '\n')
    # Existing audited PowerShell wrapper kills the complete process tree on timeout.
    wrapper_args = [pwsh, '-NoProfile', '-File', str(root / 'tools/continuous_validation_bridge.ps1'), '-InvocationPath', str(invocation_path)]
    invocation['wrapper_argv'] = wrapper_args
    invocation['wrapper_sha256'] = sha(root / 'tools/run-godot.ps1')
    invocation['bridge_sha256'] = sha(root / 'tools/continuous_validation_bridge.ps1')
    invocation_path.write_text(json.dumps(invocation, indent=2) + '\n')
    completed = launch(wrapper_args, cwd=root, capture_output=True, text=True)
    Path(str(prefix) + '-stdout.txt').write_text(completed.stdout, encoding='utf-8')
    Path(str(prefix) + '-stderr.txt').write_text(completed.stderr, encoding='utf-8')
    invocation['ended_utc'] = datetime.now(timezone.utc).isoformat()
    invocation['exit_code'] = completed.returncode
    invocation['stdout_sha256'] = sha(Path(str(prefix) + '-stdout.txt'))
    invocation['stderr_sha256'] = sha(Path(str(prefix) + '-stderr.txt'))
    invocation_path.write_text(json.dumps(invocation, indent=2) + '\n')
    print(json.dumps({'mode': mode, 'exit_code': completed.returncode, 'invocation': str(invocation_path)}))
    if completed.returncode:
        print(completed.stdout[-5000:])
        print(completed.stderr[-5000:], file=sys.stderr)
    return completed.returncode

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['parse', 'contract', 'parked'], required=True)
    parser.add_argument('--prefix', type=Path, required=True)
    args = parser.parse_args()
    try:
        return execute(args.mode, args.prefix)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print('CONTINUOUS_PREFLIGHT_BLOCKED: ' + str(exc), file=sys.stderr)
        return 2

if __name__ == '__main__':
    raise SystemExit(main())
