# Milestone 1 validation record

Date: 2026-09-06. Engine: **`4.7.2.stable.official.ed1daf0bf`**, standard Windows x86_64, Compatibility renderer.

## Preflight

- Baseline commit: `ca1f791` (`Initial commit`). Working tree was clean.
- Read the existing README, LICENSE, and `.gitattributes`; those were the only repository files outside Git metadata.
- No applicable `AGENTS.md` existed in the repository or its directory ancestors.
- No `project.godot`, main scene, camera/input/unit/navigation/selection code, or test framework existed. The baseline had no project to launch; there were no pre-existing Godot parser/runtime errors to classify.
- Godot was absent from PATH and normal installation locations. The user confirmed it needed installation and authorized proceeding. This was the only environment blocker, and it was resolved.
- Installed the official stable portable build under `C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2`. The executable's `--version` reported `4.7.2.stable.official.ed1daf0bf`.
- Archive SHA-256 matched the official GitHub release metadata: `731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953`. Source: [official Godot 4.7.2 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable). No third-party assets or project dependencies were downloaded.
- Preserved LICENSE and `.gitattributes`. README was intentionally replaced with project documentation. No commits were made.

## Architecture and behavior

Five focused typed GDScript classes implement the milestone. `TestField` builds a fixed map and wires signals, `RTSCamera` handles camera input and motion, `SelectionController` owns membership and selection gestures, `RTSUnit` handles navigation and visual feedback, and `GroupDestinations` generates and assigns slots. There are no autoloads, global managers, third-party dependencies, or speculative later-system classes.

The main scene contains 12 original primitive units at repeatable 4 × 3 starting positions, three box obstacles and visible map borders. The same obstacle rectangles build the physical scene and holes in the navigation mesh. Camera pan uses exact exponential integration with delta time. Selection raycasts run on physics ticks; drag selection projects only friendly unit anchors. Group moves use distinct navigable slots with at least 1.5 spacing, stable unit-ID ordering, distance-based assignment and improving pair swaps. New orders replace targets atomically after reachability checks.

The navigation implementation follows the built-in [NavigationAgent workflow](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html) and [navigation mesh construction APIs](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html). Units collide with obstacles and can pass one another; solid crowd handling is deliberately outside this controls milestone.

## Commands and evidence

Commands below ran from `D:\GitHub\Command_and_Concur_Generals`. `$godot` was the absolute console executable path documented in the README. Log paths are local ignored output, so another checkout should regenerate them using the same commands.

| Command | Final result | Exit |
| --- | --- | --- |
| `& $godot --version` | `4.7.2.stable.official.ed1daf0bf` | 0 |
| `& $godot --headless --path . --editor --import --log-file validation-output/import.log` | Imports and registers scripts; no parser/resource errors | 0 |
| `& $godot --headless --path . --quit-after 120 --log-file validation-output/launch-headless.log` | Main scene emits `FIELD_READY: 12 friendly units, 3 obstacles`; no runtime errors | 0 |
| `& $godot --headless --path . --fixed-fps 60 --script res://tests/milestone_checks.gd --log-file validation-output/headless.log` | `MILESTONE_CHECKS: 126 checks, 0 failures` | 0 |
| `& $godot --path . --fixed-fps 60 --script res://tests/milestone_checks.gd --log-file validation-output/graphical.log` | `MILESTONE_CHECKS: 130 checks, 0 failures`; four captured frames | 0 |
| `& $godot --path . --quit-after 120 --log-file validation-output/launch-graphical.log` | Direct graphical main-scene launch; no runtime errors | 0 |
| `git diff --check` and whitespace review of new files | No whitespace errors or unrelated modifications | 0 |

Graphics ran on **NVIDIA GeForce RTX 2070 SUPER**, OpenGL 3.3 Compatibility, driver 610.88. The runner captured `initial.png`, `selected.png`, `moving.png`, and `arrived.png`. The initial and selected frames show all 12 units, map boundaries, obstacles and controls. Movement frames show separate amber destination markers and mint selection rings.

During implementation, the test script initially had an indentation parse error (exit 1), which was corrected. Camera left/right action constants were corrected during review. Early movement tests detected corner clearance and crowd deadlocks (exit 1); movement now constrains steps to the navigation mesh and omits solid unit crowd avoidance. The final checks above supersede those development failures. These were task-introduced problems, not pre-existing repository problems.

## Acceptance checklist

PASS below means verified by automated engine input/physics checks, rendered-frame inspection, or repository review as specified. Input playback uses the real scene and Godot event dispatch; it is **not a claim of manual hardware interaction**.

| # | Acceptance item | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Project imports without new parser/resource errors | PASS | Final headless editor import and script execution, exit 0; clean logs |
| 2 | Main test scene launches | PASS | Direct headless and graphical launch; `FIELD_READY` output |
| 3 | At least 12 friendly units visible | PASS | IDs/ownership/view projection asserted for every unit; initial screenshot inspected |
| 4 | WASD and arrows move camera | PASS | All eight physical key events injected through Input; correct movement direction asserted |
| 5 | Edge scrolling moves camera | PASS | Right-edge pointer event produces camera displacement |
| 6 | Mouse wheel zoom stays within limits | PASS | Wheel input and both minimum/maximum clamps asserted |
| 7 | Camera remains inside map bounds | PASS | Ground focus clamped to x ±29, z ±23 in both directions; elevated view offset documented |
| 8 | Unit click selects only that unit | PASS | Physics picking plus replacement-selection assertions |
| 9 | Empty-ground click clears selection | PASS | Terrain raycast with selected units clears the collection |
| 10 | Drag selects multiple units in all directions | PASS | Four opposite-corner drags each select all 12; immediate rectangle visibility/hiding asserted |
| 11 | Shift-click and Shift-drag modify selection correctly | PASS | Add/toggle/preserve-outside/repeated-add tests; no duplicate references |
| 12 | Selected units display clear indicators | PASS | Ring visibility asserted for all 12 and selected screenshot inspected |
| 13 | Terrain right-click moves selected units | PASS | Real ground raycast dispatches 12 move orders; travel and arrivals asserted |
| 14 | Units navigate around test obstacles | PASS | Two full-group routes with per-physics-frame obstacle clearance checks |
| 15 | Multiple selected units get distinct destinations | PASS | Count, spacing and navigability checked in open ground, map corner, obstacle center and far outside map |
| 16 | Replacement orders interrupt previous movement | PASS | New terrain click while moving changes assigned destination and completes |
| 17 | Tested path has no obvious runtime errors | PASS | Final headless/graphical logs contain no parser, missing-resource, invalid-node or runtime errors |
| 18 | Later game systems were not implemented | PASS | Complete source/diff scope review; only controls, test field and minimal feedback |
| 19 | Controls and validation documented | PASS | README controls, run commands, architecture, limitations and this report |
| 20 | No unrelated work overwritten | PASS | Clean baseline; only planned new files and README changed; LICENSE and Git attributes preserved |

Additional checks cover the exact six-pixel drag threshold, Escape/focus-loss cancellation, release over consuming UI, UI wheel/pan suppression, non-friendly rejection, safe freed-reference pruning, deterministic slot generation, safe invalid commands, exact arrival tolerance and three seconds of no post-arrival movement. Camera integration agrees at 30, 60 and 144 FPS within 0.001 world units. The first route's 12 arrival distances were approximately 0.149–0.219 units against a 0.22 stopping distance.

## Known limitations and next milestone

- Unit-to-unit collision/avoidance is disabled. Units may overlap temporarily while following crossing routes; each has a separate final destination. Solid obstacles remain impassable.
- The test map is flat and static. Slope handling, dynamic navigation edits, large crowds and disconnected regions have not been exercised as gameplay scenes.
- Physical keyboard/mouse feel, high-DPI/multi-monitor edge behavior and other desktop platforms are NOT VERIFIED. Graphical event playback and captured-frame inspection were performed on this Windows environment.
- Assignment reduces straight-line travel and crossings but is not a global path-cost solver. Debug destination markers intentionally remain visible after arrival.
- Camera bounds apply to its ground focus, the conventional RTS rig anchor. The elevated perspective camera itself sits behind that anchor.

Recommended next milestone: a second terrain layout and movement stress tests, followed by robust crowd handling, before introducing other gameplay systems. No later milestone work was started.
