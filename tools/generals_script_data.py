"""Decode/re-encode original SCB script data without changing its decisions.

Format reference: EA GeneralsMD DataChunk.cpp, Scripts.cpp and SidesList.cpp.
This reads serialized data; it does not simulate the script engine or heal legacy
parameters. Unknown chunks remain explicit opaque records, never dropped.
"""
import base64
from collections import Counter
import struct


class Reader:
    def __init__(self, data):
        self.data, self.pos = data, 0

    def take(self, size):
        if size < 0 or self.pos + size > len(self.data):
            raise ValueError(f'Truncated SCB at {self.pos}: need {size} bytes')
        value = self.data[self.pos:self.pos + size]
        self.pos += size
        return value

    def number(self, code):
        return struct.unpack('<' + code, self.take(struct.calcsize('<' + code)))[0]

    def string(self, wide=False):
        size = self.number('H')
        return self.take(size * (2 if wide else 1)).decode('utf-16-le' if wide else 'latin1')

    def end(self):
        return self.pos == len(self.data)


def number(code, value):
    return struct.pack('<' + code, value)


def string(value, wide=False):
    data = value.encode('utf-16-le' if wide else 'latin1')
    return number('H', len(data) // (2 if wide else 1)) + data


def read_dict(reader, symbols):
    rows = []
    for _ in range(reader.number('H')):
        key = reader.number('I')
        kind = key & 255
        if kind == 0:
            value = reader.number('B')
        elif kind == 1:
            value = reader.number('i')
        elif kind == 2:
            value = reader.number('f')
        elif kind in (3, 4):
            value = reader.string(kind == 4)
        else:
            raise ValueError(f'Unsupported dictionary type {kind}')
        rows.append(dict(key=key, name=symbols[key >> 8], type=kind, value=value))
    return rows


def write_dict(rows):
    data = number('H', len(rows))
    for row in rows:
        kind, value = row['type'], row['value']
        data += number('I', row['key'])
        data += string(value, kind == 4) if kind in (3, 4) else number({0: 'B', 1: 'i', 2: 'f'}[kind], value)
    return data


def read_parameter(reader):
    kind = reader.number('i')
    if kind == 16:  # Parameter::COORD3D
        return dict(type=kind, coordinate=[reader.number('f') for _ in range(3)])
    return dict(type=kind, integer=reader.number('i'), real=reader.number('f'), text=reader.string())


def write_parameter(row):
    data = number('i', row['type'])
    if row['type'] == 16:
        return data + b''.join(number('f', v) for v in row['coordinate'])
    return data + number('i', row['integer']) + number('f', row['real']) + string(row['text'])


def read_chunks(reader, symbols):
    rows = []
    while not reader.end():
        key, version, size = reader.number('I'), reader.number('H'), reader.number('I')
        sub = Reader(reader.take(size))
        label = symbols[key]
        row = dict(id=key, label=label, version=version)
        if label in ('PlayerScriptsList', 'ScriptList', 'OrCondition'):
            row['children'] = read_chunks(sub, symbols)
        elif label == 'ScriptGroup':
            if version not in (1, 2):
                raise ValueError(f'Unsupported script-group version {version}')
            row.update(name=sub.string(), active=sub.number('B'))
            if version == 2:
                row['subroutine'] = sub.number('B')
            row['children'] = read_chunks(sub, symbols)
        elif label == 'Script':
            if version not in (1, 2):
                raise ValueError(f'Unsupported script version {version}')
            for field in ('name', 'comment', 'condition_comment', 'action_comment'):
                row[field] = sub.string()
            for field in ('active', 'one_shot', 'easy', 'normal', 'hard', 'subroutine'):
                row[field] = sub.number('B')
            if version >= 2:
                row['evaluation_interval_seconds'] = sub.number('i')
            row['children'] = read_chunks(sub, symbols)
        elif label in ('Condition', 'ScriptAction', 'ScriptActionFalse'):
            row['opcode'] = sub.number('i')
            named = version >= (4 if label == 'Condition' else 2)
            if named:
                row['name_key'] = sub.number('I')
                row['internal_name'] = symbols[row['name_key'] >> 8]
            count = sub.number('i')
            if not 0 <= count <= 64:
                raise ValueError(f'Invalid parameter count {count}')
            row['parameters'] = [read_parameter(sub) for _ in range(count)]
        elif label == 'ScriptsPlayers':
            if version not in (1, 2):
                raise ValueError(f'Unsupported players version {version}')
            if version >= 2:
                row['has_dicts'] = sub.number('i')
            row['players'] = []
            for _ in range(sub.number('i')):
                player = dict(name=sub.string())
                if row.get('has_dicts'):
                    player['properties'] = read_dict(sub, symbols)
                row['players'].append(player)
        elif label == 'ScriptTeams':
            row['teams'] = []
            while not sub.end():
                row['teams'].append(read_dict(sub, symbols))
        else:
            row['opaque_base64'] = base64.b64encode(sub.take(size)).decode('ascii')
        if not sub.end():
            raise ValueError(f'Unconsumed {label} bytes: {len(sub.data) - sub.pos}')
        rows.append(row)
    return rows


def write_chunks(rows):
    result = b''
    for row in rows:
        label = row['label']
        data = b''
        if label == 'ScriptGroup':
            data = string(row['name']) + number('B', row['active'])
            if row['version'] == 2:
                data += number('B', row['subroutine'])
        elif label == 'Script':
            data = b''.join(string(row[key]) for key in ('name', 'comment', 'condition_comment', 'action_comment'))
            data += bytes(row[key] for key in ('active', 'one_shot', 'easy', 'normal', 'hard', 'subroutine'))
            if row['version'] >= 2:
                data += number('i', row['evaluation_interval_seconds'])
        elif label in ('Condition', 'ScriptAction', 'ScriptActionFalse'):
            data = number('i', row['opcode'])
            if 'name_key' in row:
                data += number('I', row['name_key'])
            data += number('i', len(row['parameters']))
            data += b''.join(write_parameter(p) for p in row['parameters'])
        elif label == 'ScriptsPlayers':
            if row['version'] >= 2:
                data += number('i', row['has_dicts'])
            data += number('i', len(row['players']))
            for player in row['players']:
                data += string(player['name'])
                if row.get('has_dicts'):
                    data += write_dict(player['properties'])
        elif label == 'ScriptTeams':
            data = b''.join(write_dict(team) for team in row['teams'])
        if 'children' in row:
            data += write_chunks(row['children'])
        if 'opaque_base64' in row:
            data += base64.b64decode(row['opaque_base64'])
        result += number('I', row['id']) + number('H', row['version']) + number('I', len(data)) + data
    return result


def decode(data):
    reader = Reader(data)
    if reader.take(4) != b'CkMp':
        raise ValueError('Unsupported script container (expected uncompressed CkMp)')
    toc = []
    for _ in range(reader.number('I')):
        name = reader.take(reader.number('B')).decode('latin1')
        toc.append(dict(name=name, id=reader.number('I')))
    symbols = {row['id']: row['name'] for row in toc}
    if len(symbols) != len(toc):
        raise ValueError('Duplicate symbol identifier')
    return dict(symbols=toc, chunks=read_chunks(reader, symbols))


def encode(document):
    data = b'CkMp' + number('I', len(document['symbols']))
    for row in document['symbols']:
        value = row['name'].encode('latin1')
        data += number('B', len(value)) + value + number('I', row['id'])
    return data + write_chunks(document['chunks'])


def walk(rows):
    for row in rows:
        yield row
        yield from walk(row.get('children', []))


def inventory(document):
    chunks = list(walk(document['chunks']))
    return dict(chunks=dict(Counter(r['label'] for r in chunks)),
        conditions=dict(Counter(r.get('internal_name', str(r['opcode'])) for r in chunks if r['label'] == 'Condition')),
        actions=dict(Counter(r.get('internal_name', str(r['opcode'])) for r in chunks if r['label'] in ('ScriptAction', 'ScriptActionFalse'))),
        opaque_chunks=[r['label'] for r in chunks if 'opaque_base64' in r],
        teams=sum(len(r.get('teams', [])) for r in chunks),
        players=[p['name'] for r in chunks for p in r.get('players', [])])
