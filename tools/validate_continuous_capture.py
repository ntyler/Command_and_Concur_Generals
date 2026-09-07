#!/usr/bin/env python3
"""Independently validate the test-only continuous, all-participant JSONL contract.

This program performs no engine or navigation queries. Synthetic captures exercise
the serialization contract only; parked wiring cannot establish route behavior.
Exit 0: valid capture and gameplay checks pass; 1: fully recorded gameplay failure;
2: incomplete, internally contradictory, or otherwise invalid evidence.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys


MODES = ("synthetic_contract", "parked_wiring", "route")
IDS = list(range(1, 51))
MAX_BYTES = 1073741824
MAX_FRAMES = 10000
STATE_FIELDS = {
    "id", "position", "assigned", "next_waypoint", "order", "moving", "state",
    "radius", "priority", "requested_velocity", "last_movement_frame", "elapsed",
    "stall", "recoveries", "recovery_target", "movement_speed", "avoidance_enabled",
}
VECTOR_FIELDS = ("position", "assigned", "next_waypoint", "requested_velocity", "recovery_target")


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def integer(value):
    # Godot's JSON parser stores numbers as doubles; a retained integer can
    # consequently serialize as 1.0. Accept exact safe integral values, never
    # booleans, fractions, nonfinite values, or ambiguous large float IDs.
    return (isinstance(value, int) and not isinstance(value, bool)) or (
        isinstance(value, float) and math.isfinite(value)
        and value.is_integer() and abs(value) <= 9007199254740991
    )


def vector(value):
    return isinstance(value, list) and len(value) == 3 and all(finite(v) for v in value)


def complete_ids(values):
    return len(values) == 50 and all(integer(v) and 1 <= v <= 50 for v in values) and sorted(values) == IDS


def distance(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def length(a):
    return math.sqrt(sum(x * x for x in a))


def same_vector(a, b, tolerance=0.000005):
    return vector(a) and vector(b) and distance(a, b) <= tolerance


def sha(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-fA-F]{64}", value) is not None


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key: " + key)
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError("nonfinite JSON constant: " + value)


class Validator:
    def __init__(self, expected_mode, expected_source_sha256, expected_fixture_sha256):
        self.expected_mode = expected_mode
        self.expected_source = expected_source_sha256
        self.expected_fixture = expected_fixture_sha256
        self.errors = []
        self.failures = []
        self.error_count = 0
        self.failure_count = 0
        self.stats = {"records": 0, "frames": 0, "physics_frames": 0, "callbacks": 0,
                      "movement_calls": 0, "movement_advances": 0, "actual_step_excesses": 0,
                      "max_actual_step": 0.0, "max_sampled_step": 0.0,
                      "accepted_commands": 0, "settling_frames": 0}
        self.header = None
        self.footer = None
        self.last_frame = None
        self.previous = {}
        self.instances = {}
        self.callback_sequences = {}
        self.commands = {}
        self.last_command_order = {}
        self.arrival_anchor = None
        self.arrival_frame = None
        self.final_rows = {}
        self.delegate_totals = {unit_id: {"callbacks": 0, "direct": 0} for unit_id in IDS}
        self.admissions = set()
        self.motion_receipts = set()
        self.initial_event = None

    def issue(self, code, detail, gameplay=False):
        destination = self.failures if gameplay else self.errors
        if gameplay:
            self.failure_count += 1
        else:
            self.error_count += 1
        if len(destination) < 100:
            destination.append({"code": code, "detail": detail})

    def require(self, condition, code, detail, gameplay=False):
        if not condition:
            self.issue(code, detail, gameplay)
        return bool(condition)

    def state(self, state, unit_id, where):
        if not self.require(isinstance(state, dict), "state_schema", where):
            return False
        valid = self.require(STATE_FIELDS <= state.keys(), "state_fields", where)
        valid &= self.require(state.get("id") == unit_id, "state_identity", where)
        for name in VECTOR_FIELDS:
            valid &= self.require(vector(state.get(name)), "state_vector", where + ":" + name)
        for name in ("order", "last_movement_frame", "recoveries"):
            valid &= self.require(integer(state.get(name)), "state_integer", where + ":" + name)
        for name in ("radius", "priority", "elapsed", "stall", "movement_speed"):
            valid &= self.require(finite(state.get(name)), "state_number", where + ":" + name)
        for name in ("moving", "avoidance_enabled"):
            valid &= self.require(isinstance(state.get(name), bool), "state_boolean", where + ":" + name)
        if "velocity" in state:
            valid &= self.require(vector(state["velocity"]), "state_vector", where + ":velocity")
        if valid:
            self.require(state["movement_speed"] > 0 and state["radius"] > 0,
                         "movement_parameters", where)
        return bool(valid)

    def header_record(self, record):
        self.header = record
        self.require(record.get("schema_version") == 1, "schema_version", "requires version 1")
        mode = record.get("mode")
        self.require(mode in MODES, "mode", str(mode))
        self.require(self.expected_mode is None or mode == self.expected_mode,
                     "expected_mode", "capture=" + str(mode) + ", expected=" + str(self.expected_mode))
        expected_ids = record.get("expected_ids")
        self.require(isinstance(expected_ids, list) and complete_ids(expected_ids),
                     "population", "expected IDs must be exactly 1..50")
        self.require(record.get("physics_ticks") == 60, "physics_rate", "requires original 60 ticks")
        self.require(integer(record.get("start_frame")), "start_frame", "missing initial onset frame")
        self.require(isinstance(record.get("run_id"), str) and bool(record["run_id"]), "run_id", "missing")
        for name, expected in (("source_sha256", self.expected_source), ("fixture_sha256", self.expected_fixture)):
            value = record.get(name)
            self.require(sha(value), "source_identity", name)
            self.require(expected is None or value == expected, "expected_identity", name)
        limits = record.get("limits", {})
        self.require(isinstance(limits, dict) and limits.get("max_frames") == MAX_FRAMES
                     and limits.get("max_bytes") == MAX_BYTES, "limits", "original hard limits required")

    def event_record(self, event):
        frame = event.get("frame")
        self.require(integer(frame), "event_frame", str(event.get("seq")))
        self.require(isinstance(event.get("kind"), str), "event_kind", str(event.get("seq")))
        unit_id = event.get("id")
        self.require(unit_id is None or (integer(unit_id) and unit_id in IDS), "event_identity", str(event.get("seq")))
        if event.get("kind") == "continuous_initial_state":
            self.require(self.initial_event is None and self.stats["accepted_commands"] == 0,
                         "initial_event_order", "initial observation must precede public commands")
            self.initial_event = event
            details = event.get("details", {})
            states = details.get("states", []) if isinstance(details, dict) else []
            self.require(isinstance(details, dict) and details.get("before_commands") is True
                         and frame == self.header.get("start_frame") and isinstance(states, list)
                         and len(states) == 50
                         and complete_ids([s.get("id") for s in states if isinstance(s, dict)]),
                         "initial_event_coverage", "immutable all50 onset before commands required")
            if isinstance(states, list):
                for observed in states:
                    if not isinstance(observed, dict):
                        continue
                    self.state(observed, observed.get("id"), "initial event")
                    self.require(observed.get("order") == 0 and observed.get("moving") is False,
                                 "initial_event_state", str(observed.get("id")))
            return
        if event.get("kind") != "move_command_result":
            return
        details = event.get("details")
        if not self.require(isinstance(details, dict) and isinstance(details.get("accepted"), bool),
                            "command_schema", str(event.get("seq"))):
            return
        if not details["accepted"]:
            return
        after = event.get("after")
        if not self.require(unit_id in IDS and isinstance(after, dict)
                            and integer(after.get("order")) and vector(after.get("assigned"))
                            and vector(details.get("requested_destination")),
                            "accepted_command_schema", str(event.get("seq"))):
            return
        order = after["order"]
        self.require(order == self.last_command_order.get(unit_id, 0) + 1,
                     "accepted_command_order", "unit " + str(unit_id), gameplay=True)
        self.require(same_vector(after["assigned"], details["requested_destination"]),
                     "accepted_goal_changed", "unit " + str(unit_id), gameplay=True)
        self.commands.setdefault(unit_id, []).append((frame, order, after["assigned"]))
        self.last_command_order[unit_id] = order
        self.stats["accepted_commands"] += 1

    def delegate(self, record, frame, unit_id, speed, direct=False):
        where = "frame %s unit %s" % (frame, unit_id)
        if not self.require(isinstance(record, dict), "delegate_schema", where):
            return 0
        self.require(record.get("kind") == ("direct_movement_call" if direct else "avoidance_callback"),
                     "delegate_kind", where)
        self.require(record.get("absolute_frame") == frame, "delegate_frame", where)
        self.require(record.get("delegation_returned") is True and record.get("instance_survived") is True,
                     "pending_delegate", where)
        for name in ("before", "after"):
            motion = record.get(name)
            valid_motion = isinstance(motion, dict)
            if valid_motion:
                valid_motion &= all(vector(motion.get(key)) for key in ("position", "requested_velocity", "agent_target"))
                valid_motion &= all(integer(motion.get(key)) for key in ("order_version", "submitted_order", "movement_frame"))
                valid_motion &= all(isinstance(motion.get(key), bool) for key in
                                    ("moving", "crowd_enabled", "avoidance_enabled", "navigation_suspended"))
                valid_motion &= finite(motion.get("radius"))
            self.require(valid_motion, "delegate_state", where + ":" + name)
        if not direct:
            sequence = record.get("observer_local_callback_sequence")
            expected = self.callback_sequences.get(unit_id, 0) + 1
            if unit_id not in self.callback_sequences and self.header.get("mode") == "synthetic_contract":
                expected = sequence
            self.require(integer(sequence) and sequence == expected, "callback_sequence",
                         where + " expected " + str(expected) + " actual " + str(sequence))
            if integer(sequence):
                self.callback_sequences[unit_id] = sequence
            self.require(vector(record.get("callback_input")), "callback_input", where)
            self.stats["callbacks"] += 1
            self.delegate_totals[unit_id]["callbacks"] += 1
        else:
            self.require(record.get("observer_local_callback_sequence") is None
                         and record.get("callback_input") is None, "direct_context", where)
            self.delegate_totals[unit_id]["direct"] += 1
        admission = record.get("admission_sequence")
        if self.header.get("mode") != "synthetic_contract" or admission is not None:
            self.require(integer(admission) and admission > 0 and admission not in self.admissions,
                         "duplicate_or_missing_admission", where)
            if integer(admission):
                self.admissions.add(admission)
        if self.header.get("mode") != "synthetic_contract":
            receipt = record.get("motion_receipt_sequence")
            completion = record.get("completion_sequence")
            self.require(integer(receipt) and receipt > 0 and receipt not in self.motion_receipts,
                         "duplicate_or_missing_motion_receipt", where)
            if integer(receipt):
                self.motion_receipts.add(receipt)
            self.require(integer(completion) and integer(admission) and completion > admission,
                         "delegate_observation_order", where)
        calls = record.get("movement_calls")
        if not self.require(isinstance(calls, list), "movement_calls", where):
            return 0
        if direct:
            self.require(len(calls) == 1, "direct_call_count", where)
        advances = 0
        prior_end = None
        prior_stamp = None
        call_signatures = set()
        for call in calls:
            self.stats["movement_calls"] += 1
            if not self.require(isinstance(call, dict), "movement_schema", where):
                continue
            signature = json.dumps(call, sort_keys=True)
            self.require(signature not in call_signatures, "duplicate_movement_receipt", where)
            call_signatures.add(signature)
            self.require(call.get("absolute_frame") == frame, "movement_frame", where)
            self.require(call.get("delegation_returned") is True and call.get("instance_survived") is True,
                         "pending_movement", where)
            valid = all(vector(call.get(name)) for name in
                        ("desired_input", "position_before", "position_after", "displacement"))
            valid &= finite(call.get("delta")) and call.get("delta", 0) > 0
            valid &= all(integer(call.get(name)) for name in ("movement_frame_before", "movement_frame_after"))
            self.require(valid, "movement_fields", where)
            contacts = call.get("contacts")
            self.require(isinstance(contacts, list), "movement_contacts", where)
            if isinstance(contacts, list):
                for contact in contacts:
                    self.require(isinstance(contact, dict) and "collider_instance_id" in contact
                                 and all(vector(contact.get(key)) for key in ("point", "normal", "travel", "remainder")),
                                 "contact_schema", where)
            if not valid:
                continue
            before, after = call["position_before"], call["position_after"]
            stamp_before, stamp_after = call["movement_frame_before"], call["movement_frame_after"]
            changed = stamp_after != stamp_before
            self.require(isinstance(call.get("movement_frame_changed"), bool)
                         and call["movement_frame_changed"] == changed,
                         "contradictory_stamp", where)
            self.require(not changed or stamp_after == frame, "contradictory_stamp", where)
            self.require(same_vector(call["displacement"], [b - a for a, b in zip(before, after)]),
                         "contradictory_displacement", where)
            if prior_end is not None:
                self.require(same_vector(before, prior_end) and stamp_before == prior_stamp,
                             "movement_chain", where)
            prior_end, prior_stamp = after, stamp_after
            actual = distance(before, after)
            self.stats["max_actual_step"] = max(self.stats["max_actual_step"], actual)
            self.require(abs(call["delta"] - 1.0 / 60) <= 0.00000001,
                         "movement_delta", where, gameplay=True)
            self.require(length(call["desired_input"]) <= speed + 0.00001,
                         "movement_input_speed", where, gameplay=True)
            if actual > speed / 60 + 0.001:
                self.stats["actual_step_excesses"] += 1
                self.issue("actual_step_excess", where + " distance=" + repr(actual), gameplay=True)
            self.require(changed or actual <= 0.000005,
                         "movement_without_stamp", where, gameplay=True)
            advances += int(changed)
        if calls and isinstance(record.get("before"), dict) and isinstance(record.get("after"), dict):
            self.require(isinstance(calls[0], dict) and isinstance(calls[-1], dict)
                         and same_vector(record["before"].get("position"), calls[0].get("position_before"))
                         and same_vector(record["after"].get("position"), calls[-1].get("position_after")),
                         "delegate_movement_link", where)
            if isinstance(calls[0], dict) and isinstance(calls[-1], dict):
                self.require(record["before"].get("movement_frame") == calls[0].get("movement_frame_before")
                             and record["after"].get("movement_frame") == calls[-1].get("movement_frame_after"),
                             "delegate_stamp_link", where)
        self.stats["movement_advances"] += advances
        return advances

    def frame_record(self, record):
        frame = record.get("frame")
        if not self.require(integer(frame), "frame_number", str(record.get("seq"))):
            return
        initial = self.stats["frames"] == 0
        self.require(record.get("phase") == ("initial" if initial else "physics"),
                     "frame_phase", str(frame))
        expected_frame = self.header.get("start_frame") if initial else self.last_frame + 1
        self.require(frame == expected_frame, "frame_gap_or_onset", "expected %s actual %s" % (expected_frame, frame))
        self.last_frame = frame
        self.stats["frames"] += 1
        self.stats["physics_frames"] += int(not initial)
        self.require(self.stats["frames"] <= MAX_FRAMES, "frame_limit", str(frame))
        rows = record.get("rows")
        if not self.require(isinstance(rows, list), "rows_schema", str(frame)):
            return
        row_ids = [row.get("id") if isinstance(row, dict) else None for row in rows]
        self.require(complete_ids(row_ids),
                     "participant_coverage", str(frame))
        current = {}
        current_instances = []
        for row in rows:
            if not isinstance(row, dict) or row.get("id") not in IDS:
                continue
            unit_id = row["id"]
            where = "frame %s unit %s" % (frame, unit_id)
            instance = row.get("instance_id")
            self.require(integer(instance) and instance > 0, "instance_identity", where)
            if unit_id in self.instances:
                self.require(instance == self.instances[unit_id], "instance_replaced", where)
            self.instances[unit_id] = instance
            current_instances.append(instance)
            self.require(isinstance(row.get("physics_observed"), bool)
                         and (initial or row["physics_observed"] is True), "missing_physics", where)
            state = row.get("state")
            if not self.state(state, unit_id, where):
                continue
            current[unit_id] = state
            if initial and self.header.get("mode") != "synthetic_contract":
                self.require(state["order"] == 0 and not state["moving"], "capture_started_late", where)
            if not initial and unit_id in self.previous:
                sampled = distance(self.previous[unit_id]["position"], state["position"])
                self.stats["max_sampled_step"] = max(self.stats["max_sampled_step"], sampled)
                self.require(sampled <= state["movement_speed"] / 60 + 0.001,
                             "sampled_step_excess", where, gameplay=True)
            if self.header.get("mode") != "synthetic_contract":
                commands = [command for command in self.commands.get(unit_id, []) if command[0] <= frame]
                authority = commands[-1] if commands else None
                # An initial/pre-field row can precede a later public command at
                # this same engine frame. That allowance never carries forward.
                options = [authority]
                if authority and authority[0] == frame:
                    options.append(commands[-2] if len(commands) > 1 else None)
                previous = self.previous.get(unit_id, state)
                authorized = any((state["order"] == item[1] and same_vector(state["assigned"], item[2]))
                                 if item else (state["order"] == 0 and same_vector(state["assigned"], previous["assigned"]))
                                 for item in options)
                self.require(authorized, "accepted_goal_authority", where, gameplay=True)
            if self.header.get("mode") == "parked_wiring":
                self.require(state["order"] <= 1, "cluster_command_in_parked_mode", where, gameplay=True)
            advances = 0
            for key, direct in (("callbacks", False), ("direct_movements", True)):
                delegates = row.get(key)
                if not self.require(isinstance(delegates, list), "delegate_rows", where + ":" + key):
                    continue
                signatures = set()
                for delegate in delegates:
                    signature = json.dumps(delegate, sort_keys=True)
                    self.require(signature not in signatures, "duplicate_delegate_receipt", where)
                    signatures.add(signature)
                    advances += self.delegate(delegate, frame, unit_id, state["movement_speed"], direct)
            self.require(advances <= 1, "multiple_movement_advances", where, gameplay=True)
            if self.header.get("mode") == "parked_wiring":
                self.require(advances == 0, "movement_in_parked_mode", where, gameplay=True)
        self.require(len(set(current_instances)) == len(current_instances), "duplicate_instance", str(frame))
        self.previous = current
        self.final_rows = current
        if self.header.get("mode") == "route" and len(current) == 50:
            arrived = all(state["order"] == 2 and not state["moving"] and state["state"] in (0, "ARRIVED")
                          and distance(state["position"], state["assigned"]) <= 0.23
                          for state in current.values())
            if arrived and self.arrival_anchor is None:
                self.arrival_anchor = {unit_id: state["position"] for unit_id, state in current.items()}
                self.arrival_frame = frame
            if self.arrival_anchor is not None and frame > self.arrival_frame:
                self.stats["settling_frames"] += 1
                self.require(arrived, "settling_state", str(frame), gameplay=True)
                for unit_id, state in current.items():
                    self.require(distance(state["position"], self.arrival_anchor[unit_id]) < 0.001,
                                 "settling_displacement", "frame %s unit %s" % (frame, unit_id), gameplay=True)
                    self.require(vector(state.get("velocity")), "settling_velocity_missing", str(unit_id))
                    if vector(state.get("velocity")):
                        self.require(length(state["velocity"]) < 0.001, "settling_velocity", str(unit_id), gameplay=True)
                separation = min(distance(current[a]["position"], current[b]["position"])
                                 for a in IDS for b in IDS if a < b)
                self.require(separation > 0.6, "settling_separation", str(frame), gameplay=True)

    def finish(self):
        self.require(self.header is not None, "missing_header", "capture")
        self.require(self.footer is not None, "missing_footer", "capture is truncated or unfinished")
        self.require(self.stats["frames"] > 0, "missing_initial", "no all-participant initial row")
        if self.footer:
            footer = self.footer
            self.require(footer.get("complete") is True and footer.get("errors") == []
                         and footer.get("pending_delegates") == 0, "incomplete_footer", "capture")
            self.require(footer.get("last_frame") == self.last_frame and footer.get("frames") == self.stats["frames"],
                         "footer_coverage", "frame count or last frame mismatch")
            self.require(isinstance(footer.get("reason"), str), "footer_reason", "missing")
            totals = footer.get("totals")
            self.require(isinstance(totals, list) and len(totals) == 50
                         and complete_ids([t.get("id") for t in totals if isinstance(t, dict)]),
                         "footer_totals_coverage", "requires all 50 independent admission/completion totals")
            if isinstance(totals, list):
                for total in totals:
                    if not isinstance(total, dict) or total.get("id") not in self.delegate_totals:
                        continue
                    unit_id = total["id"]
                    for kind in ("callbacks", "direct"):
                        expected = self.delegate_totals[unit_id][kind]
                        self.require(total.get(kind + "_received") == expected
                                     and total.get(kind + "_completed") == expected,
                                     "footer_delegate_totals", "unit %s %s serialized %s" % (unit_id, kind, expected))
            mode = self.header.get("mode") if self.header else None
            if mode != "synthetic_contract":
                self.require(self.motion_receipts == set(range(1, len(self.motion_receipts) + 1)),
                             "motion_receipt_gap", "all live motion receipts must be retained once")
                self.require(self.initial_event is not None, "missing_initial_event",
                             "live capture requires immutable all50 onset before public commands")
            if mode == "parked_wiring":
                self.require(footer.get("cluster_commands") == 0 and footer.get("precluster_teardown") is True,
                             "precluster_boundary", "parked harness did not prove teardown before dispatch")
            if mode == "route":
                self.require(footer.get("route_finished") is True, "route_unfinished", "route result", gameplay=True)
                self.require(all(any(c[1] == 2 for c in self.commands.get(unit_id, [])) for unit_id in IDS),
                             "cluster_public_commands", "requires accepted second command for all 50", gameplay=True)
                self.require(self.arrival_anchor is not None and self.stats["settling_frames"] >= 180,
                             "arrival_and_180_tick_settling", "insufficient complete post-arrival frames", gameplay=True)
                gameplay = footer.get("gameplay")
                self.require(isinstance(gameplay, dict) and integer(gameplay.get("checks"))
                             and gameplay.get("checks", 0) > 0 and integer(gameplay.get("failures")),
                             "inherited_gameplay_receipt", "missing original suite totals")
                if isinstance(gameplay, dict) and integer(gameplay.get("failures")):
                    self.require(gameplay["failures"] == 0, "inherited_gameplay_failures",
                                 str(gameplay["failures"]), gameplay=True)


def validate_capture(path, expected_mode=None, expected_source_sha256=None, expected_fixture_sha256=None):
    validator = Validator(expected_mode, expected_source_sha256, expected_fixture_sha256)
    hasher = hashlib.sha256()
    file_hasher = hashlib.sha256()
    byte_count = 0
    try:
        with Path(path).open("rb") as stream:
            for number, raw in enumerate(stream):
                byte_count += len(raw)
                file_hasher.update(raw)
                if byte_count > MAX_BYTES:
                    validator.issue("byte_limit", str(byte_count))
                    break
                validator.require(raw.endswith(b"\n"), "truncated_line", str(number + 1))
                try:
                    record = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object,
                                        parse_constant=reject_constant)
                except (ValueError, UnicodeError) as error:
                    validator.issue("invalid_json", "line %s: %s" % (number + 1, error))
                    hasher.update(raw)
                    continue
                if not isinstance(record, dict):
                    validator.issue("record_schema", str(number + 1))
                    hasher.update(raw)
                    continue
                validator.require(integer(record.get("seq")) and record.get("seq") == number,
                                  "record_sequence", str(number + 1))
                validator.stats["records"] += 1
                if validator.footer is not None:
                    validator.issue("records_after_footer", str(number + 1))
                    continue
                kind = record.get("type")
                if kind == "footer":
                    validator.footer = record
                    validator.require(sha(record.get("sha256")) and record["sha256"] == hasher.hexdigest(),
                                      "artifact_digest", "preceding exact bytes do not match footer")
                    continue
                hasher.update(raw)
                if number == 0:
                    if validator.require(kind == "header", "missing_header", "first record must be header"):
                        validator.header_record(record)
                    continue
                if validator.header is None:
                    continue
                if kind == "event":
                    validator.event_record(record)
                elif kind == "frame":
                    validator.frame_record(record)
                else:
                    validator.issue("record_type", str(kind))
    except (OSError, TypeError, KeyError, ValueError, OverflowError) as error:
        validator.issue("validation_exception", type(error).__name__ + ": " + str(error))
    try:
        validator.finish()
    except (TypeError, KeyError, ValueError, OverflowError) as error:
        validator.issue("footer_validation_exception", type(error).__name__ + ": " + str(error))
    capture_valid = validator.error_count == 0
    gameplay_pass = validator.failure_count == 0
    return {"schema_version": 1, "path": str(Path(path).resolve()),
            "mode": validator.header.get("mode") if validator.header else None,
            "capture_valid": capture_valid, "gameplay_pass": gameplay_pass,
            "exit_code": 2 if not capture_valid else (0 if gameplay_pass else 1),
            "capture_error_count": validator.error_count, "gameplay_failure_count": validator.failure_count,
            "capture_errors": validator.errors, "gameplay_failures": validator.failures,
            "stats": validator.stats, "bytes": byte_count, "file_sha256": file_hasher.hexdigest(),
            "prefix_sha256": hasher.hexdigest(),
            "evidence_scope": "synthetic contract only" if validator.header and validator.header.get("mode") == "synthetic_contract"
            else "parked wiring only; no route mechanism execution" if validator.header and validator.header.get("mode") == "parked_wiring"
            else "recorded route; no additional native queries or inferred branch labels",
            "same_frame_command_policy": "a pre-field row may precede a later accepted command only at that same engine frame",
            "limits": {"max_frames": MAX_FRAMES, "max_bytes": MAX_BYTES},
            "diagnostic_lists_truncated": validator.error_count > 100 or validator.failure_count > 100}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--expected-mode", choices=MODES, required=True)
    parser.add_argument("--expected-source-sha256")
    parser.add_argument("--expected-fixture-sha256")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = validate_capture(args.capture, args.expected_mode, args.expected_source_sha256, args.expected_fixture_sha256)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return report["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
