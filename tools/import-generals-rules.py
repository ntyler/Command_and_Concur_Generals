"""Compile original rule syntax to an ordered, source-traceable Godot data tree.

Values stay in their source units. Repeated fields/modules are never flattened.
This is a syntax import, not an implementation of every engine field/behavior.
"""
import hashlib
import json
from pathlib import Path
import re
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'assets/generals_library'
FILES = {'aidata.ini', 'gamedata.ini', 'commandbutton.ini', 'commandset.ini',
         'playertemplate.ini', 'weapon.ini', 'armor.ini', 'locomotor.ini',
         'upgrade.ini', 'science.ini', 'rank.ini', 'multiplayer.ini', 'mouse.ini',
         'specialpower.ini', 'object.ini'}
ASSIGNMENT_BLOCKS = {'Behavior', 'Body', 'Draw', 'ClientUpdate', 'ClientBehavior', 'ConditionState', 'TransitionState'}
BARE_BLOCKS = {'DefaultConditionState', 'ConditionState', 'TransitionState', 'ArmorSet', 'WeaponSet',
    'UnitSpecificSounds', 'Prerequisites', 'Structure', 'Turret', 'AltTurret', 'SideInfo',
    'SkillSet1', 'SkillSet2', 'SkirmishBuildList', 'UnitSpecificFX', 'AttackAreaDecal',
    'TargetingReticleDecal', 'GridDecalTemplate', 'DeliveryDecal', 'InheritableModule',
    'OverrideableByLikeKind', 'AddModule', 'ReplaceModule'}


def source_lines(text):
    for line_number, raw in enumerate(text.splitlines(), 1):
        # The INI format uses ';' for comments. A quoted string may contain one.
        quoted, clean = False, []
        for char in raw:
            if char == '"':
                quoted = not quoted
            if char == ';' and not quoted:
                break
            clean.append(char)
        line = ''.join(clean).strip()
        if line:
            yield line_number, line


def parse(text):
    roots, stack = [], []
    for line_number, line in source_lines(text):
        if line.split()[0].casefold() == 'end':
            if not stack:
                raise ValueError(f'Unmatched End at line {line_number}')
            stack[-1]['end_line'] = line_number
            stack[-1]['end_value'] = line[len(line.split()[0]):].strip()
            stack.pop()
            continue
        match = re.match(r'([^\s=]+)(?:\s*=\s*(.*)|\s+(.*))?$', line)
        if not match:
            raise ValueError(f'Unrecognized syntax at line {line_number}: {line}')
        key = match[1]
        assignment = match[2] is not None
        value = (match[2] if assignment else match[3]) or ''
        block = not stack or key in ASSIGNMENT_BLOCKS or (not assignment and key in BARE_BLOCKS)
        row = dict(key=key, value=value, assignment=assignment, line=line_number)
        (stack[-1]['entries'] if stack else roots).append(row)
        if block:
            row['entries'] = []
            stack.append(row)
    if stack:
        raise ValueError(f'Unclosed block(s): {[(r["key"], r["line"]) for r in stack]}')
    return roots


def tokens_from_tree(rows):
    for row in rows:
        yield row['key'], row['value'], row['assignment']
        if 'entries' in row:
            yield from tokens_from_tree(row['entries'])
            yield 'End', row.get('end_value', ''), False


def main():
    manifest = json.loads((LIB / 'data/game-data-manifest.json').read_text())
    sources = [r for r in manifest['entries'] if r['edition'] == 'zero_hour' and r['archive'].lower() == 'inizh.big'
        and r['entry'].startswith('data/ini/') and (Path(r['entry']).name in FILES or r['entry'].startswith('data/ini/object/'))]
    # Retain declared layer order: defaults before corresponding active INI data.
    sources.sort(key=lambda r: ('/default/' not in r['entry'], r['entry']))
    documents, errors = [], []
    for source in sources:
        body = (LIB / source['path']).read_bytes()
        if hashlib.sha256(body).hexdigest() != source['sha256']:
            raise ValueError(f'Source hash mismatch: {source["path"]}')
        text = body.decode('cp1252')
        try:
            records = parse(text)
            recovered = '\n'.join(k + (' = ' if a else ' ') + v for k, v, a in tokens_from_tree(records))
            # Formatting/comments are excluded; token/field order and nesting survive.
            if list(tokens_from_tree(parse(recovered))) != list(tokens_from_tree(records)):
                raise ValueError('Syntax round-trip failed')
            documents.append(dict(path=source['path'], sha256=source['sha256'], records=records))
        except ValueError as error:
            errors.append(f'{source["entry"]}: {error}')
    if errors:
        raise SystemExit('\n'.join(errors))
    counts = dict(Counter(r['key'] for d in documents for r in d['records']))
    output = ROOT / 'assets/generals_rules/zero_hour_rules.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    result = dict(format_version=1, edition='zero_hour', interpretation='Ordered source syntax, values retain original units; engine semantics require explicit adapters.',
                  counts=counts, sources=documents)
    output.write_text(json.dumps(result, separators=(',', ':'), ensure_ascii=True) + '\n', encoding='utf-8')
    print(json.dumps(dict(files=len(documents), definitions=sum(counts.values()), counts=counts, output_sha256=hashlib.sha256(output.read_bytes()).hexdigest()), indent=2))


if __name__ == '__main__':
    main()
