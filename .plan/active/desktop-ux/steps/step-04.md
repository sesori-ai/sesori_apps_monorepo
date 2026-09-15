# Step 4 — Main-pane routing

PR ordinal: 5/13. Branch: `desktop-ux/main-pane-routes`.

## Delivered

- Session list, new session, detail, and diffs are direct sibling routes under
  the authenticated cockpit. Only the all-sessions page mounts the full
  `SessionListCubit` provider; the sidebar's recent inventory remains independent.
- The cockpit supplies `SessionSplitScope(isSplit: true)` at every width so
  shared detail presentation does not add redundant back navigation. Mobile's
  adaptive split and viewing-claim owners are unchanged.
- All sessions renders `SessionListScaffold`, including archive filtering,
  scan/refresh, shared row actions and the New task button, without a back arrow.
  Archived rows open read-only; deleting the open session returns to its list.
- New-session creation replaces its page with detail. New-session/diff Back
  preserves a pushed opener, including archived detail state; direct-entry Back
  falls back to the project's all-sessions page.
- The Projects header opens `DesktopHomePane`: sidebar guidance, Add/Open
  Project for empty inventory, labelled loading, shared failure retry, and the
  moved supervised bridge recovery view. `/splash` retains Bridge controls until
  step 6; settings routes are unchanged.
- The existing route-selected project and New session callbacks remain the
  shortcut plumbing point. Binding and shortcut-hint copy stay in step 10;
  home does not advertise an unavailable shortcut.

## Ownership, cleanup, and scope

No new persistent or business state, services, wire fields, backend behavior,
analytics events, or database changes. The existing bridge-identity cubit is
composed only for disconnected home presentation. Desktop analytics remains a
no-op; this slice introduces no authoritative outcome needing a new event.

Removed the desktop project-grid composition, persistent split-list widget,
nested session navigator/shell, and relative route-segment constants. Shared
mobile split widgets remain real consumers and are untouched.

Font-loaded previews exposed an existing mismatch between Prego's unqualified
font constant and the package-qualified family in the actual app font manifest.
The constant now names the bundled family. Removed redundant sidebar and
avatar package overrides. This also corrects shared/mobile typography; system fallbacks
and explicit monospace overrides retain their unqualified names. No new font,
platform renderer, animation cadence, or broad style redesign was introduced.

## Reproducible verification

Workspace root:
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.
Pinned tools:
`/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/{flutter,dart}`.

Production code checkpoint: `b90206e61d09a317100cc71846d845f491182bc1`.
Tree: `5d3ea4c554b6d25d4f98312d339c7d824ae72696`.
All 147 cases below passed at that checkpoint. Logs include revision, cwd, and
command headers; counts use executed, non-hidden JSON test results.

| Cwd relative to root | Command after `flutter test --reporter json` | Passed |
|---|---|---:|
| `client/desktop` | `test/core/routing/desktop_router_test.dart test/core/widgets/desktop_cockpit_shell_test.dart test/features/home/desktop_home_pane_test.dart test/features/sessions/desktop_session_detail_screen_test.dart test/features/new_session/desktop_new_session_screen_test.dart` | 42 |
| `client/app` | `test/core/routing/adaptive_session_route_matrix_test.dart test/core/routing/imperative_pane_route_test.dart test/core/routing/app_route_test.dart test/features/session_detail/adaptive_session_detail_routing_test.dart` | 53 |
| `client/module_app_ui` | `test/features/session_list test/widgets/markdown_styles_test.dart` | 49 |
| `client/module_prego` | `test/theme/prego_theme_data_test.dart` | 3 |

Logs: `/tmp/rose-elephant-main-pane-{desktop-final,mobile-routing,shared-ui,font-final}.log`.

`404da2ea23b7322f4f8aef78157066cfab843674` only replaces one test teardown
closure with its tearoff. After that cleanup, the six home cases and desktop
`dart analyze --fatal-infos` pass. The shared UI/Prego analyzers passed at the
production checkpoint. No unchanged passing suite was rerun for the test-only
cleanup. Logs: `/tmp/rose-elephant-main-pane-home-final.log` and
`/tmp/rose-elephant-main-pane-{desktop,module_app_ui,module_prego}-analyze-final.log`.
Final image inspection caught the avatar's remaining package override.
`0494cb0d24189ccabe31dad84368eca6792ba1d1` removes that argument and adds an
assertion. At this head, both avatar tests, all 20 cockpit cases, all five
render fixtures and the Prego analyzer pass. Those changed-scope logs use
`{avatar-final,cockpit-final,previews-final,module_prego-analyze-final}` under the
same `/tmp/rose-elephant-main-pane-` prefix. This adds two distinct cases to the
147-case baseline, not 22 new cases.

Localization generation (`flutter gen-l10n` in `client/module_app_ui`) and
format/diff checks pass. CI owns the remaining full suite/analyzer matrix.

Router callback tests exercise production registrations/decoders/callbacks with
inert page bodies, not authentication or real backend operations. Content tests
and render fixtures separately exercise production widgets.

## Rendering and outstanding native coverage

Five final production-widget fixtures pass at `0494cb0`:
`flutter test --reporter expanded .dart_tool/main_pane_preview_test.dart` in
`client/desktop`. The harness uses typed synthetic state and actual bundled
fonts (no font-family aliases), and Linux Flutter rendering. Images were
inspected for home, empty inventory, light/dark all-sessions, and 560-pixel
compact layout; the initial missing-font result was not accepted as visual proof.

Private images: `/tmp/rose-elephant-qa.mri9JX/main-pane-*.png`.
Harness and images stay outside tracked source. The running GUI, standalone
bridge, authentication, persisted preferences, and live app bundle were not
modified or relaunched. Native Apple activity indicators remain enabled.

These fixtures are not user approval, native compositing/performance evidence,
or live session/action coverage. Native route/back interaction, indicator
lifecycle/steady-frame behavior, persistence, and the final platform matrix
remain required before shipping/retirement, not merge/successor gates.

## Architecture and size

Architecture implementation review: approved for `93bc177..404da2e`, using a
fresh-context reviewer and the architecture skill. No findings. Report:
`/tmp/rose-elephant-main-pane-architecture.md`. The later one-argument avatar
font correction and assertion do not change architecture and have the focused
follow-up evidence above; they were outside that frozen review range.

The implementation/test checkpoint `0494cb0` is 980 changed lines (587 additions
+ 393 deletions), including nine generated localization lines, against merge base
`93bc177d60da690692f11a837101a4d76887059d`. Final self-inclusive head/size,
including this evidence and regression docs, is recorded in the PR body using
`git diff --numstat <merge-base> <final-head>`; the step target is 1,400 lines.
