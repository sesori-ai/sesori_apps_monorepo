# Pi And Oh My Pi Harness Support: Tracker

## Current State

- **Plan slug:** `pi-harness`
- **Implementation base:** current `origin/main` with Step 15 merged
- **Series state:** Step 18/21 ready to raise
- **Current step:** 18/21, Pi and OMP registration implemented
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/811
- **Step 2 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/819
- **Step 3 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/820
- **Step 4 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/829
- **Step 5 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/832
- **Step 6 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/838
- **Step 7 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/846
- **Prerequisite PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/857
- **Step 8 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/862
- **Step 9 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/866
- **Step 10 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/884
- **Step 11 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/892
- **Step 12 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/905
- **Step 13 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/910
- **Step 14 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/914
- **Step 15 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/920
- **Step 16 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/925
- **Step 17 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/963
- **Next action:** raise Step 18 PR and monitor it

## Locked Decisions

`PLAN.md` is canonical. Execution must not reopen the confirmed Pi target,
native Pi permissions, normal Pi data, local login, always-`--approve` Pi
project trust, terminal handoff, per-session Pi residency, full-package Pi
install, OpenCode default, or no-new-analytics decisions without the user.

The 2026-08-11 expansion also locks `can1357/oh-my-pi` as a separate `omp`
backend over ACP v1, no Pi-family shared package, inherited normal OMP
profile/config, preserved OMP approval mode, local OMP login, and official bare
binary install. `OMP_PROTOCOL.md` records the supporting evidence.

## External Dependencies

- PR #857 merged archive package-directory placement and generalized
  `RuntimeVersion`; Steps 8 and 17 consume those shared primitives.
- OMP Step 8 builds direct-binary assets into the existing verified installer
  rather than creating a parallel installer.
- Joint Step 18 waits for any outstanding Claude activation ownership and
  preserves every merged identity, registry, package, CI, and brand entry.

## Delivery Steps

| Done | Step | Exact PR title | Target | State |
|---|---|---|---:|---|
| [x] | 1/21 | `🌱 [pi-harness] docs: plan Pi harness support [step 1/21]` | 1,400-1,500 (recorded overage) | Merged as PR #811; title normalized |
| [x] | 2/21 | `⚙️ [pi-harness] feat(pi): scaffold the protocol package [step 2/21]` | 900-1,300 | Merged as PR #819; title normalized |
| [x] | 3/21 | `🚧 [pi-harness] feat(pi): add the JSONL RPC transport [step 3/21]` | 1,200-1,500 (recorded overage) | Merged as PR #820; title normalized |
| [x] | 4/21 | `🌱 [pi-harness] docs: expand the plan to Oh My Pi [step 4/21]` | 1,500-1,600 (recorded overage) | Merged as PR #829 |
| [x] | 5/21 | `⚙️ [pi-harness] feat(acp): bridge form elicitations [step 5/21]` | 900-1,300 (recorded overage) | Merged as PR #832 |
| [x] | 6/21 | `⚙️ [pi-harness] feat(omp): add the ACP plugin core [step 6/21]` | 900-1,300 | Merged as PR #838 |
| [x] | 7/21 | `🚧 [pi-harness] feat(omp): expose options and persisted cleanup [step 7/21]` | 1,100-1,500 (recorded overage) | Merged as PR #846 |
| [x] | 8/21 | `🚧 [pi-harness] feat(runtime): install direct binary assets [step 8/21]` | 900-1,300 | Merged as PR #862; dependency merged as PR #857 |
| [x] | 9/21 | `🚧 [pi-harness] feat(omp): add managed runtime and lifecycle [step 9/21]` | 1,000-1,400 | Merged as PR #866 |
| [x] | 10/21 | `🚧 [pi-harness] feat(pi): enumerate persisted sessions [step 10/21]` | 1,000-1,400 (recorded overage) | Merged as PR #884 |
| [x] | 11/21 | `⚙️ [pi-harness] feat(pi): replay Pi session history [step 11/21]` | 1,100-1,500 (recorded overage) | Merged as PR #892 |
| [x] | 12/21 | `🚧 [pi-harness] feat(pi): map live messages and tools [step 12/21]` | 1,200-1,500 (recorded overage) | Merged as PR #905 |
| [x] | 13/21 | `⚙️ [pi-harness] feat(pi): bridge extension dialogs [step 13/21]` | 900-1,300 | Merged as PR #910 |
| [x] | 14/21 | `🚧 [pi-harness] feat(pi): manage session residency and turns [step 14/21]` | 1,200-1,500 (recorded overage) | Merged as PR #914 |
| [x] | 15/21 | `⚙️ [pi-harness] feat(pi): expose models and commands [step 15/21]` | 900-1,300 | Merged as PR #920 |
| [x] | 16/21 | `🚧 [pi-harness] feat(pi): implement the plugin API [step 16/21]` | 1,100-1,500 (recorded slight overage) | Merged as PR #925 |
| [x] | 17/21 | `🚧 [pi-harness] feat(pi): add managed runtime and lifecycle [step 17/21]` | 1,100-1,500 | Merged as PR #963 |
| [x] | 18/21 | `⚙️ [pi-harness] feat(bridge): register Pi and OMP [step 18/21]` | 800-1,200 (over-estimate) | Merged as PR #967 |
| [ ] | 19/21 | `🌿 [pi-harness] feat(client): add Pi and OMP branding and guidance [step 19/21]` | 500-900 (over-estimate) | Open as PR #973 |
| [ ] | 20/21 | `⚙️ [pi-harness] test(harness): verify Pi and OMP integration [step 20/21]` | 300-700 | Not started |
| [ ] | 21/21 | `🌱 [pi-harness] docs: retire the Pi and OMP harness plan [step 21/21]` | 50-200 | Not started |

## Working Rules

- One series implementation PR is open at a time; every PR targets `main`.
- Merge in numeric order and merge current `origin/main` before opening each
  step so concurrent Claude/runtime work is preserved.
- Steps 1-3 remain the already-merged Pi foundation. Step 4 changes the fixed
  total because the user added OMP after those merges; their PR titles were
  normalized to `/21` when the Step 4 PR opened.
- Count additions plus deletions from the merge base, including generated code
  and tests; split coherently or record an unavoidable overage.
- Generated outputs are regenerated, never hand-edited.
- Production Steps 2-3 and 5-19 run focused/full owning-package tests, fatal
  analysis, diff checks, and architecture implementation review.
- Steps 18-19 validate touched client/packages and assets. Step 20 validates both
  live product paths. Steps 1, 4, and 21 are documentation-only.
- Every PR body uses real multiline Markdown via `--body-file` and includes all
  required review sections.
- Start PR monitoring after every PR is opened.

## Plan Review

- 2026-08-10: initial Pi architecture draft rejected; six ownership, layering,
  editor, attachment, and ID corrections applied without re-review.
- 2026-08-11: Pi toast delta rejected one effect-identity gap; monotonic show
  sequence applied without re-review.
- 2026-08-11: Pi/OMP architecture revision review accepted the core boundary
  and rejected four snapshot/service ownership, cubit-placement, and overage
  documentation gaps. All four were corrected without re-review.

## Verification Log

### Step 1/21

- Architecture reviews: initial draft and toast delta rejected; all seven
  findings applied without re-review.
- Upstream Pi repository/tag, RPC/session docs, and all six release digests
  match.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.
- Diff: +1,527/-0 = 1,527 changed lines; generated lines: 0; tests run: 0.
- Recorded overage: final review gaps belong in the canonical initial plan and
  cannot form an independently valid implementation PR.
- Dart/Flutter suites: not run for this documentation-only step.
- Plan content through `b65b19f2`; reproduce from PR #811.

### Step 2/21

- Rechecked the latest stable Pi release on 2026-08-11; `v0.84.1` remained
  current.
- `dart pub get` from `bridge/`: pass.
- `dart test` from `bridge/sesori_plugin_pi/`: pass, 10 tests.
- `dart analyze --fatal-infos` from `bridge/sesori_plugin_pi/`: pass.
- Architecture implementation review rejected duplicate executable-name
  ownership on `PiLaunchSpec`; the resolver was removed so Step 17's runtime
  manifest remains the sole owner. No re-review required after applying it.
- Diff: +338/-8 = 346 changed lines; generated lines: 0; tests run: 10.
- No user-visible, database, or persisted-data change.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.

### Step 3/21

- `dart pub get` from `bridge/`: pass.
- `dart test` from `bridge/sesori_plugin_pi/`: pass, 65 tests.
- `dart analyze --fatal-infos` from `bridge/sesori_plugin_pi/`: pass.
- Architecture implementation review: approved with no findings.
- Diff: +2,948/-17 = 2,965 changed lines; generated lines: 0; tests run: 65.
- Recorded overage: the strict framer, complete sealed discriminator boundary,
  process lifecycle, and failure/backpressure tests are one coherent transport
  seam; splitting it would publish an untyped or unverified client.
- No user-visible, database, or persisted-data change.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.

### Step 4/21

- Verified canonical OMP repository/package/tag/commit and MIT license.
- Verified all seven OMP executable assets and published SHA-256 values; the
  official macOS arm64 binary matched and reported `omp/17.2.13`.
- Compared Pi and OMP launch flags, RPC framing/methods, ACP, sessions, config,
  auth, permissions, profiles, storage, and runtime source at the exact tags.
- Live isolated OMP ACP v1 probe passed initialize, `authenticate(agent)`,
  unfiltered/scoped `session/list`, `session/new`, command/title updates, and the
  expected privacy-sensitive no-model failure shape.
- Selected separate Pi RPC and OMP-over-ACP packages; rejected a Pi-family base
  and duplicate OMP RPC implementation.
- Architecture plan review rejected four documentation gaps; all were applied
  without re-review. PR review then found one sessionless-form correlation gap,
  three layer-ownership gaps, and a duplicated stale tracker header; all were
  corrected with OMP-only process-wide prompt serialization, explicit
  API/repository/service delegation, and the PR state. A second PR pass found a
  stale package map, process-global commands in a project-scoped service, and a
  false not-found result after capped cleanup pagination; all were corrected in
  the plan. A third pass found fail-open selection, replaying cleanup, unspecified
  libc-probe ownership, a cancellation/close race, and guidance after activation;
  all were corrected. The OMP-over-ACP boundary, separate packages, direct
  runtime, dependencies, compatibility, and fixed ordering remain unchanged.
  A fourth pass aligned resident-session concurrency, configured-model default,
  the connection-scoped selection repository, empty-session recovery, layered
  libc resolution, and repeated-toast identity. Steps 18-19 still make minimum
  safety guidance atomic with registration.
- Recorded overage: the revised architecture, exact 21-step tracker, and new
  researched OMP protocol record are one implementation contract after a
  mid-series requirement change; separating the evidence would leave the plan
  non-self-contained.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.
- Diff: +1,327/-378 = 1,705 changed lines; generated lines: 0; tests run: 0.
- Dart/Flutter suites: not run for this documentation-only step.

### Step 5/21

- Added standard ACP form elicitation for string, string-enum, and boolean
  properties with typed accept, decline, cancel, privacy-safe unsupported
  handling, and capability opt-in; URL elicitation and terminal auth stay absent.
- Added the connection-scoped session-config repository, opt-in process-wide
  prompt lane, fail-closed selection policy with bound empty-session recovery,
  and privacy-safe post-dispatch failure hook. Cursor keeps existing defaults.
- Added capability-aware `session/close`: active target work is cancelled and
  awaited before close, while queued work behind another process-wide turn does
  not block deletion. Timeout preserves retryable local state.
- Updated Cursor consumers in lockstep and regression contracts for forms and
  close-capable deletion.
- `dart analyze --fatal-infos` from `bridge/sesori_plugin_acp/` and
  `bridge/sesori_plugin_cursor/`: pass.
- `dart test` from `bridge/sesori_plugin_acp/`: pass, 240 tests.
- `dart test` from `bridge/sesori_plugin_cursor/`: pass, 126 tests.
- Architecture implementation review rejected three duplicated connection/lane
  ownership and target-settlement gaps; all were corrected. Second review:
  approved with no findings.
- No database, persisted-data, client/bridge wire-contract, or client-UI change. Existing
  Cursor selection and elicitation advertisement remain unchanged.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.
- Diff: +1,304/-99 = 1,403 changed lines; generated lines: 0; tests run: 366.
- Recorded overage: review fixes for required-property validation, malformed
  session identifiers, exact enum values, bounded labels, stack preservation,
  and the regression contract belong to the same ACP form/close seam.

### Step 6/21

- Added the app-invisible `sesori_plugin_omp` package over `AcpPlugin`, with the
  `omp acp` launch contract, inherited environment/configuration, local `agent`
  authentication, form elicitation, process-wide prompts, fail-closed selection,
  and privacy-safe local `/login` guidance for OMP's demonstrated no-model error.
- Added workspace, Makefile, CI, architecture/module documentation, and
  dependency-update inventory entries without registering OMP in bridge `app`.
- `dart pub get` from `bridge/sesori_plugin_omp/`: pass.
- `dart analyze --fatal-infos` from `bridge/sesori_plugin_omp/`: pass.
- `dart test` from `bridge/sesori_plugin_omp/`: pass, 11 tests.
- Architecture implementation review rejected an empty event-mapper subclass,
  consumerless testing re-export, and premature foundation dependency; all were
  removed. Second review: approved with no findings.
- No user-visible, database, persisted-data, client/bridge wire-contract, or
  client-UI change; app registration remains Step 18.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.
- Diff: +666/-12 = 678 changed lines; generated lines: 0; tests run: 11.

### Step 7/21

- Added OMP-owned bounded ACP leases, scratch `--session-dir` catalog probes,
  mapped repositories, coherent normalized-project trackers, and options and
  persisted-cleanup services.
- Project options preserve exact slash-containing model values, the configured
  pre-sweep default, model-specific thinking variants, modes, and project-local
  command snapshots. Rejected or partially applied config writes fail before
  prompt dispatch.
- Persisted cleanup exhausts opaque ACP pagination before idempotent not-found,
  uses global-ID resume after a truncated scan, invokes `/session delete`, then
  closes and settles the isolated lease.
- `dart pub get` from `bridge/`: pass.
- `dart analyze --fatal-infos` from `bridge/sesori_plugin_omp/` and
  `bridge/sesori_plugin_acp/`: pass.
- `dart test` from `bridge/sesori_plugin_omp/`: pass, 30 tests.
- `dart test` from `bridge/sesori_plugin_acp/`: pass, 240 tests.
- `dart test` from `bridge/sesori_plugin_cursor/`: pass, 126 tests.
- Architecture implementation review rejected raw ACP results crossing the OMP
  repository boundary; repositories now own transport mapping. Second review:
  approved with no findings.
- No user-visible, database, client/bridge wire-contract, or client-UI change;
  OMP persisted artifacts are removed only for already tombstoned sessions.
- `git diff --check`: pass.
- Diff: +2,324/-28 = 2,352 changed lines; generated lines: 0; tests run: 396.
- Recorded overage: the planned catalog/options and persisted-cleanup layers,
  isolated ACP lifecycle, and focused tests form one coherent Step 7 boundary;
  splitting would publish an incomplete plugin contract.

### Step 8/21

- Modeled runtime release artifacts as sealed archive and direct-binary variants;
  archive-only format, member, and layout fields no longer create impossible
  direct-binary states.
- Extended the existing verified installer to place bare executables without
  extraction while preserving checksum verification, atomic rename, Unix chmod,
  sentinel-last adoption, managed version probing, and stale-version sweeping.
- Migrated OpenCode, Codex, and Cursor archive manifests and tests in lockstep.
- Direct-binary tests cover placement, no extraction, Unix chmod through the
  shared path, Windows `.exe` naming, checksum failure, cancellation, stale
  staging cleanup, probe, and sweep; archive binary/package behavior remains covered.
- `dart test` and `dart analyze --fatal-infos` from `sesori_plugin_runtime`,
  `sesori_plugin_opencode`, `sesori_plugin_codex`, and `sesori_plugin_cursor`: pass
  (130 + 421 + 361 + 134 = 1,046 tests).
- Architecture implementation review: approved with no findings.
- No user-visible, database, persisted-data, client/bridge wire-contract, or
  client-UI change; OMP remains app-invisible until Step 18.
- `git diff --check`: pass.
- Diff: +238/-113 = 351 changed lines; generated lines: 0; tests run: 1,046.

### Step 9/21

- Added `OmpRuntimeManifest` at `v17.2.13` with seven official direct assets,
  `omp/<semver>` parsing, normalized managed executable naming, and explicit
  unsupported Windows arm64 behavior.
- Added bounded Alpine-marker/`ldd` libc evidence through OMP-owned API,
  repository, and service layers, plus the smallest async asset-resolver seam in
  `ManagedRuntimeInstallService`; OpenCode, Codex, Cursor, and runtime tests were
  updated in lockstep.
- Added app-invisible `OmpPluginDescriptor` runtime precedence, setup/install,
  eager ACP connection, degraded recovery, abort rollback, shutdown, and host
  environment preservation using `AcpBridgePlugin` directly.
- Refreshed runtime regression coverage and the `update-backend-runtimes` skill.
  OMP remains absent from app dependencies and `knownPlugins` until Step 18.
- `dart pub get` from `bridge/`: pass.
- `dart test` and `dart analyze --fatal-infos` from `sesori_plugin_omp`: pass,
  49 tests.
- `dart test` and `dart analyze --fatal-infos` from `sesori_plugin_runtime`:
  pass, 131 tests.
- Focused descriptor tests plus fatal analysis from OpenCode, Codex, and Cursor:
  pass; final fatal analysis also passes in all three packages.
- Official release verification: all seven GitHub digests match
  `SHA256SUMS.txt`; macOS arm64 digest and `omp/17.2.13` pass. Shared managed
  installer download/checksum/chmod/version/sentinel path passes in disposable
  state.
- Isolated official ACP probe passes v1 `initialize`, `authenticate(agent)`,
  empty `session/list`, `session/new`, `session/load`, `/session delete` with
  `end_turn`, and `session/close`; normal user profile remains untouched.
- Linux glibc/musl and Windows runtime execution were not available locally;
  mappings and Alpine/`ldd` selection are covered by focused tests.
- Architecture implementation review found split Linux asset-selection
  authority and nullable libc evidence combinations. The implementation now
  uses one async Linux selector, a separate pure support query, and sealed
  Alpine/`ldd` evidence variants; the second pass confirmed the evidence fix
  and identified one stale capability call site, which was corrected.
- No user-visible, database, persisted-data, client/bridge wire-contract, or
  client-UI change.
- `git diff --check`: pass.
- Step 9 implementation and review-fix diff `88059e200...9cd87d646`:
  +1,317/-17 = 1,334 changed lines; generated lines: 0; tests run: 180
  full-suite tests plus 41 focused descriptor tests. Later commits only record
  this measurement.

### Step 10/21

- Added generated session-header, `session_info`, and settings DTOs plus an
  isolate-backed `PiSessionStorageApi` that discovers inherited environment,
  configured, default, and bridge-known roots without reading `HOME` directly.
- Added a bounded metadata-only JSONL scanner: transcript records are discarded
  without decoding, metadata records and external lineage headers are byte
  bounded, physical symlink aliases deduplicate, and only exact resolved file
  paths remain available for later resume/history operations.
- Added `PiSessionCatalogRepository` mapping for normalized derived projects,
  explicit latest titles, file activity times, parent IDs, pagination, direct
  children, ID lookup, and lazy bridge attribution retained as future scan roots.
- Focused coverage includes malformed/half-written/oversized records, malformed
  title records, title clears, root precedence/deduplication, duplicate IDs,
  deleted cwd, external ancestry and its bounds, symlink aliases/loops, settings
  fallback, privacy-safe diagnostics, and a structural real-root scan.
- `dart pub get`, `dart run build_runner build`, `dart test` (94 tests),
  `dart analyze --fatal-infos`, and `git diff --check`: pass.
- The pinned Dart formatter crashes on primary-constructor enums in
  `pi_session_storage_api.dart`; all other changed hand-written Dart files format
  cleanly, and fatal analysis passes for the unformatted-by-tool scanner file.
- No client/bridge wire-contract, database, or client-UI change; Pi remains
  app-invisible until Step 18. Existing Pi JSONL files are read but not mutated.
- Architecture implementation review: approved with no findings.
- Diff: +2,226/-8 = 2,234 changed lines; generated lines: 351; tests run: 94.
- Recorded overage: root discovery, bounded privacy-sensitive scanning, lineage,
  codegen, and focused tests form one catalog seam; splitting would publish an
  incomplete resolver or mapping contract.

### Step 11/21

- Added RPC-first `get_entries` history replay with active-branch traversal,
  deterministic live-compatible identities, visible compaction cards, tool
  result correlation, and bounded text/image/content mapping.
- Added streamed read-only JSONL fallback only for the exact pinned no-model
  startup diagnostic. Layer 2 applies v1 linear IDs/parents, v2 `hookMessage`
  conversion, and last-valid-entry leaf selection without mutating Pi files.
- Added an exact persisted authored-text codec so cold replay strips only
  plugin-proven execution context; external unmarked Pi text remains visible.
- Privacy-safe remote failures omit paths, transcript payloads, summaries, raw
  assistant errors, and process details while local logs retain causes, stacks,
  and actionable resolved paths.
- `dart pub get`, `dart run build_runner build`, `dart test` (137 tests),
  `dart analyze --fatal-infos`, and `git diff --check`: pass.
- No client/bridge wire-contract, database, persisted-data mutation, analytics,
  or client-UI change; Pi remains app-invisible until Step 18.
- Architecture implementation review findings on internal DTO seams, injected
  plugin identity, and original local file-read causes were applied.
- Diff from merge base after review feedback: +7,360/-21 = 7,381 changed
  lines; generated lines: 4,268; tests run: 137.
- Recorded overage: generated closed history unions, RPC/file normalization,
  privacy-safe mapping, and focused regression tests are one replay seam;
  splitting would publish incomplete history or live-parity contracts.

### Step 12/21

- Added `PiEventDispatcher` and `PiToolTracker` for content-index text/reasoning
  streaming, authoritative assistant finals, pending/running/terminal tools,
  cumulative output replacement, retry/status/compaction events, edit/write
  diff invalidation, and `agent_settled` completion.
- Shared repository-owned identity hydration keeps resumed live IDs aligned with
  replay, including equal-timestamp assistants and prior compactions. Final
  reconciliation removes provisional parts absent from the authoritative final.
- Reused canonical replay mapping for assistant envelopes, bounded tool results,
  unfinished failed tools, and visible compaction cards; raw Pi payload decoding
  remains below the Layer-3 dispatcher.
- `dart test` (160 tests), `dart analyze --fatal-infos`, and
  `git diff --check`: pass.
- Architecture implementation review ran twice. The user approved applying the
  remaining second-pass findings without a third review; identity hydration,
  stale-part reconciliation, tracker placement, and decoding ownership were
  corrected.
- No user-visible, database, persisted-data mutation, analytics, or client-UI
  change; Pi remains app-invisible until Step 18.
- Diff after review feedback: +2,035/-146 = 2,181 changed lines;
  generated lines: 0; tests run: 160.
- Recorded overage: review fixes for transactional identity hydration,
  concurrent live allocations, overlapping-read ordering, and active-branch
  rebasing, authoritative part ordering/omission, direct bash/custom and
  top-level custom-entry and user-final parity, diagnostic context,
  malformed-final/tool cleanup, retry-aware compaction/status recovery,
  tracker package alignment, and the pre-residency hydration invariant complete
  the same live-mapping seam; splitting them would preserve known replay
  divergence or diagnostic gaps.

### Step 13/21

- Added `PiExtensionUiTracker` and `PiExtensionUiService` for select, confirm,
  input, and editor questions; exact value/confirmation/cancellation replies;
  bounded editor prefill and notifications; and explicit decorative-UI
  degradation.
- Pending dialogs are indexed by owner, top imported display root, and normalized
  owning project. Upstream timeouts retire mirrored cards, the plugin owns editor
  expiry, and owner generation fencing prevents abort/replacement cleanup from
  racing a catalog lookup and recreating stale state.
- Response sending remains an injected operation until Step 14 owns resident Pi
  clients. The user explicitly approved that temporary seam after architecture
  review; answer translation remains service-owned and notification severity
  stays typed. Owner cleanup and disposal cancel process-local dialogs and emit
  typed rejection lifecycle events; Pi permissions remain unsupported.
- Review fixes cancel dialogs when scope resolution fails, count catalog lookup
  time against upstream expiry, retire failed writes, accept replies from the
  display root, bound rune allocation, and keep pending-question mapping single.
- `dart test` (170 tests), `dart analyze --fatal-infos`, and
  `git diff --check`: pass.
- No current user-visible, database, persisted-data, analytics, or registered
  plugin impact; Pi remains app-invisible until Step 18.
- Diff: +1,003/-7 = 1,010 changed lines; generated lines: 0; tests run: 170.

### Step 14/21

- Added persistent pending-new markers, secure caller-owned IDs, one
  generation-fenced resident RPC client per active session, replay hydration
  before frame attachment, merged tagged frame/exit streams, and resident or
  transient history/rename leases.
- Added per-session prompt lanes with immediate admission, selection-before-
  prompt ordering, same-session FIFO and cross-session concurrency, dialog-first
  command acceptance, correlated response/event settlement, no-run state
  barriers, failed-response/exit settlement, abort teardown, idle reap, and
  idempotent disposal.
- Added strict bounded inline image validation and visible privacy-safe rejection
  of paths, URLs, non-image data, malformed base64, and oversized collections.
- Architecture implementation review approved direct resident-repository
  response ownership. Validated PR review fixes then added CR/LF-safe pending
  markers, pre-start best-effort stale-marker cleanup, connecting-client and
  globally monotonic generation fencing, generation-safe extension dialogs,
  exact slash-command dispatch with privacy-safe presentation, ambiguous-timeout
  teardown with old-dialog retirement, and disposal waiting for active idle-reap
  teardown.
- Full package tests pass (211 tests); fatal analysis and diff checks pass. The
  pinned formatter still crashes on the pre-existing Dart 3.13
  primary-constructor enum in `pi_session_storage_api.dart`; every other changed
  Dart file formats cleanly.
- No generated files, database schema, client/bridge wire contract, analytics,
  or registered plugin change. Pi composition/catalog exposure remain Steps
  15-16; Pi remains app-invisible until Step 18. Cold replay cannot recover
  `userVisibleArguments` from Pi's persisted raw command without new persistence,
  so cold replay conservatively displays only the slash-command token for both
  API commands and manually typed slash prompts, never hidden raw arguments;
  live API-command presentation retains exact `userVisibleArguments`.
- Diff: +3,202/-101 = 3,303 changed lines; generated lines: 0; tests run: 211.
  Review-fix working-tree delta excluding this tracker evidence: +586/-85 =
  671 changed lines. Recorded overage:
  persistence, residency, replay hydration, turn settlement, attachment
  validation, and focused concurrency/lifecycle tests form one required Step 14
  seam; splitting would leave resident processes without their owning lane or
  required fencing evidence.

### Step 15/21

- Added generated Pi catalog DTOs plus exact `--mode rpc --no-session --approve`
  launch support. Project-scoped probes capture initial model identity, dedupe
  provider/model IDs without splitting, hydrate bounded reasoning variants,
  map command sources, cancel probe dialogs, preserve diagnostics, and always
  tear down their single process lease.
- Added normalized-project `PiCatalogTracker` and `PiCatalogService` reuse,
  refresh, same-project coalescing, cross-project concurrency,
  complete/partial/failed classification, and last-good retention. Pi uses the
  backend-neutral discovery result and synthesizes one primary `pi` agent.
- Generated catalog outputs refreshed with package codegen. Focused catalog and
  launch tests pass (17 tests); full Pi package tests pass (222 tests); fatal
  analysis and `git diff --check` pass.
- Diff: +1,925/-17 = 1,942 changed lines; generated lines: 841; non-generated
  changed lines: 1,101, within the step estimate; tests run: 222.
- Formatter passes for the touched Dart files except the pinned formatter bug
  on the valid primary-constructor catalog enum. No shared image-capability
  field exists, so Pi image input support is parsed but not exposed through an
  invented backend-neutral field.
- No database, persisted-data, client/bridge wire-contract, analytics, or
  registered-plugin impact. Step 15 merged as PR #920.

### Step 16/21

- Added the coherent `PiPlugin` composition root over session catalogs,
  residency/turns, extension dialogs, project-scoped options, buffered events,
  health, active summaries, and idempotent ordered disposal. Every
  `BridgeDerivedProjectsPluginApi` and `PersistedSessionCleanupApi` operation is
  implemented; Pi remains unregistered until Step 18.
- Added lazy empty-prompt creation, parent-aware pending markers, exact
  rename/history/delete lookup, root-and-descendant lifecycle fencing, named-root
  physical deletion, question/toast mapping, permission degradation, selection
  validation, command acceptance, and cause-preserving failures.
- User-directed slimming removed the tombstone directory column, schema v14
  migration, and directory threading through the cleanup contract. Startup
  cleanup retries stay ID-only; Pi resolves via its normal directory scan and
  accepts a rare undiscoverable-cwd disk leak (tombstone still blocks
  re-import). Claude, Cursor, and OMP keep their unchanged contract.
- Architecture implementation review approved the coherent factory, repository
  boundaries, service lifecycle ownership, and repository-owned cleanup record.
- Pi package tests pass (236 tests) with fatal analysis. Focused app
  persistence/repository/cleanup/migration tests pass (120 tests); plugin
  interface (153), Cursor (31), OMP (18), and Claude (17) suites and fatal
  analysis pass. Codegen/schema generation and diff checks pass.
- No user-visible, analytics, registered-plugin, client/bridge wire, or
  database impact.
- Review fixes clear project-local pending
  markers after global-root deletion, preserve catalog failures as causes,
  resolve cross-project fork parents, await idle reaps during deletion, and emit
  deletion events only after physical deletion succeeds. Active summaries keep
  all active descendants grouped under the displayed root; filtering to direct
  children would omit active nested forks from the only root summary.
- Diff metrics stale after the user-directed cleanup slimming; refresh with
  final verification before merge.

### Step 17/21

- Added the semantic `PiRuntimeManifest` with a `0.84.1` PATH floor, exact
  `0.84.2` managed pin, all six official package-directory archives, and
  published SHA-256 digests.
- Added read-only PATH/managed resolution, setup inspection, explicit binary
  precedence, install capability and package installation, host-backed process
  spawning, lazy lifecycle status, work-state forwarding, active interruption,
  and ordered abort-safe shutdown. Pi remains unregistered until Step 18.
- Pi process launches inherit the bridge process environment, add only
  `PI_SKIP_VERSION_CHECK=1`, and retain `--approve` for every session and
  no-session RPC launch. Storage receives the full host environment separately
  so home and custom Pi roots remain discoverable without explicitly overriding
  `HOME` in child processes.
- Official `v0.84.2` macOS arm64 verification matched SHA-256
  `c996e888b7f7dce44bcf24f69176ac646c44139d3916bd49a6b28e5a8c5e3a65`,
  preserved the complete package tree, reported `0.84.2`, and returned a
  successful correlated no-session RPC `get_state` response.
- Initial architecture review rejected duplicate executable/identity ownership,
  data-free spawn variants, explicit `pi` ambiguity, and discarded shutdown
  budgets. The implementation now uses one plugin-local identity, manifest-owned
  fallback resolution, an enum spawn outcome, nullable option defaults that keep
  explicit `--pi-bin pi` authoritative, and caller-budgeted resident teardown.
  The second review found that API-first disposal and an already-running idle
  reap could still retain a longer timeout. Per user direction, the fix was
  completed without a third review: API disposal now chooses immediate teardown,
  lifecycle shutdown tightens in-flight RPC deadlines, and process ownership
  retains active reaps until the caller budget has been applied.
- Pi tests pass (255 tests) with fatal analysis after the post-merge sync with
  Step 16 (prompt-id dedupe). Shared runtime tests pass (132 tests) with fatal
  analysis; package-directory placement, checksum failure, abort, cleanup, and
  superseded-version behavior remain covered there. Diff checks pass.
- No user-visible, database, persisted-data, analytics, registered-plugin, or
  client/bridge wire impact. The backend-runtime update skill and runtime
  installation regression matrix now include Pi.
- Diff before tracker/plan evidence: +1,378/-72 = 1,450 changed lines; generated
  lines: 0; tests run: 387 automated package checks plus one live managed
  artifact/version/RPC probe.


### Step 18/21

- Added `Harness.pi` and `Harness.omp`, the `pi_plugin`/`omp_plugin` app
  dependencies, and both production descriptors to `plugin_registry.dart`.
  The registry list became `final List.unmodifiable` because both descriptors
  construct through non-const `production()` factories. OpenCode remains the
  preferred default; all merged entries are preserved.
- Added the backend-neutral `SseToastCubit` in `module_core` mapping
  `tui.toast.show` SSE events into sealed idle/show states with a monotonic
  sequence, so equal repeated guidance re-fires; textless toasts drop and
  unknown variants degrade to info. The mobile shell renders shows through
  `PregoPopupAlertPresenter` on the root navigator's overlay, reusing the
  design-system toast surface instead of a plain snackbar.
- README and the plugin-setup regression doc record Pi's always-`--approve`
  project-code trust, OMP's inherited approval policy, and local-only provider
  login before either backend is selectable.
- Registry exact-set fixtures updated; a new test pins every registered id to
  a built-in `Harness` identity. Toast cubit tests cover monotonic repeats,
  variant fallback, and empty-drop behavior.
- Architecture implementation review approved the commit with no findings.
- Verification: bridge app fatal analysis and full suite (2,674 tests), Pi
  (255) and OMP (51) suites, shared (409), module_core toast tests, and the
  mobile shell fatal analysis all pass after the post-merge sync with `main`.
- No database, persisted-data, or wire-contract change; the app now lists Pi
  and Oh My Pi as selectable harnesses once their setup is ready.
- Diff before tracker/plan evidence: +393/-10 = 403 changed lines; generated
  lines: 46 (one freezed state file).

### Step 19/21

- Step 18 merged as PR #967. Added official Pi light/dark SVG artwork and Oh My
  Pi's shared light/dark gradient mark to the client brand catalog, with stable
  `Pi` / `Oh My Pi` display-name cases; unknown plugin ids retain the existing
  raw-id and generic-plug fallback.
- Expanded README guidance for managed install and authoritative `--pi-bin` /
  `--omp-bin` overrides, inherited Pi/OMP profiles, local-only provider login,
  OMP's standard-ACP feature boundary, and the unsupported concurrent terminal
  handoff. The headline is scalable while intro, Bridge, and feature copy list
  and link every supported assistant for discoverability.
- Updated the plugin lifecycle regression contract for both brand identities.
  No obsolete client state, assets, or copy paths became removable beyond the
  replaced fixed-harness wording.
- Verification after rebasing onto the Step 18 merge: module_prego fatal
  analysis and all 209 tests pass; mobile app fatal analysis passes; all six
  linked assistant sites return HTTP 200; the gradient OMP mark renders in the
  iOS harness picker;
  `git diff --check $(git merge-base origin/main HEAD)..HEAD` passes.
- User-visible impact is limited to Pi/OMP branding and documentation. No
  database, persisted-data, wire-contract, or runtime behavior change.
- Product diff excluding this tracker evidence, measured with
  `git diff --numstat $(git merge-base origin/main HEAD)..HEAD -- .
  ':(exclude).plan/active/pi-harness/TRACKER.md'`: +122/-7 = 129 changed
  lines; generated lines: 0. This is well below the 500-900 estimate because
  Step 18 already absorbed the shared activation/notification prerequisites;
  this step reused the existing brand catalog and needed only localized assets,
  mappings, tests, and guidance. The original budget was an over-estimate.

## Findings And Plan Deltas

- Earlier reviews corrected Pi architecture/lifecycle and added rendered toasts,
  visible compaction, bounded scans, history fallback, project questions, and
  sequencing.
- 2026-08-11 pinned Pi source verification found generated unions for every
  transport variant would add thousands of unused lines. Step 3 therefore uses
  hand-written sealed transport variants and generated leaf DTOs.
- 2026-08-11 OMP research found that ancestry does not imply compatibility:
  OMP lacks Pi's caller-owned session flag and key RPC methods, while its ACP v1
  surface directly matches Sesori's existing ACP plugin.
- The requirement change adds a plan-revision step, standard ACP form/close
  work, a thin OMP ACP package, direct-binary runtime support, OMP lifecycle,
  and joint activation/verification. The fixed total changes from 15 to 21.
- OMP ACP intentionally degrades parent lineage, native rename, notify, URL
  elicitation, and RPC-only features rather than adding transcript scans or a
  second transport.
