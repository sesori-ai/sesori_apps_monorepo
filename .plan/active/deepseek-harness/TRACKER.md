# DeepSeek Harness: Tracker

## Current State

- **Plan slug:** `deepseek-harness`
- **Plan status:** Step 5/15 PR open; Step 6/15 verified locally
- **Current repository:** `sesori-ai/sesori-deepseek-acp`
- **Current branch:** `deepseek-harness/step-6-catalogs-commands`
- **Current open PR:** [#4](https://github.com/sesori-ai/sesori-deepseek-acp/pull/4)
- **Next action:** merge Step 5, sync Step 6 to `main`, then publish Step 6
- **Implementation started:** yes
- **Retirement:** blocked until every required row in `PLAN.md` passes

## Fixed Delivery Sequence

| Done | Step | Repository | Exact PR title | Complexity | Soft line target | State |
|---|---|---|---|---|---:|---|
| [x] | 1/15 | apps monorepo | `🌱 [deepseek-harness] docs: plan DeepSeek Harness support [step 1/15]` | Trivial documentation, but architecture-bearing review | 1,500 | [PR #1036](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1036) merged |
| [x] | 2/15 | deepseek adapter | `⚙️ [deepseek-harness] feat(runtime): scaffold the DeepSeek ACP adapter [step 2/15]` | Moderate new transport/repository foundation | 1,000 | [PR #1](https://github.com/sesori-ai/sesori-deepseek-acp/pull/1) merged |
| [x] | 3/15 | deepseek adapter | `🚧 [deepseek-harness] feat(runtime): compose the DeepSeek coding runtime [step 3/15]` | Complex configuration, security, and lifecycle composition | 1,300 | [PR #2](https://github.com/sesori-ai/sesori-deepseek-acp/pull/2) merged |
| [x] | 4/15 | deepseek adapter | `🚧 [deepseek-harness] feat(runtime): add durable ACP sessions and replay [step 4/15]` | Complex persistence and live ownership | 1,450 | [PR #3](https://github.com/sesori-ai/sesori-deepseek-acp/pull/3) merged |
| [ ] | 5/15 | deepseek adapter | `🚧 [deepseek-harness] feat(runtime): stream DeepSeek turns and interactions [step 5/15]` | Complex concurrent event and interaction flow | 1,450 | [PR #4](https://github.com/sesori-ai/sesori-deepseek-acp/pull/4) open; CI passing |
| [ ] | 6/15 | deepseek adapter | `⚙️ [deepseek-harness] feat(runtime): expose DeepSeek catalogs and commands [step 6/15]` | Moderate option/command boundary | 1,200 | Local implementation verified; awaiting Step 5 merge |
| [ ] | 7/15 | apps monorepo | `⚙️ [deepseek-harness] feat(deepseek): scaffold the DeepSeek bridge plugin [step 7/15]` | Moderate new package and narrow ACP hooks | 1,250 | Pending Step 6 |
| [ ] | 8/15 | apps monorepo | `🚧 [deepseek-harness] feat(deepseek): map DeepSeek sessions and history [step 8/15]` | Complex replay and identity flow | 1,450 | Pending Step 7 |
| [ ] | 9/15 | apps monorepo | `🚧 [deepseek-harness] feat(deepseek): map DeepSeek turns and interactions [step 9/15]` | Complex events, questions, and permissions | 1,450 | Pending Step 8 |
| [ ] | 10/15 | apps monorepo | `⚙️ [deepseek-harness] feat(deepseek): expose options and lifecycle [step 10/15]` | Moderate plugin API and lifecycle composition | 1,350 | Pending Step 9 |
| [ ] | 11/15 | deepseek adapter | `🚧 [deepseek-harness] build(runtime): release the managed DeepSeek adapter [step 11/15]` | Complex supply chain and six-platform release | 1,300 | Pending Step 10 |
| [ ] | 12/15 | apps monorepo | `⚙️ [deepseek-harness] feat(deepseek): install the managed DeepSeek runtime [step 12/15]` | Moderate managed-runtime integration | 1,250 | Pending Step 11 |
| [ ] | 13/15 | apps monorepo | `⚙️ [deepseek-harness] feat(app): activate DeepSeek Harness [step 13/15]` | Moderate registry/client activation | 1,000 | Pending Step 12 |
| [ ] | 14/15 | apps monorepo | `🌱 [deepseek-harness] docs: document DeepSeek regression coverage [step 14/15]` | Straight documentation reconciliation | 600 | Pending Step 13 |
| [ ] | 15/15 | apps monorepo | `🌱 [deepseek-harness] docs: verify DeepSeek and retire the plan [step 15/15]` | Trivial evidence/retirement changes after a complex external verification run | 700 | Pending Step 14 |

The total and titles are fixed for the series. If implementation evidence
requires a split before a PR opens, update both plan and tracker first and
renumber every unopened title consistently. Do not silently exceed 1,500 lines.

## Locked Decisions

- One enhanced ACP runtime and one stdio connection; no parallel Web runtime.
- Runtime source/releases live in `sesori-ai/sesori-deepseek-acp`.
- Full `dsh-base` composition, not the limited stock ACP demo.
- Normal `DSH_HOME` is read for settings/credentials/skills; all Sesori session
  mutations live under plugin state.
- DeepSeek telemetry is forced off; sandbox defaults to workspace-write and
  approval defaults to ask.
- V1 supports only Sesori-owned DeepSeek sessions, not normal DeepSeek session
  import or attach.
- ACP carries common lifecycle/events; versioned DeepSeek extensions stay
  narrow and on the same connection.
- Provider/model selection ids are opaque. One primary DeepSeek agent is exposed.
- Persisted deletion remains unsupported upstream; Sesori purge/tombstone is
  authoritative for the product.
- Local provider setup only. No phone credential editor or backend-specific
  analytics.
- OpenCode remains preferred default; DeepSeek uses the generic icon in v1.

## Step 1 Checklist

- [x] Refresh Sesori `origin/main` and record exact base commit.
- [x] Refresh DeepSeek source/releases/npm package facts.
- [x] Inspect current ACP, managed runtime, registry, identity, client fallback,
  analytics, and regression seams.
- [x] Decide one-process runtime, state/config ownership, protocol extensions,
  packaging repository, feature degradation, and verification matrix.
- [x] Write `PLAN.md`, `TRACKER.md`, and `PROTOCOL.md`.
- [x] Run architecture plan review and apply valid findings.
- [x] Run Markdown/reference and `git diff --check` validation.
- [x] Inspect final Git status/diff/log; commit only the three plan files.
- [x] Push and open the exact Step 1 PR.

## Review Log

| Date | Review | Result | Changes |
|---|---|---|---|
| 2026-08-22 | Architecture plan review | Rejected draft with seven concrete findings | Clarified class composition/layers, moved DTO mapping to repositories, removed two unjustified Services, assigned the ACP live-client hook, fixed interaction ownership, made JSON Schema/corpus authoritative, and made Step 15 verification-only. Per repository rules, valid findings were applied without a second approval review. |
| 2026-08-23 | Step 4 architecture implementation review | Pass | Durable session ownership, persistence, and replay matched the planned one-process boundary. |
| 2026-08-23 | Step 5 architecture implementation review | Rejected first pass; passed second pass | Consolidated duplicate live/replay mappings into one event projector with thin delivery and collection sinks. |
| 2026-08-23 | Step 6 architecture implementation review | Rejected first pass; passed second pass | Changed cold rename from retained ACP ownership to one coordinated resume/rename/flush/notify/dispose transition. |

## Verification Log

### Step 1/15

- [x] `git diff --check`
- [x] Plan file/reference validation: 15 ordered steps/titles, 10 regression
  documents, current implementation base, balanced fences, and no stale
  catalog/history Service references
- [x] Architecture plan review; seven valid findings applied without re-review
- [x] Final PR changed-line count, including this tracker: 1,466 of the 1,500-line target
- [x] Commit `c40fbc4ad` pushed; PR #1036 opened against `main`

### Step 4/15

- [x] `npm run check`: 51 tests at final reviewed head
- [x] `npm ls --depth=0`; exact direct dependency closure
- [x] `npm audit --omit=dev`: 0 vulnerabilities
- [x] Architecture implementation review passed
- [x] PR #3 merged

### Step 5/15

- [x] `npm run check`: lint, typecheck, 66 tests, and build pass
- [x] `npm ls --depth=0`; exact direct dependency closure
- [x] `npm audit --omit=dev`: 0 vulnerabilities
- [x] Architecture implementation review passed after consolidating event projection
- [x] Changed-line count: 1,317 of the 1,450-line target
- [x] PR #4 opened; review fixes pushed; CI passing

### Step 6/15

- [x] `npm run check`: lint, typecheck, 69 tests, and build pass
- [x] `npm ls --depth=0`; exact direct dependency closure
- [x] `npm audit --omit=dev`: 0 vulnerabilities
- [x] Architecture implementation review passed after making cold rename temporary
- [x] Changed-line count: 669 of the 1,200-line target

Later implementation and live evidence is appended here by step. Never mark a
regression row passed without the boundary and matrix required by `PLAN.md`.
