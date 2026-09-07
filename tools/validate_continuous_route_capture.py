#!/usr/bin/env python3
"""J evidence-storage profile for the unchanged continuous capture validator.

The independently loaded I contract changes only its evidence byte ceiling to
4 GiB. All schema, integrity, movement and gameplay predicates remain inherited.
This process performs no engine, navigation or physics query.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys


CONTRACT_PATH = Path(__file__).with_name('validate_continuous_capture.py')
SPEC = importlib.util.spec_from_file_location('_m501j_continuous_capture_contract', CONTRACT_PATH)
CONTRACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTRACT)
MAX_BYTES = 4294967296
# This module owns a fresh interpreter module namespace; the original I module
# and on-disk source keep their 1 GiB contract, including in the same process.
CONTRACT.MAX_BYTES = MAX_BYTES
MODES = CONTRACT.MODES


def validate_capture(path, expected_mode=None, expected_source_sha256=None, expected_fixture_sha256=None):
    result = CONTRACT.validate_capture(path, expected_mode, expected_source_sha256, expected_fixture_sha256)
    result['capture_profile'] = 'm501j_4gib_evidence_storage'
    result['inherited_validator_path'] = str(CONTRACT_PATH.resolve())
    result['inherited_validator_sha256'] = hashlib.sha256(CONTRACT_PATH.read_bytes()).hexdigest()
    result['profile_note'] = 'Only the evidence byte ceiling is 4 GiB. I source and all gameplay, integrity, frame and step predicates remain unchanged.'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--expected-mode', choices=MODES, required=True)
    parser.add_argument('--expected-source-sha256')
    parser.add_argument('--expected-fixture-sha256')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = validate_capture(args.capture, args.expected_mode, args.expected_source_sha256, args.expected_fixture_sha256)
    rendered = json.dumps(report, indent=2, sort_keys=True) + '\n'
    if args.output:
        args.output.write_text(rendered, encoding='utf-8')
    print(rendered, end='')
    return report['exit_code']


if __name__ == '__main__':
    sys.exit(main())
