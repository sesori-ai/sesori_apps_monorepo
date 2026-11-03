# Periodic cleanup 2026-11 tracker

Status values: Pending, In progress, PR open, Merged, Blocked, Dropped.

| Step | Status | PR | Notes |
| --- | --- | --- | --- |
| 1 Raise the plan | Merged | #2310 | Also moves the 2026-09 audit record into the completed periodic-cleanup plan. |
| 2 Plugin-interface members | Merged | #2318 | `healthCheck`, `renameProject`, `markFailed` and the always-null `getSessions` paging are gone from the interface, every plugin and the fakes. |
| 3 Project-questions and plugin-setup routes | Merged | #2331 | Removes `POST /project/questions` and `GET /plugin/setup`; no public client tag calls either. |
| 4 ACP family | Merged | #2336 | Also fixes the OMP persisted-session cleanup, which had always aborted since #846 (OMP 18.15.0 never echoes `sessionId` on `session/resume`). |
| 5 Claude plugin | Merged | #2335 | Unread stream-json variants collapse into one silent `ClaudeIgnoredMessage`. |
| 6 Codex plugin | Merged | #2334, #2338, #2339, #2342, #2343 | 6.b: an approval without `threadId` fails with -32602, and a failed login status is logged. 6.d: permission id generators and probe timeouts are required. 6.e: the bridge version lives in `sesori_bridge_foundation` `bridgeVersion`, and Codex and the ACP family report it in `clientInfo` instead of "0.0.0". |
| 7 Pi, OMP and OpenCode plugins | Merged | #2346, #2347, #2351, #2354, #2376 | 7.a also fixes the OpenCode `password` option's `defaultsTo: ""` and the flaky Pi tests. 7.b reads Pi file history into the generated RPC DTO (−2.1k generated). 7.d: ownership-record builders throw `StateError` on a missing executable path; the record format is unchanged, because older public bridges reject the whole shared file on a null path. 7.e removes the test-only `OpenCodeV2Api.getServerInfo`, the generated v2 `ServerInfo` model, and `server.info` and `project.update` from the v2 surface; dropping `project.update` from the v1 surface changes no generated output. |
| 8 OpenCode v1 generated models | Merged | #2312 | Also removes the unused `--with-client` generator mode. |
| 9 Bridge persistence and plugin fakes | Merged | #2333, #2337 | 9.b drops the unused `idx_projects_path` index (schema v23, no row change). |
| 10 Push and updater | Merged | #2319, #2320 | Push maintenance logs one debug summary line per pass. Rollback failures and updater warnings now carry stacks. A cached release track this bridge does not know reads as a cache miss. |
| 11 Runtime package and lifecycle | Merged | #2327, #2325, #2328 | 11.c drops the relay `1000 + "replaced"` fallback after confirming the deployed relay sends 4007. |
| 12 Bridge app rule violations | Merged | #2344, #2345, #2356, #2358, #2361 | 12.a adds the shared sealed `RelayControlMessage`, and `--import-plugin` is now an unknown option. 12.d logs debug-server SSE disconnects at debug level. 12.e makes `token.dart` a Freezed model (same keys; a missing access or refresh token now means re-login instead of a startup crash) and makes `CommandExecutor.run` all-named across 12 packages. Positional by design: `addSourceError` (a stream `onError` callback), Drift DAO and database constructors, function references and `fromJson`. |
| 13 module_core APIs | Merged | #2322 | Local logs gain entries for analytics delivery, preference storage, harness sign-in launch and relay health-check failures. |
| 14 Optimistic session rename | Merged | #2326, #2329 | 14.b shows the new title in the session header at once. |
| 15 Prego components | Merged | #2313 | |
| 16 Phone app | Merged | #2330 | Removes the voice-engine picker (Q4) and the deep-link stack. The stored `voice_engine` value becomes a dead key, not migrated. |
| 17 Shared platform adapters | Merged | #2332 | The phone and desktop route dispatchers are merged into one. |
| 18 sesori_shared dead code | Merged | #2316, #2317 | |
| 19 Login control prompt and notification routing | Merged | #2349, #2352 | Adds the shared `openNotificationSession` in module_core routing. 19.b moves the macOS pinch and transition tests into module_app_ui. |
| 20 Lint rules | Merged | #2360, #2362, #2363, #2364, #2369, #2370, #2368, #2371, #2372, #2367, #2366, #2373, #2374 | See "Step 20" below. |
| 21 CI leftovers | Merged | #2314 | Removes the `DESKTOP_MACOS_PUBLICATION_ENABLED` gate. Also deletes the released-peer MCP runner, which could no longer run on main. |
| 22 Compatibility markers | Merged | #2348, #2357 | 22.b: `Project.path` is `required`, and `Project.fromJson` fills a missing path from the id (bridges v1.0.8–v1.4.0 omit it); the marker retires once bridges older than v1.4.1 are unsupported. |
| 23 Plans and docs | Merged | #2315 | Retires all eight plans with accepted gaps (Q5) plus `path-runtime-authority-split` (Q2). |
| 24 Restart route | Merged | #2350 | Removes the route and the whole restart subsystem (Q1), including exit code 86; `/global/restart` returns 404. |
| 25 Runtime-update seam | Merged | #2341 | Removed (Q2). The management snapshot sent to apps is byte-identical. |
| 26 Phone desktop/web runners | Merged | #2340 | Deleted (Q3), about 3.6k lines rather than the audit's ~9.9k. `firebase_options.dart` and `firebase.json` stay as generated; the next `flutterfire configure` for Android and iOS trims them. |
| 20.k, 20.l Dart format check (Q11 A) | PR open | | `tool/dart_format.sh` owns the generated-file exclusions; the CI jobs that analyze each workspace run it with `--check`. 20.k checks and reformats the bridge; 20.l, stacked on it, does the client, the shared packages and the root `tool/` scripts (which get a `tool/analysis_options.yaml` with the repository's formatter settings). Formatter output only: 174 files, about 2,820 lines. |
| 27 Regression docs | Merged | #2375 | Also runs the retired step-timers plan's step-6 reconciliation (Q6), and applies #2374's accepted README row. |
| 28 Verify and retire | Pending | | Includes the retired opencode-v2 and step-timers live rows (Q6). |

Out of series:
- #2309 fixed PN-1 (OpenCode v2 idle).
- #2311 fixed the Pi test flake.
- #2355: ownership records match on pid, start marker and a live command line that ends with the recorded args, so interpreter-shim, execve and native launches all match. Without a start marker (Windows) a record still falls back to pid + path.
- #2359: a Windows graceful stop that throws falls back to force on every stop path and skips the grace wait.
- #2365 (Q8 A): backend runtimes on Windows join a kill-on-close job object, so they end with the bridge.
- Q12 B, in progress: on Windows a runtime starts suspended, is bound to the job object, then resumes, so it cannot escape the job before it is bound.

## Step 20

- 20.a–20.d (#2360, #2362, #2363, #2364): dead linter rules and the client linter dependency go (DS-2, XC-6); `prefer_specific_type` exempts JSON maps and error causes (DS-13); `avoid_bang_operator` covers tests (DS-14), with client, shared and the already-linted bridge packages cleaned.
- Q9 A: the bridge enforces the written rules (no `!`, no forced casts, required named parameters, exhaustive switches, no mutable fields, no dynamic return types). `prefer_specific_type` and `avoid_implicit_tostring` are off for the bridge; the client keeps every rule. Q10 A: the bridge app tests are swept as well.
- 20.e (#2369, #2370): bridge lint config with the two style rules off and 110 suppressions removed; `avoid_raw_go_router` only flags `BuildContext`, `GoRouter` and `NavigatorState` receivers; the linter runs in acp, claude, hermes, codex, cursor, omp and pi. Ignores added: Claude `readValue` ×2.
- 20.f (#2368, #2371, #2372): OpenCode generators, production code and tests. Generated output is byte-identical; no ignores added.
- 20.g (#2367) and 20.h (#2366): the bridge app's production code and tests. Ignores added: `BridgeSettings.copyWith` and `SessionEventDispatcher.addSourceError`.
- 20.i (#2373): every bridge package includes `bridge/analysis_options.yaml`, which declares the plugin and includes `bridge/all_lint_rules.yaml`.
- 20.j (#2374): `prefer_exhaustive_switch` also flags `case _:`, untyped `final`/`var` bindings, and variables, wildcards or object patterns typed as the scrutinee or a supertype. Guarded cases are never flagged, switches that only split null from non-null are exempt, and the quick fixes do not cover the new forms.

Behaviour changes from step 20 (all edge cases of malformed input):
- ACP: a wrong-typed field reads as absent or fails with `FormatException`; Cursor: a thought-level config without an id reads as absent.
- OpenCode: a null MCP status fails with a `FormatException` naming the server instead of a `TypeError`; the raw HTTP post, patch and delete lost an unused `timeout` parameter.
- `tool/bump_version.dart` skips non-object `optionalDependencies` and `sesoriBridge` entries instead of crashing.

## Decisions and declined review findings

- 7.c: no shared hint mapper. DeepSeek and Copilot hints are harness-specific (Copilot names `copilot login`; DeepSeek's runtime is the Sesori adapter).
- 22: fourteen markers keep "once the minimum supported bridge always sends it", a concrete retiring condition. Its cubic threads: one fixed, three declined with tag evidence.
- 12.d: no guard on the debug-server `response.done`; no flow reaches it.
- 12.e: cubic's `token.dart` message-leak thread declined; `CheckedFromJsonException` never includes the map, only a provider name.
- #2355: cubic's PID-reuse adoption thread declined; the unique listen port is in the args.
- #2359: accepted the exit-before-signal race. It can leave one "stopping" record, which the next start's stale cleanup deletes.
- #2365: a per-executor lifetime split declined, because short commands end on their own. The architecture review's question about the host port and JSON-store adapters was decided as no change: they are small boundary adapters, and a pass-through repository adds no behaviour.
- #2360–#2364: the README CRLF-to-LF complaint declined; the file is published as is.
- #2374: three cubic findings declined. The legacy `case null:` node cannot appear, since every package requires Dart 3.13. Typed object-pattern fields and logical-or catch-alls have no site in the repository. Its README row was accepted and lands in step 27.
- BA-12 (step 9): no change. 12.a (#2344) already replaced the orchestrator's three bare `DateTime.now()` calls with `clock.now()`. `ServerClock` (the plugin-host contract `SessionOptionsService` uses) and package `clock` return the same instant in production, and each test's fake controls every time-dependent path. Unifying them would be 40–60 lines of churn with no behaviour gain.

## Dropped or corrected findings

Findings disproved during a step are recorded here with the reason.

- PN-1 (OpenCode v2 idle): fixed outside the series by #2309.
- PN-2 (step 8): request-body roots could not be dropped outright; v2 imports five of those models, so its surface lists them in `extraSchemas`.
- PN-15 (step 2): dropped. Codex and OpenCode v1/v2 `implements` the managed-API interfaces, so the overrides are required.
- PI-8 (step 4): only `session/new` throws on a missing session id, because the `session/load`, `session/resume` and `set_config_option` answers carry none; ACP auth methods without an id are skipped rather than failing `initialize`.
- BS-7, BS-11, BS-15 (step 11): `MalformedFramePolicy` stays (Codex depends on `failPending`); `trackOwnedRuntime` stays as a test seed; the selection source enum stays, because provisioning logs it.
- BS-17 (step 12): the audit's evidence was wrong; only 2 and 3 of 18 tests passed the backstop arguments, which the tests now add.
- BS-19 (step 12): `BridgeSettingsRepository` is not built five times; each CLI command builds it once.
- MC-3 (step 13): `RelayClient.pendingRequestCount` stays as a deliberate `@visibleForTesting` hook.
- UI-2 (step 16): GoRouter does receive deep links and its `onException` ignores them, so removing `app_links` still changes nothing visible.
- DS-10 (step 23): macOS shipped publicly in v1.9.1, not v1.10.1; the conclusion holds, because the shared store predates v1.9.1.
- Shared `CommandExecutor` test fake (bridge-services audit): dropped. The 18 fakes across 7 packages behave differently, and one configurable fake would need a test-support library in a production package.
