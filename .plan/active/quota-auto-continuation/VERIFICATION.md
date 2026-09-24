# Final verification — 2026-09-24

Status: **in progress / partial**. The plan remains active. No reduction of the
required matrix has been accepted by the user.

## Composed bridge verification

Two new cases in
[`orchestrator_emit_bridge_event_test.dart`](../../../bridge/app/test/bridge/orchestrator_emit_bridge_event_test.dart)
exercise production Orchestrator composition, routing, session repositories,
SQLite, continuation policy/timer, mutation publication and ordinary prompt
acceptance. Authentication and backend execution use fixtures; this is not
live-provider recovery or native-client evidence.

- A normalized terminal quota event is persisted with opt-in off. Two logical
  clients use the production encrypted relay protocol and receive matching
  responses/SSE when either enables or disables the setting. Disable persists
  off while retaining reset information. A later observation can be enabled.
- Both clients disconnect before time advances to reset + two minutes. The
  real 30-second timer sends exactly one `Continue.` through the ordinary prompt
  service to the same backend session. Agent, provider/model, variant and fast
  mode survive. Both accepted-prompt and submitted-outcome rows contain its ID.
- A file-backed database retains the enabled preference while the bridge graph
  closes. A fresh graph at reset + two minutes sends from its startup tick with
  no clients. Another fresh graph drains its startup tick without replaying the
  submitted observation; the accepted-prompt row remains durable.

Immutable source checkpoints and result attribution:

- Bridge test archive: commit `113ff5003716ad27793a262e8a90a0accda657c0`,
  tree `2bf35163c23b86644272c892240334d5c671cf2b`. The local runs below were
  incremental while preparing this commit; the earlier runs preceded addition
  of the restart fixture. They are not a claim that the whole suite ran locally
  from one clean checkout of the final archive.
- Main integration: commit `caae2798c5dd6104021ac8133305da510d89dcf2`,
  tree `2bf35163c23b86644272c892240334d5c671cf2b`. The identical full tree IDs
  and a successful `git diff --quiet` between these commits prove that the merge
  changed no files.
- Pi fix/probe archive and passing CI head:
  commit `44b6e65a803e43cc3c287f58068d50d31a1b9dd3`,
  tree `c271e3e9f015a1f8a0a5e0c40e7b4fcd50a6d34e`. GitHub completed **20/20**
  checks at this exact head. The local Pi and native results below were collected
  while preparing this commit, not by rerunning native QA after committing it.

Run from `bridge/app`:

```sh
dart test test/bridge/orchestrator_emit_bridge_event_test.dart \
  --name 'quota continuation shares relay state' --reporter expanded
dart test test/bridge/orchestrator_emit_bridge_event_test.dart \
  --name 'quota startup resumes' --reporter expanded
dart test test/bridge/orchestrator_emit_bridge_event_test.dart \
  --name '^(?!quota continuation shares relay state)' --reporter expanded
dart analyze --fatal-infos
```

Each new case passed; the other 17 orchestrator cases passed before the restart
fixture was added. Final bridge app analysis passed. The first new test took 30
seconds because it uses the production timer; the restart case uses its immediate
startup tick. Existing parser/service/client evidence in [EVIDENCE.md](EVIDENCE.md)
is cumulative; unchanged passing suites were not rerun solely for confidence.

## Native synthetic-provider replay and Pi fix

The iOS 26.5 simulator and Android API 36 emulator use a dedicated dev-account
bridge and the real relay. Pi is the published **0.85.1** runtime with isolated
state and `tool/quota_probe_provider.ts`; the provider makes no network calls,
uses no credentials and spends no model tokens. App builds use the main-integration
checkpoint above. Its client tree `cb6903c7bbccff49e25c452539cfa7cfcca03975`
is identical to the client tree in the Pi fix archive. The bridge was restarted
with the Pi validation fix; no production account was deliberately exhausted.

The local Pi test/analyzer results and corrected native bridge run used the
following Dart sources, now preserved in the Pi fix archive above:

- `pi_plugin_impl.dart`: blob `8282ce4be5a928d1bb7844220f7fc55cddb5e81e`.
- `pi_plugin_impl_test.dart`: blob `1a3a6aaa56b1b24d636ce57c1a0e2aa03cc5bcb3`.

The final four-mode RPC probes used the tool sources in that archive. The earlier
native timed recovery used its `continuation` mode before the `unknown` mode was
added; those fixture edits did not change the Dart plugin sources.

`QUOTA_PROBE_MODE=continuation` returns a one-minute quota reset on the first
prompt, then accepts the automatic `Continue.` in the same resident Pi session.
Supply that extension through a `--pi-bin` wrapper, use `--no-tools`, and keep
its `PI_CODING_AGENT_DIR` separate from normal Pi sessions. `unknown` emits a
recognized quota error without a reset, allowing native UI verification without
changing the clock or editing continuation storage.

- iOS menu enable/disable and its checkmark, enabled idle indicator, inline
  enable/disable, and the local buffered date/time were observed. Bridge detail
  reads independently confirmed each acknowledged preference.
- The first scheduled attempt exposed a real defect: Pi history records
  thinking level `off` even when its non-reasoning model has no variants.
  Restoring it made ordinary prompt validation return `staleSessionOptions`
  (409), leaving the continuation outcome failed. The Pi-local fix accepts this
  native default while continuing to reject other unsupported levels.
- After restarting the bridge with the fix, the same session retained opt-in.
  A fresh synthetic quota scheduled another attempt. The normal timer accepted
  one `Continue.` about six seconds after reset + two minutes; both native
  clients displayed the ordinary user-message echo and `fixture recovery`.
  iOS displayed the submitted time and retained opt-in for future resets.
- A later `unknown` fixture reached `resetUnknown`. iOS menu opt-in stayed on
  while the notice explicitly said no continuation could be scheduled. Menu
  disable returned it to the quota notice without inventing a schedule.
- Android displayed the shared notice and checked menu. A subsequent emulator
  network failure interrupted action verification: local logs show DNS lookup
  failures and relay WebSocket upgrade timeouts. The dedicated emulator was
  restarted, restoring its connection. Android's menu enable was acknowledged
  by the bridge and appeared on iOS; iOS inline disable was acknowledged and
  appeared on Android. The final fixture preference is off. This environment
  failure is separate from the Pi prompt-validation defect.

The new Pi regression failed before the fix. After it, all **21**
`pi_plugin_impl_test.dart` cases and Pi package analysis passed. The protocol
probe now covers known reset, unknown reset, retry recovery and retry exhaustion;
all four passed on both managed target **0.85.1** and PATH floor **0.84.1**.

```sh
# From bridge/sesori_plugin_pi
dart test test/pi_plugin_impl_test.dart --reporter expanded
dart analyze --fatal-infos
# From repository root
npx --yes --package=@earendil-works/pi-coding-agent@0.85.1 \
  node bridge/sesori_plugin_pi/tool/quota_settlement_probe.mjs 0.85.1
npx --yes --package=@earendil-works/pi-coding-agent@0.84.1 \
  node bridge/sesori_plugin_pi/tool/quota_settlement_probe.mjs 0.84.1
```

This is native-client and pinned-runtime evidence with a synthetic provider.
It does not prove real provider quota recovery. The unavailable-harness native
screen remains unexecuted; existing shared widget coverage is separate.

## Required matrix

| Boundary | Current result | Remaining proof |
|---|---|---|
| Plugin parsers/settlement | Passed suites and pinned probes | Provider recovery is separate. |
| Headless policy/cancellation | Passed service/lifecycle and composed cases | Fixture backend; see limits below. |
| Relay/client independence | Passed composed headless and native client cases | Live provider recovery is separate. |
| Persistent startup/no replay | Passed file-backed bridge compositions | Consumed/unconfirmed policy still applies. |
| Pi live provider | Partial: captured format and synthetic RPC | Same-session post-reset provider acceptance. |
| Claude Code live provider | Partial: captured format and parser fixtures | Runtime delivery and provider acceptance. |
| iOS simulator | Partial: native journey above passed | Unavailable-harness native screen. |
| macOS desktop | Blocked: user requested leaving the app untouched | Native control/message-echo journey. |
| Android shared UI | Passed native action/layout/message smoke | None additional for this step. |
| Released-peer compatibility | Partial: public baseline/source verified | Released-peer integration. |

Composed cases add route/DAO/ordinary-prompt proof to the focused service tests;
they do not repeat every injected failure through Orchestrator. The headless
timed/restart cases use a fixture backend. Abrupt process death still follows
the accepted consumed/unconfirmed policy, without guaranteed delivery.
Released-peer integration must cover decoding, ordinary send/Stop and the
unavailable-control journey.

Do not deliberately exhaust accounts to complete the provider rows. A synthetic
quota or fixture response does not prove that a real provider recovers.

## Environment and compatibility baseline

- Flutter 3.47.5 / Dart 3.13.4; Xcode 27.0; macOS 27.0; Android SDK 36.
- The existing desktop process was left running. Its startup claims a singleton,
  restores bridge intent and uses the shared desktop credential service; a second
  stock launch is not an isolated test account.
- Reviewed Peekaboo **4.2.2** and agent-device **0.20.10** were installed under
  ignored worktree-local tool directories. Package/release integrity, pinned
  launcher checks, Peekaboo permissions and iOS/macOS tool preflight passed.
  The host's Peekaboo 4.5.0 remains unchanged.
- Debug iOS, Android and macOS builds passed. The native helper was rebuilt
  with the Pi fix; macOS deep/strict code-signature verification passed. Build
  and signing checks do not substitute for desktop GUI evidence.
- The user explicitly requested on 2026-09-24 that the active desktop remain
  untouched and macOS QA be recorded as blocked. No desktop takeover, sign-out,
  helper replacement or GUI launch was performed.
- Cleanup closed the two QA automation sessions, stopped their dedicated
  bridge, and shut down only the owned simulator/emulator. Test data is retained;
  the original desktop remains running. Raw logs and captures stay private;
  published PR media contains only synthetic fixture messages and generic UI.
- Public GitHub release **v1.8.4**, published 2026-09-15, points to
  `dd52942c78e3fa2ff5a86ea678d541a6f2383e17`. The rolling v1.9.0 internal build
  is a prerelease and does not create a compatibility requirement.
- At v1.8.4, the bridge's unknown-route reply is 404 with `no handler found for `;
  its generated Session decoder reads known keys and has no auto-continuation
  field. These source observations support the existing fallback tests but are
  not an executed old-client/new-bridge integration result.

This file records boundaries still to execute, rather than marking missing
accounts, natural observations or native platforms as passed.
