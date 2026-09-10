"""Copy every BIG entry from the installed games, preserving archive versions.

The earlier art manifest/catalog remain unchanged. Rules, maps, window layouts,
audio and other runtime data are archived here as sources, not executed in Godot.
"""
import argparse
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / 'assets/generals_library'
spec = importlib.util.spec_from_file_location('generals_asset_copy', ROOT / 'tools/copy-generals-assets.py')
archive_reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive_reader)


def storage_name(name):
    # A patch archive contains a literal data/* marker. Keep its bytes under a
    # reversible filename on Windows and retain the original entry in the manifest.
    parts = []
    for part in name.split('/'):
        end = len(part.rstrip(' .'))
        encoded = ''.join(f'%{ord(char):02X}' if char in '<>:"|?*%' or ord(char) < 32 or index >= end
                          else char for index, char in enumerate(part))
        reserved = part.split('.')[0].upper()
        if reserved in {'CON', 'PRN', 'AUX', 'NUL'} or reserved in {f'{prefix}{i}' for prefix in ['COM', 'LPT'] for i in range(1, 10)}:
            encoded = f'%{ord(part[0]):02X}' + encoded[1:]
        parts.append(encoded)
    return '/'.join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('generals', type=Path)
    parser.add_argument('zero_hour', type=Path)
    args = parser.parse_args()
    for directory in [args.generals, args.zero_hour]:
        if not directory.is_dir() or not list(directory.glob('*.big')):
            parser.error(f'No BIG archives in {directory}')
    data_root = LIBRARY / 'data'
    data_root.mkdir(parents=True, exist_ok=True)
    (data_root / '.gdignore').touch()
    entries, archives = [], []
    copied, reused = 0, 0
    for edition, directory in [('generals', args.generals), ('zero_hour', args.zero_hour)]:
        for archive in sorted(directory.glob('*.big')):
            rows = list(archive_reader.index(archive))
            archives.append(dict(edition=edition, name=archive.name, entries=len(rows)))
            with archive.open('rb') as stream:
                for name, offset, size in rows:
                    target = data_root / 'source' / edition / archive.stem.lower() / storage_name(name)
                    stream.seek(offset)
                    body = stream.read(size)
                    if len(body) != size:
                        raise ValueError(f'Truncated archive entry: {archive}/{name}')
                    digest = hashlib.sha256(body).hexdigest()
                    if target.exists():
                        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                            raise ValueError(f'Refusing to overwrite different local data: {target}')
                        reused += 1
                    else:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(body)
                        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                            raise ValueError(f'Copy verification failed: {target}')
                        copied += 1
                    entries.append(dict(edition=edition, archive=archive.name, entry=name,
                        path=target.relative_to(LIBRARY).as_posix(), size=size, sha256=digest))
            print(f'VERIFIED {edition}/{archive.name}: {len(rows)} entries', flush=True)
    result = dict(scope='All BIG archive entries; external executables and loose installation files are not included.',
        counts=dict(entries=len(entries), bytes=sum(r['size'] for r in entries),
                    extensions=dict(Counter(Path(r['entry']).suffix for r in entries))),
        archives=archives, entries=entries)
    (data_root / 'game-data-manifest.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(**result['counts'], newly_copied=copied, reused_verified=reused), indent=2), flush=True)


if __name__ == '__main__':
    main()
