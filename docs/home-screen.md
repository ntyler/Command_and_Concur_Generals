# Home screen

Normal project launch and F5 open `scenes/home_screen.tscn`. The local Windows
shortcut `Launch Game.cmd` starts the installed Godot 4.7.2 directly in the
project, without opening the editor. F6 continues to run an explicitly opened
scene; selecting a script or a file without opening a scene does not define one.

Play Fortified Assault opens the existing playable match. Object Library opens
the imported catalog with Dozer, Battleship and Carrier shortcuts. Quit exits.
The home screen uses an isolated 3D preview, with visible keyboard focus and
viewport layouts checked at 1280×720 and 1920×1080.

During a running match, Esc opens Pause and Return to Home asks for confirmation.
Escape cancels that confirmation; Resume preserves the same match. Confirming
Home uses the existing scene teardown, clears tree Pause and releases navigation
and listeners. A finished match has a direct Home button. The library has a Home
button and Escape returns home instead of quitting the application.

Original skirmish setup, manual map building and AI-prompt map generation are
visibly unavailable. No generator, login, original-game AI execution or playable
naval implementation is claimed by this screen. The existing prototype rules,
automatic harvesting, historical movement exceptions and unfinished
Tempest/superweapon functionality retain their separate scope.

## Validation

The source baseline is `ad098e7`, following the original rules/AI foundation.
All validation below uses the repository's external `tools/run-godot.ps1`
watchdog. The fresh-copy matrix used `tools/validate-m8.ps1`.

| Final phase / suite | Headless checks | Graphical checks |
| --- | ---: | ---: |
| `home-screen-final-03` / `home_screen_checks` | 49 | 54 |
| `home-screen-final-03` / `home_quit_checks` | 2 | 2 |
| `home-screen-final-03` / `pause_checks` | 135 | 139 |
| `home-screen-final-03` / `pause_quit_checks` | 8 | 8 |
| `local-library-04` / `home_screen_checks --home-library-preview` | 50 | 56 |
| Total executed checks | 244 | 259 |

These are **10 successful test executions / 503 passing checks**, including
repeated coverage; they are not 503 distinct assertions. Both fresh-copy and
local editor imports also pass separately. All exits are 0, with no assertion
failures, native errors/warnings, hangs or unresolved shutdown resources.

The matrix preserves 505 source hashes, all matching at completion. Its only
later runtime difference is the home preview helicopter position, adjusted to
keep it within the view. The subsequent local headless and graphical executions
test that final source with the actual copied Dozer preview. All recorded files
match at local-run completion; Godot additionally generates three new UID files
for the home script and its two tests. Later changes are documentation and the
Windows launch shortcut, not gameplay. Five pre-existing untracked UID files
from the preceding rules/AI work are preserved separately.

The new tests drive actual viewport mouse and keyboard input through Home,
library, Pause confirmation/cancellation, replay and the result screen. They
check match and navigation release, cleared callbacks/listeners and awake tree
state after leaving Pause. A fixture applies lethal HQ damage solely to reach
the result menu; this is not an earned combat victory or human playtest. Existing
Pause tests retain the real deferred gate-callback teardown regression.

Evidence is saved in:

- `validation-output/m8/home-screen-final-03/`: eight execution logs, import,
  results, source hashes, five home/navigation PNGs and four existing Pause PNGs.
- `validation-output/home-screen/local-library-04/`: local import, two execution
  logs, source hashes and six final PNGs: Home at 720p/1080p, Dozer library with
  Home, Pause, Home confirmation and result return.
- `validation-output/home-screen/summary.json`: aggregate and final source audit.

The earlier `home-screen-focused-01` phase is retained with its test-script
WeakRef inference parse errors, before assertions ran. Explicit types correct
that fixture. `home-screen-focused-02` subsequently passed all four executions
and 105 checks; its counts are not added to the final 503. Later edits improved
button focus contrast, preview framing and checked the library panel bounds.

Documentation local links, heading references, whitespace and `git diff --check`
pass. **Home startup and navigation are VERIFIED within the scope above.**
The complete original-rules/AI game port and map-authoring features remain
**NOT VERIFIED** and unfinished.
