"""Build static GLB previews and the gameplay model selection from copied assets."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import traceback

import numpy as np
from generals_w3d import Library, convert, write_glb

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'assets/generals_library'
GAMEPLAY = {
    'tank': 'avcrusader',
    'rifle': 'airngr_skn', 'rocket_vehicle': 'avtomahawk',
    'collector': 'nvssupplytk', 'helicopter': 'avcomanche',
    'headquarters': 'abbtcmdhq', 'barracks': 'abbarracks',
    'vehicle_factory': 'abwarfact', 'supply_depot': 'absupplyct',
    'power_plant': 'abpwrplant', 'airfield': 'abarfrccmd',
    'ground_defense': 'nbgattling', 'air_defense': 'abpatriot',
    'wall': 'absecwally', 'wall_support': 'absecwallx', 'supplies': 'zbsmalpile',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gameplay-only', action='store_true')
    parser.add_argument('--repair', action='store_true', help='Refresh multipass previews and retry effect-only models')
    parser.add_argument('--models', nargs='+', help='Refresh only named models')
    args = parser.parse_args()
    library = Library(LIB)
    names = sorted(set(GAMEPLAY.values())) if args.gameplay_only else sorted(library.models)
    if args.models:
        names = sorted(set(args.models))
    if args.repair:
        previous = json.loads((LIB / 'catalog.json').read_text())
        names = sorted(set(GAMEPLAY.values()) | {row['name'] for row in previous['models']
            if row['status'] == 'unconverted' or 'Additional material passes retained in source' in row.get('warnings', [])})
    objects = {}
    for obj in library.manifest['objects']:
        for model in obj['models']:
            objects.setdefault(model.lower(), set()).add(obj['name'])
    catalog = []
    mapping_path = ROOT / 'assets/generals/source.json'
    mappings = json.loads(mapping_path.read_text()) if mapping_path.exists() else {}
    mappings = {key: value for key, value in mappings.items() if GAMEPLAY.get(key) not in names}
    for number, name in enumerate(names, 1):
        source = library.models[name]
        row = dict(name=name, type=source.get('type', 'unparsed'),
                   edition=source['edition'], source=source['path'],
                   objects=sorted(objects.get(name, [])), status='source', preview='')
        if row['type'] == 'model':
            try:
                try:
                    primitives, warnings, _ = convert(library, name)
                except ValueError as error:
                    if 'No visible geometry' not in str(error):
                        raise
                    primitives, warnings, _ = convert(library, name, keep_effects=True)
                    warnings.append('Effect geometry preview; original additive rendering is not simulated')
                positions = np.concatenate([part['vertices'] for part in primitives])
                if not np.isfinite(positions).all():
                    raise ValueError('Non-finite geometry')
                low, high = positions.min(axis=0), positions.max(axis=0)
                destination = LIB / 'data/previews' / (name + '.glb')
                digest = write_glb(primitives, destination)
                row.update(status='preview', preview=str(destination.relative_to(ROOT)).replace('\\', '/'),
                           bounds_min=low.tolist(), bounds_max=high.tolist(),
                           triangles=sum(len(part['vertices']) // 3 for part in primitives),
                           warnings=warnings, sha256=digest)
                for key, mapped_name in GAMEPLAY.items():
                    if mapped_name != name:
                        continue
                    target = ROOT / 'assets/generals' / (key + '.glb')
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(destination.read_bytes())
                    # Keep textures embedded and prevent thousands of extracted PNG files.
                    import_path = Path(str(target) + '.import')
                    if not import_path.exists():
                        import_path.write_text(
                        '[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n'
                        '[deps]\nsource_file="res://' + str(target.relative_to(ROOT)).replace('\\', '/') + '"\n\n'
                        '[params]\ngltf/embedded_image_handling=3\ngltf/naming_version=2\n'
                        'gltf/texture_map_mode=1\n', encoding='utf-8')
                    mappings[key] = dict(model=name, source=source['path'], source_sha256=source['sha256'],
                                         output_sha256=digest, bounds_min=low.tolist(), bounds_max=high.tolist(),
                                         warnings=warnings)
            except Exception as error:
                row.update(status='unconverted', warnings=[f'{type(error).__name__}: {error}'])
                if 'No visible geometry' in str(error):
                    row.update(status='source', warnings=['Source contains no standalone visible geometry'])
                if name in GAMEPLAY.values():
                    print(traceback.format_exc(), flush=True)
        catalog.append(row)
        if number % 100 == 0 or args.gameplay_only:
            print(f'IMPORT {number}/{len(names)} {name} {row["status"]}', flush=True)
    result = dict(scope='Static previews; all original files are retained in data/source',
                  source_counts=library.manifest['counts'],
                  counts=dict(Counter(row['status'] for row in catalog)), models=catalog)
    if (args.gameplay_only or args.repair or args.models) and (LIB / 'catalog.json').exists():
        previous = json.loads((LIB / 'catalog.json').read_text())
        updates = {row['name']: row for row in catalog}
        previous['models'] = [updates.get(row['name'], row) for row in previous['models']]
        previous['counts'] = dict(Counter(row['status'] for row in previous['models']))
        (LIB / 'catalog.json').write_text(json.dumps(previous, separators=(',', ':')) + '\n', encoding='utf-8')
    else:
        (LIB / 'catalog.json').write_text(json.dumps(result, separators=(',', ':')) + '\n', encoding='utf-8')
    (ROOT / 'assets/generals/source.json').write_text(json.dumps(mappings, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result['counts']), flush=True)
    missing = sorted(set(GAMEPLAY) - set(mappings))
    if missing:
        raise SystemExit('Gameplay conversions missing: ' + ', '.join(missing))


if __name__ == '__main__':
    main()
