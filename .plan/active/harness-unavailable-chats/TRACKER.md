# Unavailable chat input-gating tracker

Authority: [PLAN.md](PLAN.md). User-approved scope: **input gating only**.
No queue recovery, submission retention, attachment storage or bridge protocol work.

| Step | Complexity | Deliverable | Status |
|---|---|---|---|
| 1/4 | 🌱 | Plan read-only unavailable chats | [PR #1366](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1366) merged |
| 2/4 | ⚙️ | Gate unavailable chats on both clients | [PR #1375](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1375) open; CI/review ongoing |
| 3/4 | 🌿 | Reconcile chat availability regressions | Not started |
| 4/4 | 🌿 | Verify read-only chats and retire plan | Not started |

The earlier six-step proposal was replaced before implementation after the user
explicitly rejected queue-recovery scope. Use the four exact titles in PLAN.md.
The user authorized implementation and, after background runner failures,
authorized direct execution without subagents. No dependencies may be installed.

## Evidence and review

- Confirmed prevention gap: chat actions do not consume harness management state.
- Earlier architecture review findings relevant to the smaller scope are applied:
  sole state coordinator, metadata-first loading and shared cubit composition.
- Recovery-related PR findings are superseded by the explicit user decision;
  no approved architecture verdict is claimed for the revised plan.
- The user approved the roughly 1,750-line step-2 cap exception, including
  generated code, tests and docs, without changing scope or the four-step total.
- Shared interaction projection, metadata-first loading, mutation guards,
  notice/dialog gating and both shell settings callbacks implemented. No bridge,
  database, protocol or queue-recovery changes.
- Focused verification: 457 distinct passing tests (276 core, 123 mobile,
  56 shared UI, 2 desktop). Final targeted recovery cases also pass after covering
  a failed content refresh followed by Retry. All four owning analyzers are clean;
  formatting and `git diff --check` pass.
- Commands: cached Dart 3.13.2 test runner with
  `--packages=../.dart_tool/package_config.json` from `client/module_core`, covering
  `test/cubits/session_detail`, load-service/calculator suites, state defaults and
  the session-activity analytics listener. Flutter 3.47.2 `test --no-pub` covered
  mobile session body/title/child navigation and adaptive route matrix; shared UI
  assistant card/file part/reasoning modal; desktop session detail.
- Freezed/DI generated through the cached build_runner entry point and existing
  package config, without package resolution. Localization: `flutter gen-l10n`.
  Analyzer command: `dart analyze --format machine` in each owning module.
- Test failures fixed: reload loading-state assumptions, obsolete metadata/catalog
  fallback expectations, management mock disposal and renamed mock invocation
  arguments. No remaining observed test failures.
- Architecture self-assessment: existing management owner and refresh fencing are
  reused; the cubit alone coordinates availability; presentation stays shared and
  shells supply navigation. Independent architecture review is unavailable due to
  background runner failures; no subagent approval is claimed.
- CI integration follow-up: merged current `main` and handled the unavailable
  state in its newly introduced abort child-status switch. Cold/live gate tests
  explicitly verify abort refusal without dispatch. The updated core session,
  load-service and calculator scope passes 270 cases; all four analyzers remain
  clean. Linux build validation is delegated to the next CI run.
- Review follow-up preserves local-only cancellation and transcripts when reload
  overlaps a block, retains/logs initial status failures, distinguishes content
  restoration failure, announces the notice to accessibility, and removes a dead
  retry branch. Focused rerun: 257 core session/calculator cases and 99 session-body
  widget cases pass; owning core/shared-UI analyzers are clean. Pagination remains
  guarded because store reads can backfill from the harness. These review fixes
  and their coverage bring the implementation diff to roughly 1,865 lines; no
  additional feature scope or recovery machinery was added.
- Further reload review: restored transcripts replay buffered session/global and
  deferred-part events; metadata refresh failure preserves already-loaded content
  and the current availability decision. Cubit/event-buffer scope: 89 passing
  tests; `dart analyze --fatal-infos` is clean in core.
- No live device/bridge reproduction yet. L4 evidence and cleanup remain pending.
- Retirement requires the recorded targeted L4 matrix, privacy-safe EVIDENCE.md
  and cleanup. Partial/Blocked/Fail keeps the plan active unless the user accepts
  a matrix reduction explicitly in PLAN.md.
