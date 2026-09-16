# Step 4.b — Nonblocking Desktop Attention Startup

Status: **in review — PR #1503; startup-admission follow-up verified**.
Implementation base: `cd4c1412359ef8962cb019d97dc7fed73835e1c8` (step 4.a squash).
PR ordinal **6/14**, after [step 4.a](step-04.md), before macOS updates.

## Observed failure and scope

Before this repair, fresh signed x64 and arm64 CI installs had live windows but black content.
Run `35019880379`, payload `d5a03026dbfe7a95af0a262225c9f3ff640c74d1`, reaches
`Desktop startup: starting desktop attention` and never reaches the subsequent
analytics/rendering stages during the observation. Independent signed storage,
registration and file probes pass. No local app/bridge may be disturbed.

`client/desktop/lib/main.dart` awaits `DesktopAttentionService.start()` before
`runApp`. The service correctly installs its event/auth/window/open listeners, but
then waits for `LocalNotificationClient.initialize()` and initial native launch
metadata. On macOS that initialization includes a native authorization request;
there is no bounded-completion guarantee. The exact host/native cause of the
observed wait remains unproven. Regardless, native notification readiness must not
be a prerequisite for rendering the app.

## Change and ownership

- Keep `DesktopAttentionService` as the sole Layer-3 owner. `start()` still awaits
  local preference/session snapshots and installs all existing subscriptions before
  returning, preserving observation before AuthGate restoration or helper startup.
- Start the existing native-initialization/initial-open sequence asynchronously from
  that owner. Reuse `_notificationInitialization`, `_notificationsAvailable`, the
  existing pending-request state and account guards. Await shared readiness before
  admitting serialized notification writes, so cleanup settles actual writes without
  waiting on native authorization. Recheck the existing fences after readiness.
  Replay captured attention once after failed startup initialization; subsequent
  failures retain event-driven retry. Do not add another initialization owner.
- Preserve useful original error/stack logging. Consume native launch metadata even
  if initialization failed, as today. If completion arrives after service disposal,
  do not open a window or route; the existing `_disposed` field suffices. Do not
  make disposal wait indefinitely for a native permission decision.
- Do not change permission policy, native entitlements, account storage, relay/wire
  contracts, plugin behavior, the bridge supervisor or user-facing notification copy.
  No new classes, mutable fields, queues, registries, timers, DI or generated code.
- Cleanup is the removal of notification readiness from the shell's rendering
  prerequisite, not a refactor of the pre-existing attention service/state machines.
  Existing account/open fences remain authoritative; do not add speculative epochs.

Scoped architecture-plan review **approved**, pre-review gate **PASS**, run
`af8e6b65-ad28-4dd4-8caf-e40d116c00c9` (`medium-intelligence-fast`). Applied B-Client
(desktop shell and desktop core); B-Bridge/B-Shared were outside scope. No findings.
Output: `reviews/desktop-distribution-step-04b-plan.md` in that run's artifacts.

## Verification and budget

Revised review budget: **about 500 authored changed lines**, zero generated. The
original under-250 estimate grew for reachable logout/retry regressions and explicit
evidence receipts, not new mutable coordination. Moderate implementation complexity;
lifecycle/startup risk warrants focused review and native execution.

1. Add a red/green test proving `start()` returns with a deliberately held native
   initializer after listeners are installed. Release it and verify normal delivery
   and initial-open handling still work; do not create broad timing machinery.
2. Cover delayed native completion after disposal and preserve existing native-
   failure/auth-scoped initial-open tests. Run the owning attention suite/analyzer.
3. Repeat native signed packaged GUI checks on both CPUs; inspect actual screenshots
   for rendered login, not merely a live window. Reuse credential-free replay for
   capture-only retries. If a different earlier await remains blocked, keep its
   evidence explicit and fix only a demonstrated cause.
4. Obtain scoped architecture implementation review, update the attention/packaging
   regression documents and record the exact native source/artifact result.

No new analytics event is justified: startup diagnostic progress is not a product
metric. Human OAuth/MFA, real account restoration, interactive TCC, minimum-OS and
public ship gates remain part of the final verification handoff, not fabricated passes.

## Implementation evidence

Initial immutable implementation: `25dc586d8a4a05a513f44aa6eb5982989e928501`.
From the repository root, the fixed budget measurement is:

```bash
git diff --numstat cd4c1412359ef8962cb019d97dc7fed73835e1c8 25dc586d8a4a05a513f44aa6eb5982989e928501
```

It includes every changed path, **including this step file at that revision**:
**7 files, 94 additions + 17 deletions = 111 authored changed lines**, zero generated.
Later evidence text is not retroactively included. The same fixed base against
`5d2db9dc995766f5929c8081c35264596f25cd6f` gives 8 files, 173 + 27 = **200**;
against `5b6bdb56be70e9ecccee95b6e95ad84bf2a992e3`, 8 files, 285 + 70 = **355**.
These are revision-bound snapshots, not self-updating current-PR totals.

Three focused assertions
failed before the production fix: held initialization blocked `start()`, and late
success/failure reopened a disposed service. Those red tests were an uncommitted
checkpoint against the base; no immutable red tree is claimed. Final tests also
cover disposal while initial-open window focus is pending.

Every row below measured full commit `25dc586d8a4a05a513f44aa6eb5982989e928501`,
full tree `f5a12df4629a16b08b875adcccbb8b45d3551f5d`, using the pinned Flutter-owned
Dart executable. Working directories are relative to repository root
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope`.
Commands ran individually, not as a combined suite:

| Cwd | Command | Individual result |
|---|---|---|
| `client/module_desktop_core` | `dart test test/services/desktop_attention_service_test.dart --reporter json` | Exit 0; 32 non-hidden successful `testDone` cases; `done.success=true` |
| `client/module_desktop_core` | `dart analyze --fatal-infos` | Exit 0; `No issues found!` |
| `client/desktop` | `dart analyze --fatal-infos` | Exit 0; `No issues found!` |

Local evidence: `build/desktop-attention-startup-evidence/attention-startup-red.log`,
`attention-tests-final.jsonl`, and `local-verification-25dc586.json`. Scoped
architecture implementation review **approved** exact `25dc586` against the base,
run `15293d58-5c2d-4bf9-af7f-775169242992`, B-Client only, no findings; output
`reviews/desktop-distribution-step-04b-implementation.md` in that run's artifacts.

## Review follow-up: readiness admission and captured retries

Ordinary flow: an authenticated attention event joins pending native initialization,
then the user signs out. That wait must not enter `_inFlightNotifications`, because
logout settles those writes before clearing credentials. `_queueAttention` checks
its initial fence, awaits shared readiness, rechecks the existing fences (including
disposal), then admits serialized writes. Actual writes remain settlement barriers. A failed startup attempt
also replays captured requests once through the existing shared initializer; there
is no repeated retry loop or new state.

Immutable red checkpoint `e78e87a3ebe136caa3c0534f54022d7dab0b22eb`, tree
`b619505c44f9d067a6815d8b01225ba8152d5167`, cwd `client/module_desktop_core`:

```bash
dart test test/services/desktop_attention_service_test.dart --reporter json \
  --name 'start returns|startup failure retries|cleanup excludes'
```

Exit **1**: one success, two expected attempt-count assertion failures, and two
expected one-second cleanup timeouts (Dart reports these as errors).

Every green row below measured full commit `5b6bdb56be70e9ecccee95b6e95ad84bf2a992e3`,
full tree `8b39259a6dcb117f0311a8e5f875d7ecd0d78862`, with the same root/SDK as above:

| Cwd | Command | Individual result |
|---|---|---|
| `client/module_desktop_core` | `dart test test/services/desktop_attention_service_test.dart test/orchestration/desktop_logout_orchestrator_test.dart --reporter json` | Exit 0; 36 attention + 17 logout cases passed |
| `client/module_desktop_core` | `dart analyze --fatal-infos` | Exit 0; `No issues found!` |
| `client/desktop` | `dart analyze --fatal-infos` | Exit 0; `No issues found!` |

Machine-readable local receipts under `build/desktop-attention-startup-evidence/`:
`review-red-receipt.json`, `review-regressions-red-e78e87a.jsonl`,
`review-verification-5b6bdb5.json`, and `review-tests-5b6bdb5.jsonl`.
Second scoped implementation architecture review **approved** full `5b6bdb5` against
the base, run `3b0b36da-6b9a-4a43-bf3b-a5645fc42e13`, B-Client only, no findings;
output `reviews/desktop-distribution-step-04b-implementation-followup.md`.
## Incoming main integration

Normal merge `eb545904ef70a5b967bb6d8d01df9fa0479e396b` brought in
`f1e3276591d5f54137eec776c219b8964af933b2` (desktop-UX popup/focus behavior).
Only regression prose conflicted; both behaviors were retained. The following
individual commands measured that full merge commit, tree
`c8904f820551b430d6956f160c1c8ab864a5661c`, same root/SDK as above:

| Cwd | Command | Individual result |
|---|---|---|
| `client/module_desktop_core` | `dart test test/services/desktop_attention_service_test.dart test/orchestration/desktop_logout_orchestrator_test.dart --reporter json` | Exit 0; 37 attention + 17 logout cases passed (one incoming UX case) |
| `client/module_desktop_core` | `dart analyze --fatal-infos` | Exit 0; `No issues found!` |
| `client/desktop` | `dart analyze --fatal-infos` | Exit 0; `No issues found!` |

Receipt: `build/desktop-attention-startup-evidence/merge-verification-eb54590.json`;
test events: `merge-tests-eb54590.jsonl`. Earlier architecture reviews remain scoped
to their stated revisions, not retroactively attributed to the incoming main change.

## Native first-render evidence

Initial `25dc586` packages rendered login in run `35038153010` (build 23); their
original receipt is preserved in Git at `5d2db9dc995766f5929c8081c35264596f25cd6f`.
Follow-up signed run [35042335424](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35042335424)
measured exact `efefcbcff7e7b75bdde271c1c670333987530212`, full tree
`d0f1d0e3cfb31090d0ddb6d5b8321604e7e65730`, **1.8.4/build 24**. It includes the
readiness-admission/retry fix; it predates the incoming popup/focus merge above.
That merge was verified separately rather than relabeling these native artifacts.
Both app/DMG notarizations were Accepted; signatures, staples, Gatekeeper, identical
seven-binary ZIP/DMG inventories, helper version/E2E and the signed synthetic
Keychain/registration/file fixture passed. Both recorded source patches were empty.
Both window and full-desktop screenshots were inspected: **rendered login**, with
GitHub/Google buttons; logs now reach analytics and rendering. This proves first
render, not account login/restoration, permission decisions, native notification
delivery, OS-login execution, minimum-OS support or public-release readiness. Default
six-target qualification was skipped in this manual mode, not newly executed.

| CPU | Native job | Packages artifact | Evidence artifact |
|---|---|---|---|
| arm64 | `104624732129` | `10425308516` | `10425577611` |
| x64 | `104624732147` | `10425499197` | `10425334824` |

All four downloaded payloads independently matched the report's SHA256 values:

| Payload | SHA256 |
|---|---|
| arm64 ZIP | `830ebf0a3fb607a9a059a8177262b8c010f2f90fd6a319f3a3ee2d34fee3b85e` |
| arm64 DMG | `27de5e5c8cfc15ed707c199d193b202fe0aec45c69abd5985f7c23ea129fda16` |
| x64 ZIP | `ee66a211471534595477b50c728a7f81091aab9389fc66a0cc305f1321330b01` |
| x64 DMG | `e0ee205da412828e667cd63653e92005986e926275b9fcc992e05d78415bbe7f` |

Retrieve to a fresh destination with authorized GitHub access (14-day retention):

```bash
gh run download 35042335424 --repo sesori-ai/sesori_apps_monorepo \
  --pattern 'desktop-macos-*' --dir <fresh-destination>
```

Local copies: `build/desktop-attention-startup-evidence/native-efefcbc/`;
each `desktop-macos-evidence-<cpu>/desktop-macos-packaging/platform-probe/` contains
`installed-gui.png`, `desktop.png` and `installed-gui.log`. Nothing was installed,
mounted or launched locally; the existing desktop and live bridge were untouched.
