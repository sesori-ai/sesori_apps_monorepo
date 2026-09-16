# Step 5 — Connection overlay and sidebar recovery

## Delivered behavior

- Connection state floats over the routed main pane without changing its bounds.
  Shared grace/reconnect ownership stays in `ConnectionOverlayCubit`.
- Local desired Off suppresses bridge-offline copy, including cold-start/default
  Off before any user action. Relay reconnecting/lost presentation and Reconnect
  remain available when using another bridge. No past-action provenance is inferred
  from activity/process state. PR feedback clarified this wording, not behavior.
- Recovery fades away without intercepting clicks or retaining announcements;
  both reduced-motion signals disable the fade.
- Bridge status remains visible/accessibly described in expanded and compact
  navigation. Exceptional recovery moves to the sidebar, keeping existing
  takeover/retry/log callbacks and command locks. Long bundle-repair guidance
  scrolls within a bounded card; compact mode keeps its primary action.

No business, persistence, wire, auth, analytics or native-renderer change. No new
owned mutable fields, timers, subscriptions, services or coordination owners. This is
presentation of existing authoritative state, not a new analytics outcome.

## Reproducible verification

Workspace: `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.
SDK executables: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/`.
Cwds below are relative to that workspace; commands use those pinned executables.

Measured checkpoint: `f25f6eb3a3d150d3f91f58a2411dfdd215f4d8f1`.
Tree: `053e89859499f63161acf2ad144a1be05db0778c`.

| Cwd | Command | Result |
|---|---|---|
| `client/desktop` | `flutter test --reporter json test/core/widgets/desktop_cockpit_shell_test.dart` | 25 pass |
| `client/module_core` | `dart test --reporter json test/cubits/connection_overlay/connection_overlay_cubit_test.dart` | 9 pass |
| `client/desktop` | `flutter test --reporter json .dart_tool/connection_preview_test.dart` | 6 fixtures pass |
| `client/module_app_ui` | `dart analyze --fatal-infos` | clean |

The desktop analyzer requested exhaustive bridge-state branches. Follow-up
`c28ce5fc8f9ccb60449520fed9476fee63295ac5` (tree
`1f3e67a5cb2f769402768e7baa4bc4e9697b886a`) enumerates the same warning cases
and explains the card's height limit; it changes no behavior. At that checkpoint,
`dart analyze --fatal-infos` in `client/desktop` passes. The preceding tests and
fixtures remain explicitly baseline evidence, not claimed reruns at this head.
Localization generation and formatting also pass.

Logs: `/tmp/rose-elephant-connection-{desktop-final,grace-final,previews,app-ui-analyze,desktop-analyze-final}.log`.
Each contains full head/tree/cwd/command headers. Six inspected private PNGs under
`/tmp/rose-elephant-qa.mri9JX/connection-*.png` cover reconnecting, dark offline,
lost connection at 560×480, repair at a 200px sidebar/480px height, compact
Take Over, and intentional Off. They load the real bundled text/icon fonts and
production widgets using synthetic state and the Linux Flutter renderer. The
ignored fixture harness is outside Git; tree identities pin its production source.

## Proof boundaries and review

No native/live attempt was made for this slice. The existing GUI, bundle,
standalone bridge, auth and preferences remain untouched. Native relay loss,
reconnect and supervision interaction remain required before shipping/retirement,
not merge/successor gates. Fixtures do not establish native compositing, platform
view lifecycle, energy behavior, live backend coverage or user approval.

Fresh-context architecture review **APPROVED**, with no findings, the exact range
`235da0b1ae4e47fb6f5ccbc202c0eadc44b63f45..c28ce5fc8f9ccb60449520fed9476fee63295ac5`.
B-Client applied; unchanged bridge/shared workspaces were excluded. The full report
is `/tmp/rose-elephant-connection-architecture.md`, with source-write/hash
provenance in `/tmp/rose-elephant-connection-architecture-provenance.json`.
Later documentation is outside that reviewed range.

## Cleanup and size

Removed the desktop root banner mount and full-width supervision composition;
mobile retains its shared banner. No state/storage migration is warranted.

Implementation checkpoint size: **533 lines = 405 additions + 128 deletions**,
including 54 generated and 479 authored lines. Reproduce from the workspace:

```sh
git diff --numstat 235da0b1ae4e47fb6f5ccbc202c0eadc44b63f45 c28ce5fc8f9ccb60449520fed9476fee63295ac5
```

That range includes its initial tracker edit, not this evidence file or later
regression/plan edits. Final self-inclusive head/accounting belongs in the PR
body, outside its own commit hash. The step target is 700 changed lines.
