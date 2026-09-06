# Periodic cleanup — recorded verification results

Executed for step 25 of [PLAN.md](../PLAN.md) against the branch head recorded
below. Each row of the plan's verification matrix is reported as `Pass`,
`Partial`, `Fail`, `Blocked`, or `Not run`, with the evidence that produced it.

## Execution context

| Field | Value |
| --- | --- |
| Commit | `2a20330dd9` (branch `periodic-cleanup-step-25`, on top of merged steps 1-24) |
| Host | macOS on Apple Silicon (single machine) |
| Bridge host | Same machine. A source bridge ran headlessly on dev slot 1 (debug port 9971, isolated data directory) |
| Client platforms | iOS 26.5 simulator (`sesori-dev-1`, iPhone 17), debug build installed and driven. macOS desktop app built and launched but not observable |
| Plugins | OpenCode 1.18.29 and Codex 0.153.4 started and ran real turns. All ten registered harnesses inspected. No runtime installed |
| Accounts | Dev account `1@sesori.com` only, through the production relay. No user data touched |

## What was executed

Everything in this section ran to completion on the commit above.

| Evidence | Result |
| --- | --- |
| `bridge/` full workspace suite (`make test`) | 5,489 passed, 3 skipped, across all 16 modules |
| `bridge/` analyzer matrix (`make analyze`) | No issues across all 16 modules |
| `client/module_core` | 1,565 passed |
| `client/module_auth` | 109 passed |
| `client/app` | 682 passed |
| `client/module_app_ui` | 302 passed |
| `client/module_prego` | 275 passed |
| `client/desktop` | 112 passed |
| `client/module_desktop_core` | 261 passed |
| Analyzer, pure Dart: `module_core`, `module_desktop_core`, `module_auth`, `sesori_shared`, `no_slop_linter` | No issues |
| Analyzer, Flutter: `app`, `desktop`, `module_app_ui`, `module_prego`, `design_catalog` | No issues |
| Documentation link and source-reference validation | No broken relative link; every source path in all 25 regression guides resolves |

## Live coverage executed

A second pass added live evidence on top of the automated suites:

| Evidence | Result |
| --- | --- |
| Headless bridge start on dev slot 1 | Authenticated, debug server listening, relay connected |
| Harness inspection, all ten registered harnesses | 8 `ready`, `copilot` `runtimeMissing`, `grok` `authenticationRequired`; nothing installed, no backend started by inspection |
| OpenCode provisioning and bounded cold start | Path runtime selected, server started on a dynamic port, cold start completed inside its budget (no degraded or timeout line) |
| Codex provisioning and bounded cold start | App server started on a dynamic websocket port, cold start completed inside its budget |
| Live turn, OpenCode | Session created with a first prompt; user and assistant messages present in durable history; session returned to idle |
| Live turn, Codex | Session created with a first prompt; user and assistant messages present in durable history |
| iOS simulator, signed-in launch | App restored its session and reached Projects with the bridge shown online |
| iOS simulator, navigation | Projects to session list to session detail, showing both live sessions and the full transcript with timestamps, agent/model/variant selector, composer and voice control |
| iOS simulator, live turn from the client | Follow-up prompt typed and sent from the app streamed through relay to bridge to OpenCode, and its reply rendered in the transcript |
| Bridge ownership | Launching a second bridge for the same account produced the documented takeover: `closeCode=4007 closeReason=replaced` and a long-backoff retry on the displaced bridge |

## What was still not executed

macOS desktop client end to end: the app builds and launches, but this host has
no observable display for the run, so its navigation and rendering could not be
verified and are `Not run`. Android, packaged artifacts, push providers, real
provider accounts, and managed runtime installation were not exercised.

## Per-row results

| Matrix row | Result | Evidence and gap |
| --- | --- | --- |
| Steps 2-3 — history/turns/connectivity | Partial | Automated cubit, buffer and history-mapper coverage passed. Client end to end on the iOS simulator now also passed: a prompt sent from the app streamed through relay, bridge and OpenCode, and the transcript rendered and persisted. The macOS desktop half is `Not run` (no observable display). |
| Steps 4/8 — projects/archiving | Pass | Real-SQLite repository, service, identity, ordering and route suites passed in the bridge suite. The row's boundary is a representative faithful plugin, which the suite provides. |
| Step 5 — creation and options | Pass | Real database fresh-install and schema-14 upgrade, discovery, malformed-JSON, invalidation, generation and path tests passed on a macOS SQLite host. The row declares fake plugin plus real DAO/repository/service as the full cache-policy boundary. |
| Steps 6-7 — turns/history/questions | Pass | Translator, status-variant, message, stable-id, terminal-handoff, child-routing and wire round-trip suites passed for every producing plugin, and the row's headless-bridge transcript/status smoke ran against two representative live backends (OpenCode and Codex), each finalizing its turn into durable history and returning to idle. |
| Step 9 — tools/connectivity | Pass | Dropped-category OpenCode mapping fixtures, Codex MCP suppression, both mapper suites and the client decoder regressions passed. The row's boundary is automated plus consumer inspection. |
| Step 10 — attachments/voice | Partial | Shared storage, temporary-directory cache/failure/retry, image-repository, retirement, atomic-replacement, concurrency, corruption and recording suites passed on macOS. Native directory binding smoke on macOS desktop, iOS and Android: not run, and the row states mock-only wiring cannot substitute. |
| Step 11 — rename | Pass | Both cubit rename suites and the shared RenameSheet behavior and widget tests passed; the shared module and both shells analyze clean. The row needs no live rename claim. |
| Step 12 — runtime installation | Partial | Runtime and all seven descriptor install/setup suites, manifest target mapping, checksum, failure, cancellation and client-closure coverage passed. Headless live installation on macOS arm64 for every managed-install consumer: not run. |
| Step 13 — installation/setup lifecycle | Pass | Provisioning and descriptor suites for all seven managed plugins passed, including both Codex/OpenCode cold-start success, failure, timeout, late-failure and abort paths. Headless inspection ran for all ten registered harnesses, and the live bounded cold-start smoke ran for both Codex and OpenCode on macOS arm64, each completing inside its budget. |
| Step 14 — worktree/Codex folds | Pass | Worktree collision, failure and fallback tests plus the Codex command, turn-retry and scanner suites passed, with the real Git fixture proving repository creation. The row states no live backend is needed. |
| Step 16 — shell composition | Partial | Both shell provider and screen tests and the fresh-cubit lifecycle assertions passed. Real navigation through project, session list and session detail passed on the iOS simulator. The macOS desktop half is `Not run` (no observable display). |
| Step 17 — account and onboarding | Partial | Real auth-owner tests with fake HTTP and secure storage passed, covering email and Apple completion, parse, non-2xx and empty failures, supersession, logout and persistence failure. Email client end to end on a mobile platform: not run. |
| Steps 15/18-24 — tests, tooling, docs | Pass | Changed fixture suites and every owning analyzer passed; dependency resolution succeeded for the client, bridge and linter workspaces; documentation link and source-reference validation is clean across all 25 guides. |

## Cleanup

The live pass used dev slot 1 with its own data directory and debug port. Its
scratch project under `/tmp` and both smoke sessions were deleted through the
product delete route, the project was hidden, the scratch directory removed, the
bridge stopped and its port released, and the slot's simulator shut down without
touching any other device. The desktop app instance launched for the attempt was
quit. No user data, no other slot, and no other session's simulator was touched.
No runtime was installed.

## Retirement status

Eight rows pass. Five are `Partial`: their automated coverage passed and a
live, desktop, device or packaged portion remains unexecuted.

The plan's rule keeps it active while required coverage is missing unless the
user explicitly accepts a reduced matrix. That acceptance was given on
2026-09-06 and is recorded in [PLAN.md](../PLAN.md), which enumerates the
coverage retired unexecuted. The plan was therefore moved to
`.plan/completed/periodic-cleanup/` on the strength of this record plus that
acceptance, not on this run alone.
