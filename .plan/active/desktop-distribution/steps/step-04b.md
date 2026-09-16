# Step 4.b — Nonblocking Desktop Attention Startup

Status: **implemented and verified — ready for PR review**.
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
  existing pending-request state and account guards; notification delivery already
  awaits the shared readiness future. Do not add another initialization owner.
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

Target **under 250 authored changed lines**, zero generated. Moderate implementation
complexity; lifecycle/startup risk warrants focused review and native execution.

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

Immutable implementation: `25dc586d8a4a05a513f44aa6eb5982989e928501`, **111 authored
changed lines**, zero generated, against the base above. Three focused assertions
failed before the production fix: held initialization blocked `start()`, and late
success/failure reopened a disposed service. Those red tests were an uncommitted
checkpoint against the base; no immutable red tree is claimed. Final tests also
cover disposal while initial-open window focus is pending.

At `25dc586`, **32 attention cases** passed (non-hidden JSON `testDone` events), and
both owning-core and desktop strict analyzers passed. Commands, run separately:

```bash
# client/module_desktop_core
dart test test/services/desktop_attention_service_test.dart --reporter json
dart analyze --fatal-infos
# client/desktop
dart analyze --fatal-infos
```

Local evidence: `build/desktop-attention-startup-evidence/attention-startup-red.log`,
`attention-tests-final.jsonl`, and `local-verification-25dc586.json`. Scoped
architecture implementation review **approved** exact `25dc586` against the base,
run `15293d58-5c2d-4bf9-af7f-775169242992`, B-Client only, no findings; output
`reviews/desktop-distribution-step-04b-implementation.md` in that run's artifacts.

Native signed run [35038153010](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35038153010)
measured exact `25dc586d8a4a05a513f44aa6eb5982989e928501`, **1.8.4/build 23**.
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
| arm64 | `104611850455` | `10424845911` | `10424373484` |
| x64 | `104611850459` | `10424681012` | `10423863675` |

All four downloaded payloads independently matched the report's SHA256 values:

| Payload | SHA256 |
|---|---|
| arm64 ZIP | `4d76df88b7f779e200958f4f220fc52363b105c16a5434a9a4832fc49eeb0698` |
| arm64 DMG | `36f28dabd598c810034284dd57f0809c9d819ec508cbe04e3f45ae06cfed62ca` |
| x64 ZIP | `797043d464199ec5d71fd22016d1b5543fc6f305673425e825c6adb5ad4f58c1` |
| x64 DMG | `c6ce1ea1e272c383d1969ae0e0643f084b4511552ecf29a721a55db3db206978` |

Retrieve to a fresh destination with authorized GitHub access (14-day retention):

```bash
gh run download 35038153010 --repo sesori-ai/sesori_apps_monorepo \
  --pattern 'desktop-macos-*' --dir <fresh-destination>
```

Local copies: `build/desktop-attention-startup-evidence/native-25dc586/`;
each `desktop-macos-evidence-<cpu>/desktop-macos-packaging/platform-probe/` contains
`installed-gui.png`, `desktop.png` and `installed-gui.log`. Nothing was installed,
mounted or launched locally; the existing desktop and live bridge were untouched.
