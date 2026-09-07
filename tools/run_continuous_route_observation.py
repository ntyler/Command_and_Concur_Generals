"""Prepare one J observation, guarded by unchanged-source validation receipts."""
import argparse
import hashlib
import json
import math
import os
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
REQUIRED = (
    'tests/continuous_route_checks.gd', 'tests/continuous_route_recorder.gd',
    'tests/continuous_capture_recorder.gd', 'tests/continuous_capture_field.gd',
    'tests/continuous_capture_probe.gd', 'tests/unit13_fixture_checks.gd',
    'tools/run-godot.ps1', 'tools/continuous_route_bridge.ps1',
    'tools/run_continuous_route_observation.py',
)
PRODUCER_TOOLS = set(REQUIRED[-3:])


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def utc():
    return datetime.now(timezone.utc).isoformat()


def write_json(path, value, exclusive=False):
    with Path(path).open('x' if exclusive else 'w', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())


def source_paths(root):
    names = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard'],
        cwd=root, text=True).splitlines()
    return sorted({name for name in names if (root / name).is_file()
                   and not name.startswith('validation-output/')})


def is_producer(name):
    return (Path(name).suffix in {'.gd', '.tscn', '.tres'}
            or name == 'project.godot' or name == 'tests/fixtures/unit13_predeadlock.json'
            or name in PRODUCER_TOOLS)


def producer_manifest(root):
    return [{'File': name, 'SHA256': sha(root / name)}
            for name in source_paths(root) if is_producer(name)]


def artifact(path):
    return {'path': str(Path(path).resolve()), 'sha256': sha(path)}


def successful_receipt(path, mode, producers, root):
    receipt = load(path)
    if receipt.get('mode') != mode or receipt.get('exit_code') != 0:
        raise ValueError('Required successful execution receipt unavailable: ' + str(path))
    if receipt.get('engine_sha256') != ENGINE_SHA or receipt.get('source_sha256') != SOURCE_SHA or receipt.get('fixture_sha256') != FIXTURE_SHA:
        raise ValueError('Validation receipt input identities changed.')
    if receipt.get('producer_manifest') != producers:
        raise ValueError('Producer sources differ from the successful validation execution.')
    retained = Path(receipt.get('retained_source', '')).resolve()
    if retained.parent != (root / 'validation-output').resolve():
        raise ValueError('Invalid retained validation source path.')
    for entry in producers:
        if sha(retained / entry['File']) != entry['SHA256']:
            raise ValueError('Retained validation producer source changed.')
    prefix = Path(str(path)[:-len('-invocation.json')])
    for suffix, key in [('-inputs.json', 'inputs_sha256'), ('-stdout.txt', 'stdout_sha256'), ('-stderr.txt', 'stderr_sha256')]:
        if sha(str(prefix) + suffix) != receipt.get(key):
            raise ValueError('Validation input/output receipt integrity mismatch.')
    return receipt


def validation_gates(mode, prefix, producers, root):
    """No engine calls; immutable preceding receipts are mandatory."""
    output = root / 'validation-output'
    slot = output / 'm501j-observation-slot.json'
    if slot.exists():
        raise ValueError('The single observation slot is already consumed; no further J engine execution.')
    if mode == 'parse':
        if prefix.name == 'm501j-parser-2':
            first = load(output / 'm501j-parser-1-invocation.json')
            if first.get('mode') != 'parse' or not isinstance(first.get('exit_code'), int) or first['exit_code'] == 0:
                raise ValueError('Parser2 requires an actual failed parser1 receipt.')
        return []
    parser_path = None
    for candidate in ['m501j-parser-2-invocation.json', 'm501j-parser-1-invocation.json']:
        path = output / candidate
        if path.is_file() and load(path).get('exit_code') == 0:
            successful_receipt(path, 'parse', producers, root)
            parser_path = path
            break
    if parser_path is None:
        raise ValueError('A successful current-source parser execution is required.')
    gates = [artifact(parser_path)]
    if mode == 'validate':
        return gates
    validation_path = output / 'm501j-validate-1-invocation.json'
    successful_receipt(validation_path, 'validate', producers, root)
    result_path = output / 'm501j-validate-1-result.json'
    result = load(result_path)
    if (result.get('mode') != 'validate' or result.get('failures') != 0
            or result.get('capture_complete') is not True
            or result.get('footer', {}).get('complete') is not True
            or result.get('cluster_commands') != 0 or result.get('cluster_physics_steps') != 0
            or result.get('live_field') is not False):
        raise ValueError('Precluster validation must pass completely with no cluster command or physics.')
    independent_path = output / 'm501j-validate-1-independent-report.json'
    independent = load(independent_path)
    if (independent.get('capture_valid') is not True or independent.get('gameplay_pass') is not True
            or independent.get('exit_code') != 0
            or independent.get('file_sha256') != sha(output / 'm501j-validate-1.jsonl')):
        raise ValueError('Independent complete precluster capture validation is required.')
    gates += [artifact(validation_path), artifact(result_path), artifact(independent_path),
              artifact(output / 'm501j-validate-1.jsonl')]
    return gates


def finite_vector(value):
    return isinstance(value, list) and len(value) == 3 and all(
        isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(item)
        for item in value)


def preflight(mode, prefix, fixture_path=FIXTURE, engine=ENGINE, root=ROOT):
    if mode not in {'parse', 'validate', 'observe'}:
        raise ValueError('Only parse, precluster validate and the single observe mode are allowed.')
    root, prefix = Path(root).resolve(), Path(prefix).resolve()
    allowed = {'parse': {'m501j-parser-1', 'm501j-parser-2'},
               'validate': {'m501j-validate-1'}, 'observe': {'m501j-observe-1'}}
    if prefix.parent != root / 'validation-output' or prefix.name not in allowed[mode]:
        raise ValueError('Use the predetermined direct validation-output prefix for this mode.')
    if any(prefix.parent.glob(prefix.name + '*')):
        raise ValueError('Execution prefix exists; every prior attempt is preserved.')
    if sha(fixture_path) != FIXTURE_SHA:
        raise ValueError('Frozen fixture missing or modified.')
    fixture = load(fixture_path)
    units = fixture.get('units')
    if (not isinstance(units, list) or len(units) != 50
            or any(not isinstance(unit, dict) for unit in units)
            or [unit.get('id') for unit in units] != list(range(1, 51))):
        raise ValueError('The exact ordered 50-unit fixture is required.')
    if any(not finite_vector(unit.get(key)) for unit in units for key in ['position', 'parking_goal', 'goal']):
        raise ValueError('All fixture vectors must be complete and finite.')
    if units[40]['goal'] != [28.5, 0.0, 17.5]:
        raise ValueError('Unit41 exact accepted goal changed.')
    if sha(root / 'scripts/rts_unit.gd') != SOURCE_SHA or sha(engine) != ENGINE_SHA:
        raise ValueError('Unchanged validated production and engine identities are required.')
    for name in REQUIRED:
        if not (root / name).is_file():
            raise ValueError('Required producer source missing: ' + name)
    producers = producer_manifest(root)
    if not all(any(item['File'] == name for item in producers) for name in REQUIRED):
        raise ValueError('Every required producer must be included in the source inventory.')
    gates = validation_gates(mode, prefix, producers, root)
    return fixture, producers, gates


def execute(mode, prefix, launch=subprocess.run, fixture_path=FIXTURE, engine=ENGINE, root=ROOT):
    root, prefix = Path(root).resolve(), Path(prefix).resolve()
    fixture, producers, gates = preflight(mode, prefix, fixture_path, engine, root)
    pwsh = shutil.which('pwsh')
    if not pwsh:
        raise ValueError('Audited PowerShell wrapper runtime unavailable; no engine launch.')
    inputs = {'mode': 'validate' if mode == 'parse' else mode, 'fixture_sha256': FIXTURE_SHA,
              'production_sha256': SOURCE_SHA, 'fixture': fixture}
    input_path = Path(str(prefix) + '-inputs.json')
    write_json(input_path, inputs, True)
    if load(input_path) != inputs:
        raise ValueError('Prepared input round-trip failed; no engine launch.')
    source_dir = Path(str(prefix) + '-source')
    source_dir.mkdir()
    (source_dir / '.gdignore').write_text('', encoding='utf-8')
    manifest = []
    for name in source_paths(root):
        source, target = root / name, source_dir / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        digest = sha(source)
        if sha(target) != digest:
            raise ValueError('Retained source copy mismatch; no engine launch.')
        manifest.append({'File': name, 'SHA256': digest})
    if producer_manifest(root) != producers:
        raise ValueError('Producer changed during preparation; no engine launch.')
    for entry in producers:
        if sha(source_dir / entry['File']) != entry['SHA256']:
            raise ValueError('Prepared producer snapshot is stale; no engine launch.')
    arguments = [str(engine), '--headless', '--path', str(root), '--fixed-fps', '60', '--script',
                 'res://tests/continuous_route_checks.gd', '--log-file', str(prefix) + '.log']
    if mode == 'parse':
        arguments.append('--check-only')
    arguments += ['--', '--diagnostic-prefix=' + str(prefix), '--capture-run-id=' + prefix.name,
                  '--continuous-route-mode=' + inputs['mode'], '--continuous-route-inputs=' + str(input_path)]
    invocation_path = Path(str(prefix) + '-invocation.json')
    wrapper_args = [pwsh, '-NoProfile', '-File', str(root / 'tools/continuous_route_bridge.ps1'),
                    '-InvocationPath', str(invocation_path)]
    invocation = {'schema_version': 1, 'mode': mode, 'command_argv': arguments,
                  'exact_display_command': subprocess.list2cmdline(arguments), 'wrapper_argv': wrapper_args,
                  'engine_sha256': ENGINE_SHA, 'source_sha256': SOURCE_SHA, 'fixture_sha256': FIXTURE_SHA,
                  'inputs_sha256': sha(input_path), 'launcher_sha256': sha(root / 'tools/run_continuous_route_observation.py'),
                  'wrapper_sha256': sha(root / 'tools/run-godot.ps1'),
                  'bridge_sha256': sha(root / 'tools/continuous_route_bridge.ps1'),
                  'source_manifest': manifest, 'producer_manifest': producers, 'retained_source': str(source_dir),
                  'gate_artifacts': gates, 'started_utc': utc(), 'timeout_seconds': 240,
                  'observation_slots_spent': 0, 'engine_launch_attempted': False, 'exit_code': None}
    write_json(invocation_path, invocation, True)
    stdout_path, stderr_path = Path(str(prefix) + '-stdout.txt'), Path(str(prefix) + '-stderr.txt')
    stdout_path.touch(exist_ok=False)
    stderr_path.touch(exist_ok=False)
    # Check every prerequisite once more after preparation, before consuming a slot.
    validation_gates(mode, prefix, producers, root)
    if producer_manifest(root) != producers:
        raise ValueError('Producer changed immediately before launch; no engine launch.')
    if mode == 'observe':
        slot_path = root / 'validation-output/m501j-observation-slot.json'
        write_json(slot_path, {'invocation_path': str(invocation_path), 'prefix': str(prefix),
                              'consumed_utc': utc(), 'attempts': 1,
                              'rule': 'Consumed on any launch failure, timeout, non-reproduction or gameplay failure; no retry.'}, True)
        invocation['observation_slots_spent'] = 1
        invocation['slot_path'] = str(slot_path)
    invocation['engine_launch_attempted'] = True
    write_json(invocation_path, invocation)
    try:
        completed = launch(wrapper_args, cwd=root, capture_output=True, text=True)
        stdout_path.write_text(completed.stdout or '', encoding='utf-8')
        stderr_path.write_text(completed.stderr or '', encoding='utf-8')
        invocation['exit_code'] = completed.returncode
        invocation['external_timeout'] = completed.returncode == 124
    except (OSError, subprocess.SubprocessError) as exc:
        stderr_path.write_text(type(exc).__name__ + ': ' + str(exc) + '\n', encoding='utf-8')
        invocation['exit_code'] = 2
        invocation['launch_error'] = type(exc).__name__ + ': ' + str(exc)
        invocation['external_timeout'] = isinstance(exc, subprocess.TimeoutExpired)
    finally:
        invocation['ended_utc'] = utc()
        invocation['stdout_sha256'] = sha(stdout_path)
        invocation['stderr_sha256'] = sha(stderr_path)
        write_json(invocation_path, invocation)
    print(json.dumps({'mode': mode, 'exit_code': invocation['exit_code'], 'invocation': str(invocation_path),
                      'observation_slots_spent': invocation['observation_slots_spent']}))
    return invocation['exit_code']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['parse', 'validate', 'observe'], required=True)
    parser.add_argument('--prefix', type=Path, required=True)
    args = parser.parse_args()
    try:
        return execute(args.mode, args.prefix)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print('CONTINUOUS_ROUTE_PREFLIGHT_BLOCKED: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
