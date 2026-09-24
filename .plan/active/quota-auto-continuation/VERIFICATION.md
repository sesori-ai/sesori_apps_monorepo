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

Code checkpoint: `113ff5003`; integrating main in `caae2798c` did not change this
verified tree. Run from `bridge/app`:

```sh
dart test test/bridge/orchestrator_emit_bridge_event_test.dart --name 'quota continuation shares relay state' --reporter expanded
dart test test/bridge/orchestrator_emit_bridge_event_test.dart --name 'quota startup resumes' --reporter expanded
dart test test/bridge/orchestrator_emit_bridge_event_test.dart --name '^(?!quota continuation shares relay state)' --reporter expanded
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
uses no credentials and spends no model tokens. App builds use `caae2798c`;
the bridge was restarted with the Pi validation fix included in this step.
No production account was deliberately exhausted.

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
npx --yes --package=@earendil-works/pi-coding-agent@0.85.1 node bridge/sesori_plugin_pi/tool/quota_settlement_probe.mjs 0.85.1
npx --yes --package=@earendil-works/pi-coding-agent@0.84.1 node bridge/sesori_plugin_pi/tool/quota_settlement_probe.mjs 0.84.1
```

This is native-client and pinned-runtime evidence with a synthetic provider.
It does not prove real provider quota recovery. The unavailable-harness native
screen remains unexecuted; existing shared widget coverage is separate.

## Required matrix

| Boundary | Current result | Remaining proof |
|---|---|---|
| Implemented plugin parsers and terminal settlement | Passed existing focused suites and pinned Pi RPC probes | Actual provider recovery is separate. |
| Headless policy and cancellation | Passed existing deterministic service/lifecycle suites | Composed cases above add route/DAO/ordinary-prompt proof; they do not repeat every injected failure through Orchestrator. |
| Relay and client independence | Passed composed headless boundary and native iOS/Android preference convergence/reconnect | The headless timed/restart tests use a fixture backend; live provider recovery is separate. |
| Persistent startup and no replay | Passed with new file-backed bridge compositions | Abrupt process death remains the explicitly accepted consumed/unconfirmed policy, not guaranteed delivery. |
| Pi `openai-codex` live provider | Partial: natural captured format plus pinned synthetic RPC settlement | Natural quota → post-reset provider acceptance in the same session. |
| Claude Code live provider | Partial: natural captured format plus parser/lifecycle fixtures | Pinned live runtime quota delivery and post-reset provider acceptance. |
| iOS simulator | Partial: native controls, local time, bridge restart/reconnect, unknown reset and automatic message echo passed | Unavailable-harness native state. |
| macOS desktop | Blocked: user requested leaving the running app untouched | Complete native control/message-echo journey. |
| Android shared UI | Passed native notice/menu layout, automatic message echo and acknowledged action smoke after emulator network recovery | No additional Android matrix required for this step. |
| Released-peer compatibility | Partial: public baseline/source verified | Actual released-peer decoding, ordinary send/Stop and unavailable-control journey. |

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
