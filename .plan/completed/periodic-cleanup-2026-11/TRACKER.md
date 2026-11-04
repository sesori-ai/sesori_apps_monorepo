# Periodic cleanup 2026-11 tracker

## Retired 2026-11-03

All 28 steps merged. Step 28 ran the verification matrix on `main` at
`1ca8d39c82` (step 20.l), and steps 28.a–28.g handled what it found. The user
accepted the reduced matrix: Q13 A (step-timer rows the current sign-ins could
not run) and Q14 A (desktop notification-open Not run). See
[Step 28 verification](#step-28-verification).

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
| 20.k, 20.l Dart format check (Q11 A) | Merged | #2377, #2378 | `tool/dart_format.sh` owns the generated-file exclusions; the CI jobs that analyze each workspace run it with `--check`. 20.k checks and reformats the bridge; 20.l, stacked on it, does the client, the shared packages and the root `tool/` scripts (which get a `tool/analysis_options.yaml` with the repository's formatter settings). Formatter output only: 174 files, about 2,820 lines. |
| 27 Regression docs | Merged | #2375 | Also runs the retired step-timers plan's step-6 reconciliation (Q6), and applies #2374's accepted README row. |
| 28 Verify and retire | Merged | #2380, #2381, #2382, #2383, #2384, #2385, #2386 | Includes the retired opencode-v2 and step-timers live rows (Q6). See "Step 28 verification" below. |

Out of series:
- #2309 fixed PN-1 (OpenCode v2 idle).
- #2311 fixed the Pi test flake.
- #2355: ownership records match on pid, start marker and a live command line that ends with the recorded args, so interpreter-shim, execve and native launches all match. Without a start marker (Windows) a record still falls back to pid + path.
- #2359: a Windows graceful stop that throws falls back to force on every stop path and skips the grace wait.
- #2365 (Q8 A): backend runtimes on Windows join a kill-on-close job object, so they end with the bridge.
- #2379 (Q12 B): Windows runtimes that end with the bridge start inside the kill-on-close job (`CreateProcessW` with `PROC_THREAD_ATTRIBUTE_JOB_LIST`), so none escapes before it is bound; this closes the gap without a suspended phase. If that start fails, it is logged and falls back to `Process.start` plus a late bind. Known limits: Windows before 1607 uses the late bind; descendants started with `CREATE_BREAKAWAY_FROM_JOB` escape; a read error other than end-of-file ends the output stream with a log. Declined in review: adding a suspended start anyway (the `RegisterWait` failure it would guard happens only on resource exhaustion, and the child stays in the job regardless), and unlistened pipes (every caller drains both).

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

## Step 28 verification

Run on 2026-11-03 against `main` `1ca8d39c82`: a headless live bridge on macOS
arm64 and the headless iOS simulator. Rows follow PLAN.md "Verification and
retirement".

| Row | Result | Evidence or reason |
| --- | --- | --- |
| Plugin interface, routes and plugins | Pass | Setup inspection of all 11 harnesses (9 ready; Antigravity and Copilot runtime-missing; Cursor disabled). Real turns completed on OpenCode v2, Claude Code and Codex; a Claude permission round trip. |
| Bridge services | Pass after 28.a, 28.b | `supervised_e2e_test`, reconnect backoff (1, 2, 4 s), no stray processes, exit codes {0, 1, 87, 88} and no restart route all passed. Clean shutdown was Partial: a stalled debug event stream forced a 50 s shutdown (28.a), and each runtime stop waited the full 5 s grace (28.b). |
| Client (steps 13–17) | Pass | iOS simulator: project and session lists, rename without a jump, session detail, Settings without the voice-engine row, dictation, sign-out and sign-in. The "Couldn't load sessions" flash after sign-in went to 28.f. |
| Desktop-specific (step 19) | Not run (Q14 A) | `module_desktop_core` `dart test` 454/0 and module_core notification routing 26/0. The macOS desktop launch was not run, per the testing rule. |
| Shared, linter, CI, docs | Pass | `tool/dart_format.sh --check` clean over 3,303 files; no_slop_linter 225/0; `sesori_shared` analyzes clean, 494/0; OpenCode v1 and v2 regeneration is byte-identical; CI below. Link check: 552 links, 10 broken, all in the 2026-09 `.plan/completed/periodic-cleanup/AUDIT.md`, pointing at code later work moved; left as the historical record. |

Retired opencode-v2 live rows (Q6), each bridge-side; the client-side cases ran
with the step-timers rows:

| Row | Result | Evidence or reason |
| --- | --- | --- |
| OpenCode 1.18.32 on PATH | Pass | |
| Managed upgrade 1.18.32 → 2.1.4 | Pass | First cold start 21.4 s, including the database migration. It used a private server, because the user's shared service held the port. |
| Managed fresh install 2.1.4 | Pass | |
| `--opencode-no-auto-start` attach | Pass after 28.c | The re-fetch after a reconnect was Partial: a session that finished during the outage stayed busy. |

Retired step-timers live rows (Q6). Device, Android and macOS desktop rows are
not run, per the testing rule.

| Harness | Result | Evidence or reason |
| --- | --- | --- |
| Claude Code | Pass | Its first sub-agent kept the main turn "Working…" for about 90 s while a background shell ran; this matches the bridge's state, so no change. |
| Codex | Pass | |
| OpenCode | Partial (Q13 A) | Working timer Pass. Foreground Task Partial and background sub-agent Blocked: the sub-agent models return 401 because OpenCode's Anthropic sign-in was revoked. |
| Pi | Pass | Run on the DeepSeek key; Pi's OpenAI sign-in fails with `invalid_grant`. |
| DeepSeek | Partial (Q13 A) | Sub-agent Pass. The working timer was not caught on screen, but the bridge returns the message times it needs. |
| Grok | Pass after 28.d | Sub-agent and follow-up passed; the first prompt of a new session showed no time. |
| Hermes (another ACP) | Pass after 28.d | Follow-up passed; same first-prompt failure as Grok. |
| Retry rows | Not run (Q13 A) | No harness produced a retry status that could be triggered; Hermes reports provider retries only as transcript text. |

Fixes found by step 28 (none caused by the cleanup):

| Step | PR | Change |
| --- | --- | --- |
| 28.a | #2381 Merged | The debug server writes to each client without awaiting a flush and drops a client when its response ends. Accepted: no backpressure for a stalled but connected debug client, and cubic's bounded queue declined (a loopback, opt-in debug tool). |
| 28.b | #2383 Merged | An owned runtime stop and the post-crash stale cleanup end the grace wait when the runtime exits (bridge exit 5.1 s → 0.2 s; plugin start after a crash about 5.5 s → under 1 s). Declined: an untracked-record qualifier (no caller) and a poll-count backstop (only a frozen fake clock reaches it). |
| 28.c | #2382 Merged | After an event-stream reconnect, OpenCode v1 and v2 diff session status and send a finished turn's final reply with all its parts; v1 drops duplicate replied events by request id. No change for v2's three `part.removed` events: they are the bridge's own retry-row clears, which clients ignore. |
| 28.d | #2380 Merged | An ACP session's first prompt keeps its time on replay (Grok, Hermes, Antigravity, Copilot, Cursor, OMP). |
| 28.e | None | No change. "Codex stayed stopped after its app-server exited" is the documented dormant state: Codex runs with `RuntimeRestartPolicy.disabled()` because it cannot reconnect to a restarted app-server, and the next request starts a new generation (verified live; chosen in 199d5f6a96, documented in `plugin-setup-and-lifecycle.md`). The failed-plugin hint is accurate. |
| 28.f | #2384 Merged | Session loads, pages and search wait under the skeleton while the bridge connects (15 s cap); sign-out clears the filter, so there is no title jump or cross-account carry. |
| 28.g | #2385 PR open | After a Codex app-server WebSocket drop mid-turn, the plugin reconnects at once while the process runs, resumes the idled sessions, restores busy for a running turn (keeping its turn id for Stop), sends the newest reply for a turn that ended during the outage, and re-syncs the work state. Accepted: items missed during the outage appear on reload (parity with OpenCode), and two rare races (a prompt's own resume landing first, a second drop mid-resume). |

Q16 C: the rating sheet keeps its timing; it followed its documented rules.

Q15 cleanup: 19 step 28 sessions were deleted (OpenCode 6, Claude 4, Codex 3,
Grok 2, DeepSeek 2, Hermes 1, Pi 1), including the Hermes session with the
dictated speech, and the local evidence folder. The two "extra dev-account
registrations" never existed. Left: Hermes's `state.db` free pages keep the
dictated bytes until the user runs `hermes sessions optimize` with Hermes
closed; OpenCode keeps empty project rows for the deleted scratch folders (no
delete API); log files still name the session ids.

CI on `main` `1ca8d39c82`: Mobile CI 41735174047, Desktop CI 41735174331,
Design Catalog CI 41735174083 and Bridge CI 41735173971, all green. Bridge and
Desktop CI stay green through the 28.a–28.d and Q12 commits.

Stale matrix text: PLAN.md's opencode-v2 row says "managed OpenCode 2.0.x",
but the pin is 2.1.4 (2.0.11 is the v2 and shared-service floor). The live run
also corrected assumptions carried over from retired plans: the setup route is
`/plugin/management` (not `/plugin/setup`), compaction runs through the
`compact` command (there is no route), v2 forms reach clients as Sesori
`question.asked` events, and v2 archive state lives in the bridge database. No
live doc states the old assumptions. The one live-doc fix:
`plugin-runtime-installation.md` now says managed runtimes install under the
home directory, which `--data-dir` does not move.

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
