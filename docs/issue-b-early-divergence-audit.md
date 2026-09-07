# Milestone 5.0.1 — early-trajectory divergence audit, E/J

2026-09-07. **Outcome B: a production-version comparison is supportable; a unit 41 regression is not established.** E and J execute different movement rules and different observers. Their identical wiring does not isolate either difference. No implementation defect causing the early divergence was demonstrated. Unit 41 and original Issue B remain unresolved; Milestone 5 remains blocked.

This audit used retained source/evidence and small offline extractions. No applicable AGENTS.md was found in the workspace, retained source scopes or named ancestors. **Zero Godot executions and zero production/test/fixture changes.** Issue A and the verified projection correction remain unchanged, with no new runtime verification. Existing evidence and closed budgets were preserved; no archive, framework, dependency or commit was created.

## Comparability

E is `m501e-current-mechanism-headless-1`; J is `m501j-observe-1`, under `validation-output/`. E's invocation identifies its movement file and eight retained diagnostic files. Its `m501e-source-comparison.json` also identifies the production field, scene and project configuration. E movement is preserved in `D:/GitHub/Command_and_Concur_m501g_before_20260907T155955Z/scripts/rts_unit.gd`; E diagnostics are in `m501e-current-mechanism-headless-1-source/`. J's invocation/manifests identify `m501j-observe-1-source/`. Only relevant source copies were rechecked; historical artifacts were not rehashed wholesale.

Full movement SHA-256 identities:

- E: `9b26194e6a0ef505573b0f51a8a7cdb1c409fae24c9526ccae0284cef29bbe2b`.
- J/current: `1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4`.

Source line references below use the unchanged J/current copies. E's eight retained diagnostic files match their corresponding J copies, although J executes additional subclasses.

| Item | E identity/value | J identity/value | Comparison | Could influence before frame 233? | Supporting reference |
|---|---|---|---|---|---|
| Movement/projection | `9b26194e…`; closest-point endpoint | `1af671d1…`; bounded first navigable leg for enlarged projections | Different | Yes if a qualifying projection occurs; E's early calls are missing. No changed endpoint observed in J's early calls | Invocations; `m501g-production.patch`; `scripts/rts_unit.gd:395–419` |
| Initial/subsequent paths | Direct final-distance query, then advancing agent query | Same implementation | Identical code; initial agent-path equality unavailable | Yes; equal scalar lengths do not establish equal paths | `rts_unit.gd:192–227,320–341,474–481` |
| Avoidance submission/acceptance | Order/mode guards; once-per-frame application | Same implementation | Identical code; native inputs unavailable in E's early gap | Yes; inputs include evolving actor/neighbor state | `rts_unit.gd:332–349,395–400` |
| Recovery, parking, Issue A | Issue A guard and continuation already present | Same code and parameters | Identical | Parked parameters operate from startup; no changed recovery rule explains this comparison | `rts_unit.gd:304–329,424–440,484–596`; Issue A report |
| Creation, registration, geometry, public orders | TestField `11a30bf3…`; stress scene `8e017369…`; frozen 50-unit fixture | Same files, geometry and ordered goals | Identical intended setup | Relevant, but no changed source enumeration found | E source-comparison; J source manifest; byte-identical wiring `fcf629e7…`; `test_field.gd:40–55,85–93,113–124,289–331` |
| Factory/runner | `unit13_fixture_field`, `unit13_fixture_checks` | `continuous_capture_field`, `continuous_route_checks`; extra out-of-tree probe installation/preflight | Different | Additional work exists; no extra yield before cluster dispatch | Original runner `23–46,120–130`; J runner `49–77`; J field `7–18` |
| Observer/schema | Bounded JSON events/recent-motion archive, schema 1 | Continuous JSONL frames/events/completions, also schema 1 | Different, incompatible schemas | Work surrounds creation, commands, physics and callbacks; causal scheduling effect unproved | `full_sequence_recorder.gd:195–240,265–294`; `continuous_capture_recorder.gd:91–218`; `continuous_capture_probe.gd:4–17` |
| Project/engine/runtime state | Project `879f3421…`; engine `c8f0a6bc…`; setup map/region iterations 2/1 | Same project and engine; exact map/region iterations not serialized | Source/binary identical; some runtime identity unavailable | Readiness is established, identical native update state is not | Source manifests, invocations; E capture metadata; J runner `115–122` |
| Actual arguments | `--headless --path . --fixed-fps 60 --script res://tests/unit13_fixture_checks.gd` | Same headless/fixed60; absolute same project; `res://tests/continuous_route_checks.gd`, observe mode and prepared inputs | Different selected runner; same engine/project/display mode | Runner differences above; no engine-setting difference established | Both retained `-invocation.json` files contain complete argument arrays |

Both invocations identify engine SHA-256 `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`, version `4.7.2.stable.official.ed1daf0bf`. Project configuration contains no physics/navigation/threading overrides. E records 60 physics ticks, time scale 1, maximum 8 physics steps and jitter fix .5. J records fixed60 and actual 1/60 deltas but omits those full runtime metadata fields; identical project bytes are not a substitute for their observation.

## Early call order and alignment

```text
milestone_checks:11–18: deferred _run
  → runner creates field; TestField:48–55 builds navigation
  → sequential create → add_child → register (IDs 1–50)
      RTSUnit:124–138 creates/connects/enables NavigationAgent
  → five physics/process waits; assert map iteration > 0
  → public parking at frame 6 → three waits → 180 stationary samples
  → immediate synchronous public cluster dispatch at frame 189
      unit13_fixture_checks:120–130 enumerates field.units
      RTSUnit:200–227 resets order/velocities; assigns accepted goal
        → direct final-distance map_get_path → assigns agent target
  → RTSUnit physics:302–341
      map readiness → progress sample when due
      → get_next_path_position → bounded desired velocity → submit order/velocity
  → engine callback delivery → order/mode guard:347–349
  → movement-frame guard:395–400 → projection / J optional first leg
      → body velocity → move_and_slide:415–419
  → engine-owned agent position synchronization; exact server phase unknown
```

There is no explicit deferred call between a unit's accepted cluster command and the return of the synchronous dispatch loop. J's first frame-189 unit-physics observations are in ID order, observation sequences 28857–28955, followed by callbacks in ID order, admissions 28957–29055. E's equivalent first processing order is unavailable. Source assigns `agent.velocity` on submission but does not explicitly resubmit actual projected displacement or write the agent/server position after movement. Whether native synchronization changes the next solver inputs cannot be determined from this application source; this is not a diagnosed stale-input defect.

`move_to`'s direct map query returns a scalar remaining length. It does not supply the agent's cached path. All **50 initial scalar returns at frame 189 match**; unit 41 is E event **665** / J sequence **855**, length **30.3550658226013**. J's first 13-point cached path is **seq935/observation28938/frame189**, after delegated physics. E has no initial cached path. A later cached waypoint cannot fill that gap.

E contains **no events at frames190–232 and no retained movement records for any participant at frames189–233**. At the first common post-dispatch sample, frame233, **29/50 positions differ by more than 1e-6** (an analysis comparison only). Maximum difference is unit35, **.994937779**, E776/J1117. Unit41 is **.257367086** apart, E788/J1129, despite the same next waypoint. Unit49 is **.010301473** apart, E804/J1145, with the same next waypoint; unit44's position/request/scalar query agree, E794/J1135. This establishes distributed early differences, not their first instant or cause.

The frame233 query occurs before that frame's new waypoint acquisition/submission. Its `requested_velocity` is the existing agent property, not the frame233 callback input. E788's last-safe value is the actually received **frame232** input `(1.956852436,0,4.601166248)`, with movement stamp232, but its linked completed call is gone. E updates last-safe on admission; J updates it after completion. J **frame-record seq1045** links callback232's request `(.104747407,0,4.998902798)`, input `(.375593483,0,4.985872746)`, and completed move through observations35544/35545, stamp231→232, no contacts. Both last-safe ages are one frame at the query; equivalence of their generating submissions and native neighbor state is unavailable. These are not demonstrated unequal solver outputs for identical inputs. J's per-unit frame rows also are not a simultaneous native neighbor snapshot.

All **2,250 J movement calls at frames189–233** returned, advanced their stamps and had no contacts. Every endpoint matches an offline float32 calculation of `start + desired_input * delta`. Thus there is **no observable early endpoint correction in J**. This calculation neither observes internal projection/path returns nor proves the new branch never executed. E's missing calls prevent the same check. At E's later exact stall, the retained outward-input/zero-displacement mechanism remains separate: the added projection guard requires enlarged displacement, so it does not directly repair the zero-step case (source/offline reasoning, as documented in the reproduction-design report).

## Three explanations to distinguish

1. **Changed projection behavior contributes to the approach.** The exact changed branch is `rts_unit.gd:407–414`; it can affect any participant and then neighbors. J's early endpoint correspondence supplies no positive evidence for that contribution before233. E's early projections are missing. A comparison must locate an actual movement divergence at a qualifying projection after an equivalent observed prefix; otherwise it cannot attribute the early split to this rule.
2. **Initial native path or avoidance inputs differ despite matching setup.** The relevant boundaries are target assignment/query at `rts_unit.gd:216–221,332`, submission/callback at `340–349`, and post-movement native synchronization. Equal scalar lengths, stable ID enumeration and a nonzero map iteration do not identify the cached path, map update epoch or native solver inputs. E's missing first path/processing records and J's omitted map iterations prevent resolution. The first unequal requested path/input versus the first unequal callback would discriminate where the difference enters; native internals remain unknown.
3. **Observer work changes processing circumstances.** Extra script installation, per-frame cached reads/serialization and completion hooks are concrete source differences at the table's references. The call trace finds no added pre-dispatch yield or advancing diagnostic path query. No capture proves that this work changes solver timing or results. Holding the observer identical removes it as an experimental factor; generic nondeterminism, threading or RVO behavior is not a diagnosis.

## One proposed comparison; no stall fixture or execution authorized

The strongest controlled variable is the **known 11-line production projection difference**. Use one isolated E-production control and one isolated repaired-production experiment with identical continuous observer code, engine, fixture, creation order, public parking/cluster dispatch, parameters and acceptance assertions. Preserve the workspace repair. This is a new controlled comparison, not an exact replay of E; impose no neighbor schedule, private state, teleport, frozen mover or failed-stop initialization.

The discriminating observation is the **first unequal all-participant path/request/callback/movement sequence**, especially frames189–233. The hypothesis is that changed projected displacement sends participants onto different approaches. Support requires matching preceding observed inputs/state and a first differing completed movement consistent with E's enlarged projection and the repaired bounded rule. Earlier path/request/callback divergence contradicts a direct displacement-mediated explanation for that observed prefix. It leaves branch/query effects unresolved: the added native path query could execute without changing the endpoint. Equal early behavior followed by a later correction only establishes later influence. Different prefixes, ambiguous branch evidence or two arrivals are inconclusive about E's cause; stop without another batch. A pair alone cannot establish reliability or identical hidden engine state.

Existing continuous capture supplies the observable prefix and movement evidence: public inputs, cached paths, actual callbacks, completed moves, stamps and contacts. Internal branch results remain unavailable. **The existing J launcher cannot simply be rerun or pointed at E:** the runner, launcher and bridge pin the repaired SHA and the consumed J budget. Any future authorization must explicitly cover a narrow adaptation of those existing identity/preflight checks in isolated comparison copies, with identical observer behavior in both arms and fresh bounded case identities. It must preserve the closed J ledger and validate both source identities; no new recorder or framework is needed.

Proposed maximum: **one control plus one experiment (two moving executions total)**, gated by at most one parser-only and one precluster-only validation per arm; any failed gate stops, with no retries. Preserve all ordinary failures, including E-source step-size failures. Both runs retain the original route deadline, all-participant accepted-goal arrival, navigation/obstacle constraints, step bounds and full180-tick settling/separation checks. This comparison would establish a stall regression only if it actually captures unit41 reaching E's boundary beside already-parked49, outward avoidance with returned zero-displacement movement, and eight ineffective final-goal retries. It authorizes no repair and proves nothing about original Issue B's unit4.

**Required next authorization:** the narrowly adapted, validated two-arm comparison above. No execution or implementation follows this audit automatically. If its mechanism correspondence is absent, preserve that limitation and stop.

The small reproducible extraction and output are `validation-output/m501k-early-divergence.py` and `.json`; they reuse E/J captures and existing provenance. One exploratory inline extraction failed on `details["assignments"]` (exit1); the captured key is `commands`, and the corrected extraction succeeded. No missing original script/hash was fabricated.

Issue A and projection correction: **PRESERVED; no new runtime verification**. Unit41 boundary stall: **UNRESOLVED**. Original Issue B: **UNRESOLVED**. Milestone5: **STILL BLOCKED**.
