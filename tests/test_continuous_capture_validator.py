"""Offline adversarial tests. Fixtures are explicitly synthetic, never live units."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("continuous_validator", ROOT / "tools/validate_continuous_capture.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


def state(unit_id, order=0):
    point = [float(unit_id * 2), 0.0, 0.0]
    return {"id": unit_id, "position": point, "assigned": point[:], "next_waypoint": point[:],
            "order": order, "moving": False, "state": 0, "radius": 0.35, "priority": 0.5,
            "requested_velocity": [0.0, 0.0, 0.0], "last_movement_frame": -1,
            "elapsed": 0.0, "stall": 0.0, "recoveries": 0, "recovery_target": point[:],
            "movement_speed": 5.0, "avoidance_enabled": True, "velocity": [0.0, 0.0, 0.0]}


def frame(number, initial=False, order=0):
    return {"type": "frame", "frame": number, "phase": "initial" if initial else "physics",
            "route": "synthetic data only", "rows": [
                {"id": unit_id, "instance_id": unit_id + 1000, "state": state(unit_id, order),
                 "physics_observed": not initial, "callbacks": [], "direct_movements": []}
                for unit_id in range(1, 51)]}


def records(mode="synthetic_contract", count=2):
    header = {"type": "header", "schema_version": 1, "mode": mode, "run_id": "offline-contract",
              "source_sha256": "a" * 64, "fixture_sha256": "b" * 64,
              "expected_ids": list(range(1, 51)), "physics_ticks": 60, "start_frame": 10,
              "limits": {"max_frames": 10000, "max_bytes": 1073741824}}
    return [header] + [frame(10 + index, index == 0) for index in range(count)]


def callback(number=11, sequence=1, step=0.05, stamp_before=-1, admission=1, start=2.0):
    before = [start, 0.0, 0.0]
    after = [start + step, 0.0, 0.0]
    motion = {"absolute_frame": number, "desired_input": [3.0, 0.0, 0.0], "delta": 1 / 60,
              "position_before": before, "position_after": after,
              "movement_frame_before": stamp_before, "movement_frame_after": number,
              "movement_frame_changed": stamp_before != number, "displacement": [step, 0.0, 0.0],
              "contacts": [], "delegation_returned": True, "instance_survived": True}
    before_state = {"position": before, "requested_velocity": [3.0, 0.0, 0.0], "agent_target": [4.0, 0.0, 0.0],
                    "order_version": 2, "submitted_order": 2, "movement_frame": stamp_before,
                    "moving": True, "crowd_enabled": True, "avoidance_enabled": True,
                    "navigation_suspended": False, "radius": 0.35}
    after_state = copy.deepcopy(before_state)
    after_state.update(position=after, movement_frame=number)
    return {"kind": "avoidance_callback", "absolute_frame": number,
            "observer_local_callback_sequence": sequence, "admission_sequence": admission,
            "motion_receipt_sequence": admission, "completion_sequence": admission + 1,
            "callback_input": [3.0, 0.0, 0.0], "before": before_state, "after": after_state,
            "movement_calls": [motion], "delegation_returned": True, "instance_survived": True}


def encode(items, footer_overrides=None):
    items = copy.deepcopy(items)
    if items and items[0].get("mode") != "synthetic_contract":
        items.insert(1, {"type": "event", "frame": items[0]["start_frame"], "kind": "continuous_initial_state",
                         "id": None, "details": {"states": [state(i) for i in range(1, 51)], "before_commands": True}})
    chunks = []
    frames = [item for item in items if item.get("type") == "frame"]
    totals = []
    for unit_id in range(1, 51):
        callbacks = sum(len(row["callbacks"]) for item in frames for row in item["rows"] if row["id"] == unit_id)
        direct = sum(len(row["direct_movements"]) for item in frames for row in item["rows"] if row["id"] == unit_id)
        totals.append({"id": unit_id, "callbacks_received": callbacks, "callbacks_completed": callbacks,
                       "direct_received": direct, "direct_completed": direct})
    for sequence, item in enumerate(items):
        value = copy.deepcopy(item)
        value["seq"] = sequence
        chunks.append((json.dumps(value, separators=(",", ":")) + "\n").encode())
    footer = {"type": "footer", "seq": len(items), "last_frame": frames[-1]["frame"] if frames else None,
              "frames": len(frames), "complete": True, "errors": [], "pending_delegates": 0,
              "reason": "offline synthetic validation", "cluster_commands": 0, "precluster_teardown": True,
              "route_finished": True, "gameplay": {"checks": 32, "failures": 0}, "totals": totals,
              "sha256": hashlib.sha256(b"".join(chunks)).hexdigest()}
    footer.update(footer_overrides or {})
    chunks.append((json.dumps(footer, separators=(",", ":")) + "\n").encode())
    return b"".join(chunks)


class ContinuousCaptureValidatorTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="continuous-offline-")
        self.path = Path(self.directory.name) / "capture.jsonl"

    def tearDown(self):
        self.directory.cleanup()

    def validate(self, items=None, raw=None, mode="synthetic_contract", footer=None, **kwargs):
        self.path.write_bytes(raw if raw is not None else encode(items if items is not None else records(), footer))
        return VALIDATOR.validate_capture(self.path, expected_mode=mode, **kwargs)

    def invalid(self, result, code):
        self.assertEqual(result["exit_code"], 2, result)
        self.assertIn(code, {error["code"] for error in result["capture_errors"]}, result)

    def gameplay_failure(self, result, code):
        self.assertTrue(result["capture_valid"], result)
        self.assertEqual(result["exit_code"], 1, result)
        self.assertIn(code, {error["code"] for error in result["gameplay_failures"]}, result)

    def test_synthetic_positive(self):
        result = self.validate()
        self.assertEqual(result["exit_code"], 0, result)
        self.assertEqual(result["stats"]["frames"], 2)
        self.assertEqual(result["evidence_scope"], "synthetic contract only")

    def test_godot_integral_double_json_values_are_valid(self):
        def doubles(value):
            if isinstance(value, bool):
                return value
            if isinstance(value, int):
                return float(value)
            if isinstance(value, list):
                return [doubles(item) for item in value]
            if isinstance(value, dict):
                return {key: doubles(item) for key, item in value.items()}
            return value
        items = records()
        items[2]["rows"][0]["callbacks"] = [callback()]
        self.assertEqual(self.validate(doubles(items))["exit_code"], 0)

    def test_fractional_integer_field_rejected(self):
        items = records()
        items[2]["rows"][0]["state"]["order"] = 1.5
        self.invalid(self.validate(items), "state_integer")

    def test_boolean_integer_field_rejected(self):
        items = records()
        items[2]["rows"][0]["state"]["order"] = True
        self.invalid(self.validate(items), "state_integer")

    def test_unsafe_float_identity_rejected(self):
        items = records()
        items[2]["rows"][0]["instance_id"] = 9007199254740992.0
        self.invalid(self.validate(items), "instance_identity")

    def test_parked_positive(self):
        self.assertEqual(self.validate(records("parked_wiring"), mode="parked_wiring")["exit_code"], 0)

    def test_actual_callback_and_bounded_movement(self):
        items = records()
        items[2]["rows"][0]["callbacks"] = [callback()]
        result = self.validate(items)
        self.assertEqual(result["exit_code"], 0, result)
        self.assertEqual(result["stats"]["movement_calls"], 1)

    def test_direct_movement_supported(self):
        items = records()
        direct = callback()
        direct.update(kind="direct_movement_call", observer_local_callback_sequence=None, callback_input=None)
        items[2]["rows"][0]["direct_movements"] = [direct]
        self.assertEqual(self.validate(items)["exit_code"], 0)

    def test_synthetic_retained_sequence_can_start_late(self):
        items = records(count=3)
        items[2]["rows"][0]["callbacks"] = [callback(sequence=654)]
        items[3]["rows"][0]["callbacks"] = [callback(number=12, sequence=655, admission=2)]
        self.assertEqual(self.validate(items)["exit_code"], 0)

    def test_live_callback_onset_must_begin_at_one(self):
        items = records("parked_wiring")
        items[2]["rows"][0]["callbacks"] = [callback(sequence=654, step=0)]
        self.invalid(self.validate(items, mode="parked_wiring"), "callback_sequence")

    def test_live_shared_observation_sequences_need_not_be_contiguous(self):
        items = records("parked_wiring")
        value = callback(step=0, stamp_before=11)
        value["admission_sequence"] = 250
        value["completion_sequence"] = 251
        items[2]["rows"][0]["callbacks"] = [value]
        self.assertEqual(self.validate(items, mode="parked_wiring")["exit_code"], 0)

    def test_missing_initial_rejected(self):
        items = records()
        del items[1]
        self.invalid(self.validate(items), "frame_phase")

    def test_wrong_start_frame_rejected(self):
        items = records()
        items[0]["start_frame"] = 9
        self.invalid(self.validate(items), "frame_gap_or_onset")

    def test_missing_middle_frame_rejected(self):
        items = records(count=3)
        del items[2]
        self.invalid(self.validate(items), "frame_gap_or_onset")

    def test_missing_participant_rejected(self):
        items = records()
        items[2]["rows"].pop()
        self.invalid(self.validate(items), "participant_coverage")

    def test_duplicate_participant_rejected(self):
        items = records()
        items[2]["rows"][49] = copy.deepcopy(items[2]["rows"][0])
        self.invalid(self.validate(items), "participant_coverage")

    def test_frozen_physics_rejected(self):
        items = records()
        items[2]["rows"][0]["physics_observed"] = False
        self.invalid(self.validate(items), "missing_physics")

    def test_instance_replaced_rejected(self):
        items = records()
        items[2]["rows"][0]["instance_id"] = 9001
        self.invalid(self.validate(items), "instance_replaced")

    def test_callback_receipt_duplicate_rejected(self):
        items = records()
        items[2]["rows"][0]["callbacks"] = [callback(), callback()]
        self.invalid(self.validate(items), "duplicate_delegate_receipt")

    def test_callback_sequence_gap_rejected(self):
        items = records(count=3)
        items[2]["rows"][0]["callbacks"] = [callback()]
        items[3]["rows"][0]["callbacks"] = [callback(number=12, sequence=3, admission=2)]
        self.invalid(self.validate(items), "callback_sequence")

    def test_pending_callback_rejected(self):
        items = records()
        value = callback()
        value["delegation_returned"] = False
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "pending_delegate")

    def test_pending_movement_rejected(self):
        items = records()
        value = callback()
        value["movement_calls"][0]["delegation_returned"] = False
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "pending_movement")

    def test_contradictory_stamp_rejected(self):
        items = records()
        value = callback()
        value["movement_calls"][0]["movement_frame_changed"] = False
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "contradictory_stamp")

    def test_wrong_movement_frame_rejected(self):
        items = records()
        value = callback()
        value["movement_calls"][0]["absolute_frame"] = 12
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "movement_frame")

    def test_duplicate_movement_receipt_rejected(self):
        items = records()
        value = callback()
        value["movement_calls"].append(copy.deepcopy(value["movement_calls"][0]))
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "duplicate_movement_receipt")

    def test_missing_raw_motion_state_rejected(self):
        items = records()
        value = callback()
        del value["before"]["movement_frame"]
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "delegate_state")

    def test_malformed_contact_rejected(self):
        items = records()
        value = callback()
        value["movement_calls"][0]["contacts"] = [{"collider_instance_id": 100}]
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "contact_schema")

    def test_raw_delegate_stamp_link_rejected(self):
        items = records()
        value = callback()
        value["after"]["movement_frame"] = 50
        items[2]["rows"][0]["callbacks"] = [value]
        self.invalid(self.validate(items), "delegate_stamp_link")

    def test_actual_excess_is_ordinary_gameplay_failure(self):
        items = records()
        items[2]["rows"][0]["callbacks"] = [callback(step=0.0844)]
        result = self.validate(items)
        self.gameplay_failure(result, "actual_step_excess")
        self.assertEqual(result["stats"]["actual_step_excesses"], 1)

    def test_original_step_threshold_unchanged(self):
        items = records()
        items[2]["rows"][0]["callbacks"] = [callback(step=0.0843)]
        self.assertEqual(self.validate(items)["exit_code"], 0)

    def test_multiple_actual_advances_are_gameplay_failure(self):
        items = records()
        # Distinct, fully returned receipts preserve an observed bad stamp reset.
        items[2]["rows"][0]["callbacks"] = [callback(), callback(sequence=2, admission=2, start=2.05)]
        self.gameplay_failure(self.validate(items), "multiple_movement_advances")

    def test_goal_replacement_is_gameplay_failure(self):
        items = records("parked_wiring")
        items[2]["rows"][0]["state"]["assigned"] = [100.0, 0.0, 0.0]
        self.gameplay_failure(self.validate(items, mode="parked_wiring"), "accepted_goal_authority")

    def test_public_accepted_command_authorizes_goal(self):
        items = records("parked_wiring")
        event = {"type": "event", "frame": 11, "kind": "move_command_result", "id": 1,
                 "details": {"accepted": True, "requested_destination": [2.1, 0.0, 0.0]},
                 "after": {"id": 1, "order": 1, "assigned": [2.1, 0.0, 0.0]}}
        items.insert(2, event)
        items[3]["rows"][0]["state"].update(order=1, assigned=[2.1, 0.0, 0.0])
        self.assertEqual(self.validate(items, mode="parked_wiring")["exit_code"], 0)

    def test_same_frame_precommand_observation_allowed_only_same_frame(self):
        items = records("parked_wiring", count=3)
        event = {"type": "event", "frame": 11, "kind": "move_command_result", "id": 1,
                 "details": {"accepted": True, "requested_destination": [2.1, 0.0, 0.0]},
                 "after": {"id": 1, "order": 1, "assigned": [2.1, 0.0, 0.0]}}
        items.insert(2, event)
        items[4]["rows"][0]["state"].update(order=1, assigned=[2.1, 0.0, 0.0])
        self.assertEqual(self.validate(items, mode="parked_wiring")["exit_code"], 0)
        items[4]["rows"][0]["state"]["order"] = 0
        self.gameplay_failure(self.validate(items, mode="parked_wiring"), "accepted_goal_authority")

    def test_missing_footer_and_truncation_rejected(self):
        raw = encode(records())
        self.invalid(self.validate(raw=raw[:raw.rfind(b"\n", 0, -1) + 1]), "missing_footer")
        self.invalid(self.validate(raw=raw[:-10]), "truncated_line")

    def test_corrupt_bytes_rejected(self):
        raw = encode(records()).replace(b"offline-contract", b"OFFLINE-contract")
        self.invalid(self.validate(raw=raw), "artifact_digest")

    def test_duplicate_json_key_rejected(self):
        raw = encode(records()).replace(b'"schema_version":1', b'"schema_version":1,"schema_version":1')
        self.invalid(self.validate(raw=raw), "invalid_json")

    def test_nonfinite_data_rejected(self):
        raw = encode(records()).replace(b'"elapsed":0.0', b'"elapsed":NaN', 1)
        self.invalid(self.validate(raw=raw), "invalid_json")

    def test_record_sequence_gap_rejected(self):
        raw = encode(records()).replace(b'"seq":1', b'"seq":9', 1)
        self.invalid(self.validate(raw=raw), "record_sequence")

    def test_wrong_expected_mode_rejected(self):
        self.invalid(self.validate(mode="route"), "expected_mode")

    def test_source_identity_checked(self):
        self.invalid(self.validate(expected_source_sha256="c" * 64), "expected_identity")

    def test_fixture_identity_checked(self):
        self.invalid(self.validate(expected_fixture_sha256="c" * 64), "expected_identity")

    def test_footer_incomplete_rejected(self):
        self.invalid(self.validate(footer={"complete": False}), "incomplete_footer")

    def test_footer_pending_rejected(self):
        self.invalid(self.validate(footer={"pending_delegates": 1}), "incomplete_footer")

    def test_footer_totals_mismatch_rejected(self):
        self.invalid(self.validate(footer={"totals": []}), "footer_totals_coverage")
        raw = encode(records()).replace(b'"callbacks_received":0', b'"callbacks_received":1', 1)
        self.invalid(self.validate(raw=raw), "footer_delegate_totals")

    def test_malformed_footer_types_return_invalid_instead_of_crashing(self):
        result = self.validate(footer={"totals": [{"id": []}]})
        self.invalid(result, "footer_totals_coverage")

    def test_parked_precluster_boundary_required(self):
        self.invalid(self.validate(records("parked_wiring"), mode="parked_wiring",
                                   footer={"precluster_teardown": False}), "precluster_boundary")

    def test_route_requires_real_commands_arrival_and_180_ticks(self):
        self.gameplay_failure(self.validate(records("route"), mode="route"), "cluster_public_commands")

    def test_route_complete_180_ticks_and_settling_failure(self):
        items = records("route", count=1)
        for order, at in ((1, 11), (2, 12)):
            for unit_id in range(1, 51):
                point = state(unit_id)["assigned"]
                items.append({"type": "event", "frame": at, "kind": "move_command_result", "id": unit_id,
                              "details": {"accepted": True, "requested_destination": point},
                              "after": {"id": unit_id, "order": order, "assigned": point}})
            items.append(frame(at, order=order))
        items.extend(frame(at, order=2) for at in range(13, 193))
        result = self.validate(items, mode="route")
        self.assertEqual(result["exit_code"], 0, result)
        self.assertEqual(result["stats"]["settling_frames"], 180)
        items[-1]["rows"][0]["state"]["velocity"] = [0.0011, 0.0, 0.0]
        self.gameplay_failure(self.validate(items, mode="route"), "settling_velocity")

    def test_cli_exit_contract_and_output(self):
        self.path.write_bytes(encode(records()))
        output = self.path.with_suffix(".result.json")
        run = subprocess.run([sys.executable, "-B", str(ROOT / "tools/validate_continuous_capture.py"),
                              str(self.path), "--expected-mode", "synthetic_contract", "--output", str(output)],
                             capture_output=True, text=True, check=False)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(json.loads(output.read_text())["exit_code"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
