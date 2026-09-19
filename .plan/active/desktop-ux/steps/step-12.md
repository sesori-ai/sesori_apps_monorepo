# Step 12 — Coverage and qualification handoff

Delivery 22/22; branch `desktop-ux/coverage-retire`; documentation-only, at most 300 all-path changed lines.
Recorded 2026-09-19 against #1550 squash `776c4a9ee0c793b99a32c459b3490422039aee32`, tree
`289e0b747e6c0bf4a1f01995940d2cc92dd1b67b` in the existing `rose-elephant` worktree.

**Overall result: Partial. Retirement: Blocked.** Implementation deliveries 1–21 are merged; final native/live,
packaged and device requirements are not all executed. This report is not release qualification or a coverage waiver.
The plan remains under `.plan/active/desktop-ux/`; step 12 remains unchecked and blocked.

## Recorded matrix disposition

The authoritative matrix remains in [PLAN.md](../PLAN.md#regression-documentation-and-final-matrix).
The only accepted reduction is Windows/Linux smoke instead of full L3, accepted on 2026-09-15.
Smoke itself, macOS L3/packaged checks and iOS device smoke were not waived.
Execute cumulative entries at each target's recorded level, applying each feature's declared plugin/capability scope.
No live plugin was exercised by this documentation step.

| Target | Required boundary | Result | Evidence boundary |
|---|---|---|---|
| macOS desktop | L3 client E2E + packaged/external | Blocked | Tests/builds do not prove the live journey. |
| iOS | L2 automated + device smoke | Partial | Shared/mobile suites passed; device log/banner smoke is not run. |
| Android | L2 automated | Pass | Recorded mobile/shared tests and the settled mobile CI test job. |
| Windows | Client E2E smoke | Partial | Hosted build passed; native interactive smoke is not run. |
| Linux | Client E2E smoke | Partial | Hosted build passed; widget-render variants are not desktop smoke. |

No platform is inferred from a `TargetPlatformVariant`: those tests select Flutter behavior, not a real OS/device.
Android's Pass covers only its recorded automated boundary, not hardware, release packaging or voice capture.

## Existing evidence retained, not rerun

The documentation step runs no Dart/Flutter suite, app bootstrap, generator, live bridge or native probe.
Unchanged passing commands are not repeated solely to manufacture a final-run timestamp.
Use each source's exact checkpoint, cwd, command and failure/correction history; there is no summed series test count.

- Sidebar geometry, gestures and motion: [2](step-02.md), [2.b](step-02b.md), [9.b](step-09b.md).
  Early observed dragging/auto-collapse/reset does not qualify the subsequently changed complete cockpit.
- Inventory/activity/refresh: [3](step-03.md), [9.c.1](step-09c1.md), [9.c.2a](step-09c2.md),
  [recent owner](step-09c2b.md), [project owner](step-09c2b2.md), [refresh workflow](step-09c.md).
  Headless ownership, synchronous publication, retained data, winner receipts and action scopes have focused evidence.
- Routes, modal visibility, settings and shortcuts: [4](step-04.md), [7.a](step-07a.md), [7.b](step-07b.md),
  [7.c](step-07c.md), [10](step-10.md), [11](step-11.md). Step 11's 28-case inventory includes nine overlapping
  typography-follow-up cases, not 37. Earlier 250% overflow and size-only clipping checks remain failed history;
  the final natural-line-height check and both inspected 250% package-font renders pass at their recorded checkpoint.
- Connectivity, local controls and first-run state: [5](step-05.md), [6](step-06.md), [8](step-08.md).
  Fakes prove intent, UI scope and projection, not OS registration, permission grants or helper inheritance.
- Diagnostics and orderly completion: [9.a.1](step-09a1.md), [9.a.2](step-09a.md).
  Temporary-path rotation, typed diagnostics, cache-directory selection and fake termination ordering are tested.
  Native folder opening, actual final-write-before-exit and device backup/restore are not established by those tests.

### Hosted CI at the accepted implementation head

Before merging #1550, checks associated with head `c92ced39a99230963ee13f671586ef54e78d131a` settled 13/13:
11 successful check contexts and two skipped contexts. Cubic approved with zero issues, Codex completed without
findings, and all three review threads were resolved. The accepted head and squash share the tree above.

Workflow definitions identify what that green automation means:

- `.github/workflows/mobile-ci.yml`: analyze app/core/auth/Prego/shared UI; run core/auth Dart tests,
  Prego/shared-UI/app Flutter tests and the linter suite, on a hosted Ubuntu runner.
- `.github/workflows/desktop-ci.yml`: desktop-core/desktop analysis and tests on Ubuntu;
  `flutter build` for macOS, Windows and Linux. `supervised_e2e` was skipped, not passed.
- The catalog and lint-suppression checks also succeeded. `[code]smith` was the other skipped context.

Receipt: `/tmp/rose-elephant-1550-c92ced3-ready-assessment.json`. GitHub merge identity/time is recorded in
`/tmp/rose-elephant-1550-merged.json` and [step 11](step-11.md#merge-record).
The terminal monitor subsequently showed 13/14 still running; no terminal 14/14 success is claimed.
Hosted build success does not prove installer trust, launch/relaunch, window interaction or a client/bridge journey.

## Remaining execution and safety boundary

These checks are required, not optional backlog or regressions claimed to have passed:

1. **macOS L3:** exercise the final cockpit through a real client and supervised bridge: project/recent/Activity
   navigation, live updates and action ownership, resize/collapse/restore, connection loss/recovery without reflow,
   local Start/Stop/Retry/Take Over, modal entry/nested navigation/retained drafts, attention activation and shortcuts.
   Include native keyboard/accessibility, light/dark, reduced motion and indicator clipping/compositing/energy.
2. **macOS packaged/external:** fresh-account defaults, login-item registration and actual launch behavior;
   FDA deny/grant/focus-return and helper inheritance; logs folder opening, real orderly termination and relaunch.
   Native chrome remains unchanged; D12's omitted custom-title-bar experiment creates no new drag-region claim.
3. **iOS smoke:** inspect the actual app log and unchanged connection banner on an approved device/account.
   Backup/restore exclusion remains an additional recorded diagnostics gap, not proven by choosing a cache directory.
4. **Windows/Linux smoke:** run the client, resize/collapse, open popover/modal/logs, and verify unsupported
   file-access controls are omitted. Successful platform builds do not satisfy these interactions.

Current authorization preserves the running app/helper/bridge, production auth/preferences/databases and native
registration. It does not permit relaunch, takeover, bundle replacement, secure-storage prompts or unlocking macOS.
Required execution needs explicitly approved isolated accounts/data/process ownership and suitable native targets.
Do not borrow or mutate the protected live instance to turn a Blocked row into Pass.

Historical native attempts encountered a locked-GUI capture refusal, a pinned-SDK profile AOT snapshot failure and
an unavailable `agent-device` CLI. These are prior observations, not assertions about today's GUI lock/tool availability
or a blanket build failure; subsequent hosted release builds passed. They were not retried for this docs-only step.
No production state was mutated and no cleanup of a real app/helper is needed. Temporary render/receipt artifacts
remain outside Git; some older PNGs were unavailable and step 11 records their fake-only replacement.

## Phase-two handoff — intent only

The existing later-phase list remains exploratory, requiring its own scoped plan and approval before implementation.

- Measure per-project inventory cost before adding a bridge overview route. Preserve normalized plugin boundaries,
  latest-owner refresh outcomes and headless operation. Do not recreate the rejected presentation-driven bus.
- Existing scoped project/recent services are the starting owners, not an invitation to add duplicate caches.
  Any sidebar/main-list sharing must preserve explicit viewing claims, ordering, live patches and action scopes.
- Last-session restore, pinned/recent sections and sidebar search remain unimplemented phase-two intent.
  Diagnostics export/attachments/multi-window and multi-bridge sections belong to their later phases.
- Signing, packaging, stable Keychain identity and distribution stay with `desktop-distribution`.
  `desktop-app` MT Gate C remains pending; its unaffected harness/attention/mobile/release-safety checks are not waived.

## Retirement decision

Finish the recorded matrix on authorized targets, or obtain and record explicit user acceptance of each remaining
coverage reduction in `PLAN.md`. Only then check off step 12 and move the plan to `.plan/completed/desktop-ux/`.
The unattended implementation instruction is not such acceptance. No extra implementation PR or feature is invented
by this handoff, and publishing delivery 22 does not mean its blocked qualification work is complete.

For this report, validate only local Markdown targets, whitespace, added-line character/byte limits and the whole
branch's changed-line count. No architecture review applies to these documentation-only changes.
