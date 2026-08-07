# Read-Only Archiving: Tracker

## Current State

- **Plan slug:** `read-only-archiving`
- **Implementation base:** `origin/main` at `354c61c1`
- **Series state:** Step 3/4 in PR
- **Current step:** 3/4
- **Plan PR:** [#765](https://github.com/sesori-ai/sesori_apps_monorepo/pull/765) merged
- **Relationship:** prerequisite of `internal-chat-history`; that series does
  not start until this one has fully merged.
- **Next action:** merge step 3/4, then start step 4/4.

## Delivery Steps

| Done | Step | Exact PR title | State |
|---|---|---|---|
| [x] | 1/4 | `🌱 [read-only-archiving] Raise plan [step 1/4]` | [PR #765](https://github.com/sesori-ai/sesori_apps_monorepo/pull/765) merged |
| [x] | 2/4 | `⚙️ [read-only-archiving] Reject unarchive and delete restore machinery [step 2/4]` | [PR #767](https://github.com/sesori-ai/sesori_apps_monorepo/pull/767) merged |
| [ ] | 3/4 | `⚙️ [read-only-archiving] Enforce read-only archived sessions [step 3/4]` | in PR |
| [ ] | 4/4 | `🌱 [read-only-archiving] Retire plan [step 4/4]` | pending |

## Execution Rules

- Merge in numeric order; each PR must remain independently valid at its own
  base.
- If step 3 trends past the 1,500-line soft cap it splits at the
  bridge/client boundary and the series total is restated before the first
  affected PR opens.
- Run focused tests, the owning package's tests, and the analyzer for each
  implementation step; run `architecture-implementation-review` (sub-agent)
  for steps 2 and 3.

## Verification Log

- 2026-08-07 (step 3/4) — `bridge/app`: analyzer clean, `dart test test/bridge`
  1360 passing. `client/module_core`: analyzer clean, `dart test` 1005 passing.
  `client/app`: analyzer clean, `flutter test` 914 passing. Diff ~1.2k lines, so
  the bridge/client split contingency was not needed.

- 2026-08-07 (step 2/4) — `bridge/app`: `dart analyze --fatal-infos .` clean,
  `dart test` 2430 passing. `shared/sesori_shared`: `dart analyze
  --fatal-infos .` clean, `dart test` 364 passing.

## Findings And Plan Deltas

- 2026-08-07 (step 3/4) — the archived-rejection 409 is mapped once in
  `RequestHandlerBase.handleInternal`, not per handler, so every current and
  future gated route answers identically.
- 2026-08-07 (step 3/4) — archiving now always confirms. The previous
  no-worktree bypass skipped the sheet entirely, which is unacceptable for a
  permanent action; the sheet simply offers no cleanup checkboxes there.
- 2026-08-07 (step 3/4) — archived session detail reuses the existing
  `SessionDetailLoadedView.readOnly` variant rather than adding a parallel
  presentation, plus an archived notice and suppressed pending banners/modals.
- 2026-08-07 (step 3/4) — the plan's step-3 emoji was `🌿`; the actual diff spans
  bridge services, routing, three client modules, l10n, and presentation, so the
  PR ships as `⚙️`.

- 2026-08-07 (step 2/4) — `ArchivedSessionValidator.requireNotArchived` takes
  only `sessionId`. It reads `SessionRepository.getStoredSession`, which is a
  durable catalog read and needs no `SessionOperation` for plugin routing;
  passing one would have been unused ceremony.
- 2026-08-07 (step 2/4) — an unknown session passes the validator so the
  caller keeps owning the 404 decision (the lifecycle service already resolves
  the stored session before consulting it).
