"""Copy all model/texture/object-definition entries from two local game installs.

Usage: python tools/copy-generals-assets.py GENERALS_DIRECTORY ZERO_HOUR_DIRECTORY
Archives are read only. Every archive version is retained and SHA-256 verified.
The large, reproducible source library stays local; gameplay assets are separate.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/generals_library"


def index(path):
    with path.open("rb") as stream:
        header = stream.read(16)
        if header[:4] not in (b"BIGF", b"BIG4"):
            raise ValueError(f"Unsupported archive: {path}")
        for _ in range(struct.unpack_from(">I", header, 8)[0]):
            offset, size = struct.unpack(">II", stream.read(8))
            name = bytearray()
            while (byte := stream.read(1)) != b"\0":
                if not byte:
                    raise ValueError(f"Truncated index: {path}")
                name.extend(byte)
            relative = name.decode("ascii").replace("\\", "/").lower()
            safe = PurePosixPath(relative)
            if safe.is_absolute() or ".." in safe.parts or ":" in relative:
                raise ValueError(f"Unsafe archive entry: {relative}")
            yield relative, offset, size


def chunks(data):
    offset = 0
    while offset < len(data):
        kind, flags = struct.unpack_from("<II", data, offset)
        offset += 8
        size = flags & 0x7FFFFFFF
        if offset + size > len(data):
            raise ValueError("Truncated W3D chunk")
        yield kind, data[offset:offset + size]
        offset += size


def model_info(data):
    top = list(chunks(data))
    counts = Counter(kind for kind, _ in top)
    result = dict(meshes=counts[0], hierarchy=bool(counts[0x100]),
                  animation=bool(counts[0x200] or counts[0x280]), hlod=bool(counts[0x700]))
    if counts[0x700]:
        header = dict(chunks(next(body for kind, body in top if kind == 0x700)))[0x701]
        result['skeleton'] = header[24:40].split(b'\0')[0].decode('ascii').lower()
    result['type'] = 'model' if counts[0] else 'animation' if result['animation'] else 'hierarchy' if result['hierarchy'] else 'effect/data'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('generals', type=Path)
    parser.add_argument('zero_hour', type=Path)
    args = parser.parse_args()
    data_root = LIBRARY / 'data'
    data_root.mkdir(parents=True, exist_ok=True)
    (data_root / '.gdignore').write_text('')
    rows, objects = [], []
    for edition, directory in [('generals', args.generals), ('zero_hour', args.zero_hour)]:
        for archive in sorted(directory.glob('*.big')):
            entries = list(index(archive))
            with archive.open('rb') as stream:
                for name, offset, size in entries:
                    suffix = PurePosixPath(name).suffix
                    if suffix not in ('.w3d', '.dds', '.tga') and not name.startswith('data/ini/object/'):
                        continue
                    stream.seek(offset)
                    body = stream.read(size)
                    if len(body) != size:
                        raise ValueError(f'Truncated asset: {name}')
                    relative = f'source/{edition}/{archive.stem.lower()}/{name}'
                    target = data_root / relative
                    digest = hashlib.sha256(body).hexdigest()
                    if target.exists():
                        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                            raise ValueError(f'Refusing to overwrite different local asset: {target}')
                    else:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(body)
                    if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                        raise ValueError(f'Copy verification failed: {target}')
                    row = dict(edition=edition, archive=archive.name, entry=name,
                               path='data/' + relative, size=size, sha256=digest)
                    if suffix == '.w3d':
                        try:
                            row.update(model_info(body))
                        except (ValueError, KeyError, struct.error, UnicodeError) as error:
                            row.update(type='unparsed', diagnostic=str(error))
                    rows.append(row)
                    if suffix == '.ini':
                        text = body.decode('cp1252').replace('\r', '')
                        blocks = list(re.finditer(r'(?im)^(?:Object|ChildObject)\s+(\S+)', text))
                        for i, match in enumerate(blocks):
                            block = text[match.end():blocks[i+1].start() if i+1 < len(blocks) else len(text)]
                            models = sorted(set(re.findall(r'(?im)^\s*Model\s*=\s*(\S+)', block)))
                            side = re.search(r'(?im)^\s*Side\s*=\s*(\S+)', block)
                            objects.append(dict(name=match[1], edition=edition, source=row['path'],
                                                side=side[1] if side else '', models=models))
            print(f'COPIED {edition}/{archive.name}', flush=True)
    manifest = dict(entries=rows, objects=objects,
                    counts=dict(files=len(rows), bytes=sum(row['size'] for row in rows),
                                extensions=dict(Counter(PurePosixPath(row['entry']).suffix for row in rows)),
                                model_types=dict(Counter(row.get('type') for row in rows if row['entry'].endswith('.w3d'))),
                                object_definitions=len(objects)))
    (data_root / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest['counts'], indent=2))


if __name__ == '__main__':
    main()
