"""Preserve and decode the loose original skirmish/multiplayer scripts."""
import argparse
import hashlib
import json
from pathlib import Path
from generals_script_data import decode, encode, inventory

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('generals', type=Path)
    parser.add_argument('zero_hour', type=Path)
    args = parser.parse_args()
    output = ROOT / 'assets/generals_rules'
    output.mkdir(parents=True, exist_ok=True)
    manifest = []
    for edition, install in [('generals', args.generals), ('zero_hour', args.zero_hour)]:
        for source in sorted((install / 'Data/Scripts').glob('*')):
            if source.suffix.lower() not in ('.scb', '.ini'):
                continue
            body = source.read_bytes()
            digest = hashlib.sha256(body).hexdigest()
            target = ROOT / 'assets/generals_library/data/source' / edition / 'loose/data/scripts' / source.name.lower()
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() and target.read_bytes() != body:
                raise ValueError(f'Refusing to overwrite different source: {target}')
            target.write_bytes(body)
            if target.read_bytes() != body:
                raise ValueError(f'Copy mismatch: {target}')
            entry = dict(edition=edition, source=str(source), copy=target.relative_to(ROOT).as_posix(), bytes=len(body), sha256=digest)
            if source.suffix.lower() == '.scb':
                document = decode(body)
                if encode(document) != body:
                    raise ValueError(f'Decoded SCB does not round-trip byte-for-byte: {source}')
                entry['inventory'] = inventory(document)
                payload = dict(format_version=1, interpretation='Serialized original data; legacy healing and execution are separate.', source_sha256=digest, **document)
                destination = output / f'{edition}_{source.stem.lower()}.json'
                destination.write_text(json.dumps(payload, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
                entry['decoded'] = destination.relative_to(ROOT).as_posix()
                entry['decoded_sha256'] = hashlib.sha256(destination.read_bytes()).hexdigest()
                entry['round_trip_exact'] = True
            manifest.append(entry)
            print(json.dumps(entry), flush=True)
    if sum('decoded' in row for row in manifest) != 4:
        raise ValueError('Expected both original skirmish and multiplayer programs for both editions')
    (output / 'ai-source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
