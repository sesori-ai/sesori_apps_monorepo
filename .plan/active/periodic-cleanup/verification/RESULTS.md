# Periodic cleanup — recorded verification results

Executed for step 25 of [PLAN.md](../PLAN.md) against the branch head recorded
below. Each row of the plan's verification matrix is reported as `Pass`,
`Partial`, `Fail`, `Blocked`, or `Not run`, with the evidence that produced it.

## Execution context

| Field | Value |
| --- | --- |
| Commit | `2a20330dd9` (branch `periodic-cleanup-step-25`, on top of merged steps 1-24) |
| Host | macOS on Apple Silicon (single machine) |
| Bridge host | Same machine, headless bridge not started for this run |
| Client platforms | None exercised: no simulator, device, or desktop app run |
| Plugins | None started: no live backend, no network install |
| Accounts | None used; no account, relay, or provider credential was exercised |

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

## What was not executed

No live plugin, relay, packaged artifact, simulator, device, or provider account
was exercised in this run. Every matrix row whose complete boundary requires one
is therefore reported below as `Partial` — its automated portion passed and its
live portion is `Not run`, never silently converted to a pass.

## Per-row results

| Matrix row | Result | Evidence and gap |
| --- | --- | --- |
| Steps 2-3 — history/turns/connectivity | Partial | Automated cubit, buffer and history-mapper coverage passed inside the client and bridge suites above. Client end to end on macOS desktop and a mobile platform through a streaming backend: not run. |
| Steps 4/8 — projects/archiving | Pass | Real-SQLite repository, service, identity, ordering and route suites passed in the bridge suite. The row's boundary is a representative faithful plugin, which the suite provides. |
| Step 5 — creation and options | Pass | Real database fresh-install and schema-14 upgrade, discovery, malformed-JSON, invalidation, generation and path tests passed on a macOS SQLite host. The row declares fake plugin plus real DAO/repository/service as the full cache-policy boundary. |
| Steps 6-7 — turns/history/questions | Partial | Translator, status-variant, message, stable-id, terminal-handoff, child-routing and wire round-trip suites passed for every producing plugin. The headless-bridge smoke through a representative live backend: not run. |
| Step 9 — tools/connectivity | Pass | Dropped-category OpenCode mapping fixtures, Codex MCP suppression, both mapper suites and the client decoder regressions passed. The row's boundary is automated plus consumer inspection. |
| Step 10 — attachments/voice | Partial | Shared storage, temporary-directory cache/failure/retry, image-repository, retirement, atomic-replacement, concurrency, corruption and recording suites passed on macOS. Native directory binding smoke on macOS desktop, iOS and Android: not run, and the row states mock-only wiring cannot substitute. |
| Step 11 — rename | Pass | Both cubit rename suites and the shared RenameSheet behavior and widget tests passed; the shared module and both shells analyze clean. The row needs no live rename claim. |
| Step 12 — runtime installation | Partial | Runtime and all seven descriptor install/setup suites, manifest target mapping, checksum, failure, cancellation and client-closure coverage passed. Headless live installation on macOS arm64 for every managed-install consumer: not run. |
| Step 13 — installation/setup lifecycle | Partial | Provisioning and descriptor suites for all seven managed plugins passed, including both Codex/OpenCode cold-start success, failure, timeout, late-failure and abort paths and OpenCode's skipped wait. Headless inspection/provisioning for all seven and the live bounded cold-start smoke: not run. |
| Step 14 — worktree/Codex folds | Pass | Worktree collision, failure and fallback tests plus the Codex command, turn-retry and scanner suites passed, with the real Git fixture proving repository creation. The row states no live backend is needed. |
| Step 16 — shell composition | Partial | Both shell provider and screen tests and the fresh-cubit lifecycle assertions passed. Real navigation on macOS desktop and a mobile platform: not run. |
| Step 17 — account and onboarding | Partial | Real auth-owner tests with fake HTTP and secure storage passed, covering email and Apple completion, parse, non-2xx and empty failures, supersession, logout and persistence failure. Email client end to end on a mobile platform: not run. |
| Steps 15/18-24 — tests, tooling, docs | Pass | Changed fixture suites and every owning analyzer passed; dependency resolution succeeded for the client, bridge and linter workspaces; documentation link and source-reference validation is clean across all 25 guides. |

## Cleanup

This run created no session, project, worktree, account, or installed runtime,
and mutated no user data. Test suites own and remove their temporary directories.
No diagnostic residue was retained.

## Retirement status

Five rows pass. Eight are `Partial`: their automated coverage passed and their
live, device, or packaged portion was not run. Under the plan's own rule, missing
required coverage keeps the plan active, and reducing the matrix requires
explicit user acceptance recorded in `PLAN.md`. The plan therefore stays in
`.plan/active/` on the strength of this run alone.
