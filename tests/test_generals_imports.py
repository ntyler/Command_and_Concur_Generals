"""Data fidelity boundaries independent of the Godot runtime checks."""
import importlib.util
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from generals_script_data import Reader, decode, encode, read_dict, write_dict, read_parameter, write_parameter

spec = importlib.util.spec_from_file_location('import_rules', ROOT / 'tools/import-generals-rules.py')
rules = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rules)


class RulesSyntaxChecks(unittest.TestCase):
    def test_repeated_fields_keep_order(self):
        data = rules.parse('AIData\nSideInfo America\nSkillSet1\nScience = A\nScience = B\nEnd\nEnd\nEnd')
        fields = data[0]['entries'][0]['entries'][0]['entries']
        self.assertEqual([r['value'] for r in fields], ['A', 'B'])

    def test_same_key_can_be_bone_field_or_ai_block(self):
        data = rules.parse('Object Tank\nDraw = W3DModelDraw Tag\nConditionState = NONE\nTurret = BONE\nEnd\nEnd\nBehavior = AIUpdateInterface AI\nTurret\nTurretTurnRate = 80\nEnd\nEnd\nEnd')
        draw, behavior = data[0]['entries']
        self.assertNotIn('entries', draw['entries'][0]['entries'][0])
        self.assertEqual(behavior['entries'][0]['entries'][0]['value'], '80')

    def test_optional_equals_is_retained(self):
        data = rules.parse('Object A\nDraw = W3DModelDraw Tag\nDefaultConditionState\nModel NAME\nEnd\nAliasConditionState NIGHT\nEnd\nEnd')
        draw = data[0]['entries'][0]
        self.assertEqual(draw['entries'][0]['entries'][0]['value'], 'NAME')
        self.assertFalse(draw['entries'][0]['entries'][0]['assignment'])
        self.assertNotIn('entries', draw['entries'][1])

    def test_quoted_semicolon_is_data(self):
        data = rules.parse('Object A\nDisplayName = "A;B" ;comment\nEnd')
        self.assertEqual(data[0]['entries'][0]['value'], '"A;B"')

    def test_original_end_suffix_is_preserved(self):
        data = rules.parse('Object A\nBehavior = X Tag\nEnd LegacyToken\nEnd')
        self.assertEqual(data[0]['entries'][0]['end_value'], 'LegacyToken')

    def test_unbalanced_input_fails(self):
        for text in ['End', 'Object A\nBuildCost = 1', 'Object A\nEnd\nEnd']:
            with self.assertRaises(ValueError):
                rules.parse(text)


class ScriptDataChecks(unittest.TestCase):
    def test_dictionary_types_round_trip(self):
        rows = [dict(key=(i+1)*256+i, name=str(i), type=i, value=v) for i,v in enumerate([1,-123,1.25,'ASCII','中文'])]
        encoded = write_dict(rows)
        decoded = read_dict(Reader(encoded), {i+1:str(i) for i in range(5)})
        self.assertEqual(decoded, rows)
        self.assertEqual(write_dict(decoded), encoded)

    def test_coordinate_parameter_has_original_xyz_order(self):
        raw = struct.pack('<ifff', 16, 1.25, -2.5, 300)
        decoded = read_parameter(Reader(raw))
        self.assertEqual(decoded['coordinate'], [1.25,-2.5,300])
        self.assertEqual(write_parameter(decoded), raw)

    def test_generic_parameter_keeps_all_three_representations(self):
        row = dict(type=15, integer=-1, real=1.5, text='AmericaVehicleDozer')
        self.assertEqual(read_parameter(Reader(write_parameter(row))), row)

    def test_bad_magic_and_truncation_fail(self):
        for data in [b'',b'NotACkMp',b'CkMp'+struct.pack('<I', 1),b'CkMp'+struct.pack('<I',0)+b'bad']:
            with self.assertRaises(ValueError):
                decode(data)

    def test_unknown_chunk_is_preserved_explicitly(self):
        raw = b'CkMp'+struct.pack('<I',1)+b'\x06Future'+struct.pack('<I',1)+struct.pack('<IHI',1,99,3)+b'abc'
        decoded = decode(raw)
        self.assertIn('opaque_base64', decoded['chunks'][0])
        self.assertEqual(encode(decoded), raw)

    def test_all_four_original_programs_reencode_exactly(self):
        manifest = json.loads((ROOT / 'assets/generals_rules/ai-source-manifest.json').read_text())
        checked = 0
        for source in manifest:
            if 'decoded' not in source:
                continue
            document = json.loads((ROOT / source['decoded']).read_text())
            original = (ROOT / source['copy']).read_bytes()
            self.assertEqual(encode(document), original, source['decoded'])
            checked += 1
        self.assertEqual(checked, 4)


if __name__ == '__main__':
    unittest.main()
