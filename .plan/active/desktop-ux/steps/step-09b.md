# Step 9.b — Anchored sidebar resizing and scrollbar hit targets

Delivery 14/21 after the measured 9.c.2 split; originally published as 14/18.
Branch `desktop-ux/sidebar-interactions`.
Merged #1524 at accepted head `bf273d272e0ffff4191f870919760e686fb80446`;
squash `ed09171665995b98d1e010b9b5bd340c3c50a605`, tree `53e40902232a807cd91f83beaec669f95c084b9f`.
Final publication was **344 changed lines** (307 additions + 37 deletions) across **eight paths**.
The 202 documentation lines are included in that total, not additional to it; generated churn is zero.
From the repository root, reproduce the full base-to-accepted-head publication without path filters:

```sh
git diff --numstat \
  23ed67ca38e85894d6c1ef7c91bbc0b95a667f8d \
  bf273d272e0ffff4191f870919760e686fb80446
```

Source/test content remained identical to A below; native qualification is unchanged.
Base: `23ed67ca38e85894d6c1ef7c91bbc0b95a667f8d` (merged #1509).
Implementation A: `8a0cfcce3e30404b136d8a80529f7b097d67aae6`;
tree `e2a24ff6c1b500f94def63f5ba7c7b48da12ca72`.
The source/test scope is three paths, 124 additions + 18 deletions = 142 lines.
From the repository root, reproduce the entire immutable base-to-A diff without path filters:

```sh
git diff --numstat \
  23ed67ca38e85894d6c1ef7c91bbc0b95a667f8d \
  8a0cfcce3e30404b136d8a80529f7b097d67aae6
```

The rows are cockpit shell 42/16, sidebar 2/1, and cockpit tests 80/1 (additions/deletions).
Their sums are 124/18. A contains no documentation: this file and later docs are excluded
from that source checkpoint, not from the PR budget. The PR body records the inclusive
published diff across every path, including subsequent documentation.

## Delivered

- One private stateful resize leaf retains the initial width and global pointer X.
  `DragStartBehavior.down` includes initial movement; updates use that fixed origin,
  not a previously clamped width. Existing `DesktopSidebarCubit` still owns limits and storage.
- Drag end/cancellation saves once after an admitted drag. Idle recognizer cancellation
  does not save, so double-click reset no longer causes three preference writes.
- A 16-pixel directional project-list gutter keeps trailing controls clear of the
  interactive scrollbar. It follows expansion and becomes zero in the compact rail.
- No core, DI, wire, database, storage-format, analytics or backend change. No generation.
  Activity/refresh/wording/tooltips remain 9.c; the existing native indicator path is unchanged.

## Verification at A

Cwd: `client/desktop` within the existing `rose-elephant` worktree.
Pinned tools: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin`.

```sh
flutter test --no-pub --reporter json test/core/widgets/desktop_cockpit_shell_test.dart
dart analyze --fatal-infos
```

33 nonhidden cockpit cases pass, zero failures/skips; desktop analysis reports no issues.
Coverage includes exact immediate width, both-bound overshoot/reversal across rebuilds,
end/cancel/reset write counts, visible-scrollbar edge clicks and thumb dragging on
Linux/macOS widget variants, plus existing responsive/reduced-motion/native-view checks.
Manifest: `/tmp/rose-elephant-sidebar-interactions-verified.json`.

Before production changes, test-only index `97ce9d736105ec89faf4cabef8a8b32e6c1d9505`
ran the same suite with `--name 'drag resizes|drag preserves|admitted drag|project toggle edge'`.
Five behavioral regressions failed: maximum reversal gave 400 instead of 420,
minimum reversal gave 220 instead of 200, reset wrote three times instead of once,
and neither platform's intercepted project-edge click collapsed its project.
The sixth case's assertion passed but fixture cleanup left Flutter's 40ms double-tap timer;
a bounded pump fixes that cleanup. Red manifest: `/tmp/rose-elephant-sidebar-interactions-red.json`.

Intermediate runs exposed fixture platform-override cleanup and analyzer style issues;
use `TargetPlatformVariant` rather than resetting globals after the framework's checks.
The final 33-case run replaces earlier executions; they are not added to its count.

## Inspected synthetic renders

Four separate preview cases passed at A using the production sidebar, fake inventories,
a real cubit over an in-memory mock repository, and package-qualified Satoshi/Tabler plus
Material icon fonts. Inspected `expanded-light.png` (260px), `minimum-dark.png` (200px),
and `compact-light.png` / `compact-dark.png` (56px), each 650px tall with a visible scrollbar.
The expanded chevrons are visibly separate from the thumb; minimum-width labels truncate
without overflow, and compact geometry remains unchanged. An initial fixture omitted the
Material icon font; its renders were replaced and re-inspected, not counted twice.

```sh
flutter test --no-pub --reporter json .dart_tool/sidebar_interactions_preview_test.dart
```

Same cwd/SDK as above. The ignored harness has SHA256
`7585674cf7e9d570a6d53340cbcd424c80ce737d343f760258681f5f42f4c1f2`.
Images: `/tmp/rose-elephant-sidebar-interactions-preview.tK50vH/`.
Manifest: `/tmp/rose-elephant-sidebar-interactions-preview-final.json`.
These four Flutter/Linux renders are separate from the 33 tracked regression cases.
They do not establish native compositing, interaction, performance, or user approval.

## Architecture provenance

Plan review `7b2de045-45c2-4736-97a5-eecfda382e78` approved the concrete plan at the frozen base.
Complete report: 891 bytes; SHA256
`e89431f34bb5fe65275692f1882adfa2c02c1a57a7b8774a93e7550c5c575495`.
Bound output under the session's `subagent-artifacts/outputs/`:
`6c02e775-cc30-4c07-852d-53e3153816d9/sidebar-interactions-plan-architecture.md`.

The workflow then failed on `emit.outputPathMapping` being undefined; its completed review
was retained and the docs-only partial diff captured before same-protocol recovery.
The replacement implementation child initially returned BLOCKED while awaiting a committed scope.
It inspected no partial implementation; that response was not an architecture verdict.

Resumed implementation review `a463bd5b-963c-4395-a52a-8f268c84ad82` approved exact base..A,
all three source/test paths, B-Client; no findings. Complete report: 900 bytes; SHA256
`db7bd4a250333ef84c64d988ac3b1dade5e1ac86536f34bec4b8d2827d4a454d`.
Bound output: `b3b07151-150b-4f3e-bfc7-00faaafa2c6b/sidebar-interactions-implementation-architecture.md`.
Parent-only docs, later fixtures/evidence, 9.c and legacy cleanup are outside that verdict.

## Required qualification still outstanding

No GUI launch/relaunch, bundle replacement, helper/bridge operation, production DI,
authentication/preferences access, native registration or app smoke test was performed.
Native drag feel, relaunch persistence, native indicator scrolling/energy and the broader
plan-level qualification remain required but unexecuted. The known 250% shared-header
overflow remains assigned to step 11; this narrow interaction correction does not resolve it.
