# Pi And Oh My Pi Harness Support: Tracker

## Current State

- **Plan slug:** `pi-harness`
- **Implementation base:** `origin/main` at `ca550a7b`
- **Series state:** Step 4/21 plan revision in progress
- **Current step:** 4/21, expand the plan to Oh My Pi
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/811
- **Step 2 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/819
- **Step 3 PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/820
- **Step 4 PR:** pending
- **Next action:** validate and open Step 4

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

- Pi Step 17 strictly requires `RuntimeAssetLayout.packageDirectory`; the local
  `phone-harness-install-cursor` branch at `6054d7cd` also generalizes
  `RuntimeVersion`. Do not duplicate or cherry-pick those primitives.
- OMP Step 8 builds direct-binary assets on the merged package-directory/runtime
  variant model rather than creating a parallel installer.
- Joint Step 18 waits for any outstanding Claude activation ownership and
  preserves every merged identity, registry, package, CI, and brand entry.

## Delivery Steps

| Done | Step | Exact PR title | Target | State |
|---|---|---|---:|---|
| [x] | 1/21 | `🌱 [pi-harness] docs: plan Pi harness support [step 1/21]` | 1,400-1,500 (recorded overage) | Merged as PR #811; title normalized |
| [x] | 2/21 | `⚙️ [pi-harness] feat(pi): scaffold the protocol package [step 2/21]` | 900-1,300 | Merged as PR #819; title normalized |
| [x] | 3/21 | `🚧 [pi-harness] feat(pi): add the JSONL RPC transport [step 3/21]` | 1,200-1,500 (recorded overage) | Merged as PR #820; title normalized |
| [ ] | 4/21 | `🌱 [pi-harness] docs: expand the plan to Oh My Pi [step 4/21]` | 1,500-1,600 (recorded overage) | Open as PR #829 |
| [ ] | 5/21 | `⚙️ [pi-harness] feat(acp): bridge form elicitations [step 5/21]` | 900-1,300 | Not started |
| [ ] | 6/21 | `⚙️ [pi-harness] feat(omp): add the ACP plugin core [step 6/21]` | 900-1,300 | Not started |
| [ ] | 7/21 | `🚧 [pi-harness] feat(omp): expose options and persisted cleanup [step 7/21]` | 1,100-1,500 | Not started |
| [ ] | 8/21 | `🚧 [pi-harness] feat(runtime): install direct binary assets [step 8/21]` | 900-1,300 | Blocked on runtime dependency |
| [ ] | 9/21 | `🚧 [pi-harness] feat(omp): add managed runtime and lifecycle [step 9/21]` | 1,000-1,400 | Blocked on Step 8 |
| [ ] | 10/21 | `⚙️ [pi-harness] feat(pi): enumerate persisted sessions [step 10/21]` | 1,000-1,400 | Not started |
| [ ] | 11/21 | `⚙️ [pi-harness] feat(pi): replay Pi session history [step 11/21]` | 1,100-1,500 | Not started |
| [ ] | 12/21 | `🚧 [pi-harness] feat(pi): map live messages and tools [step 12/21]` | 1,200-1,500 | Not started |
| [ ] | 13/21 | `⚙️ [pi-harness] feat(pi): bridge extension dialogs [step 13/21]` | 900-1,300 | Not started |
| [ ] | 14/21 | `🚧 [pi-harness] feat(pi): manage session residency and turns [step 14/21]` | 1,200-1,500 | Not started |
| [ ] | 15/21 | `⚙️ [pi-harness] feat(pi): expose models and commands [step 15/21]` | 900-1,300 | Not started |
| [ ] | 16/21 | `🚧 [pi-harness] feat(pi): implement the plugin API [step 16/21]` | 1,100-1,500 | Not started |
| [ ] | 17/21 | `🚧 [pi-harness] feat(pi): add managed runtime and lifecycle [step 17/21]` | 1,100-1,500 | Blocked on package-directory runtime support |
| [ ] | 18/21 | `⚙️ [pi-harness] feat(bridge): register Pi and OMP [step 18/21]` | 350-650 | Not started |
| [ ] | 19/21 | `⚙️ [pi-harness] feat(client): add Pi and OMP branding and guidance [step 19/21]` | 800-1,200 | Not started |
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
- Step 19 validates touched client/package assets and tests. Step 20 validates
  both live product paths. Steps 1, 4, and 21 are documentation-only.
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
  without re-review. The OMP-over-ACP boundary, separate packages, scratch
  catalog, deletion flow, direct runtime, dependencies, compatibility, and
  sequencing received no findings.
- Recorded overage: the revised architecture, exact 21-step tracker, and new
  researched OMP protocol record are one implementation contract after a
  mid-series requirement change; separating the evidence would leave the plan
  non-self-contained.
- `git diff --check $(git merge-base origin/main HEAD)..HEAD`: pass.
- Diff: +1,210/-377 = 1,587 changed lines; generated lines: 0; tests run: 0.
- Dart/Flutter suites: not run for this documentation-only step.

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
