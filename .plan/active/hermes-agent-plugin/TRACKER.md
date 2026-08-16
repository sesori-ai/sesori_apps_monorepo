# Hermes Agent Harness Plugin: Tracker

## Current State

- **Plan slug:** `hermes-agent-plugin`
- **Owner review:** in progress since 2026-08-15
- **Current open PR:** Step 8/9, #929
- **Local successor:** none; Step 9 retirement is blocked
- **Next action:** review and merge #929, then execute blocked matrix rows or record explicit owner acceptance
- **Retirement:** blocked on the Step 8 matrix in `PLAN.md`

## Delivery

| Done | Step | PR | State |
|---|---|---|---|
| [x] | 1/9 | #895 | Merged; original contributor plan, now corrected by owner review. |
| [x] | 2/9 | #915 | Merged package scaffold. |
| [x] | 3/9 | #916 | Merged ACP plugin core. |
| [x] | 4/9 | #917 | Merged descriptor/setup implementation. |
| [x] | 5/9 | #919 | Merged registration and CI coverage. |
| [x] | 6/9 | #921 | Merged branding implementation and supplied artwork corrections. |
| [x] | 7/9 | #927 | Merged corrective plan/runtime/ACP pass. |
| [ ] | 8/9 | #929 | Open regression evidence; blocked rows prevent retirement. |
| [ ] | 9/9 | pending | Retirement only after required evidence passes. |

## Owner Decisions

- Hermes uses ACP v1 over stdio and no Sesori-managed runtime.
- Hermes support targets persisted ACP-source sessions, not ordinary CLI/TUI/gateway sessions.
- `0.20.0` is the conservative minimum tested Hermes Agent release; it is not called an adapter version.
- Version 1 uses Hermes's configured model/provider and does not expose model or mode selectors.
- Setup remains out of band through Hermes CLI. The bridge never runs terminal setup as authentication.
- Custom Hermes branding is explicitly approved (2026-08-15) as a narrow presentation exception.
- Local deletion uses Sesori purge plus plugin-scoped tombstone; no private Hermes database mutation is added.

## Audit Findings

| Finding | Status |
|---|---|
| Plan/tracker state and locked decisions were stale and unapproved | Corrected in local Step 7. |
| Version probe was mislabeled as an ACP adapter version | Code/tests/docs correction in local Step 7. |
| Terminal-only `hermes-setup` could be selected by the headless bridge | Code/test correction in local Step 7. |
| Explicit binary was not revalidated before start | Code/test correction in local Step 7. |
| Nonzero `hermes status` output could still report setup ready | Code/test correction in local Step 7. |
| Registry test allowed undeclared extra plugins | Exact-set test correction in local Step 7. |
| Null ACP load/resume results were accepted as resident sessions | ACP base retry correction and regression test in local Step 7. |
| Plan falsely claimed no model/config operations | Scope corrected: configured defaults only in v1. |
| Plan overclaimed all Hermes sessions and automatic enumeration | Scope corrected: ACP sessions through explicit import. |
| History verification bypassed bridge-authoritative cached reads | Matrix corrected. |
| Deletion did not state upstream Hermes data retention | Limitation and tombstone behavior recorded. |
| Branding crosses the generic plugin-id presentation preference | Explicitly approved owner exception; unknown-id fallback retained. |
| Artwork tests selected filenames but did not validate composition | Asset composition test added to #921. |

## Step 7 Verification

- [x] `dart analyze --fatal-infos` in `bridge/sesori_plugin_acp`
- [x] `dart test` in `bridge/sesori_plugin_acp` (242 tests passed)
- [x] `dart analyze --fatal-infos` in `bridge/sesori_plugin_hermes`
- [x] `dart test` in `bridge/sesori_plugin_hermes` (24 tests passed)
- [x] Registry test in `bridge/app` (2 tests passed)
- [x] Architecture implementation review approved with no findings

## Step 8 Evidence

Execution date: 2026-08-15.

- Hermes Agent: `0.20.1`, upstream tag `v2026.8.13`, commit
  `f80f453ae0679347e38abc917c7f94f717bf96c5`.
- Bridge source: local Step 8 merge `3540d42a`, containing merged Step 7
  `d4e673306` from `main`.
- Host: macOS 26.6.1 (`25G76`), arm64; Dart 3.13.0 stable.
- Client platform/build: none. Client E2E rows are Blocked, not inferred from
  debug HTTP or raw ACP behavior.
- Provider: isolated local OpenAI-compatible deterministic endpoint. This
  verifies configured-provider plumbing without real credentials; it does not
  establish vision, permissions, or production-provider behavior.
- Isolation: Hermes checkout, executable, home, configuration, and provider
  stayed under the approved temporary directory. No user Hermes configuration
  or provider credential was read or changed.

| Matrix row | Result | Privacy-safe evidence |
|---|---|---|
| Plugin setup and lifecycle | **Blocked** | Partial Pass: `hermes acp --version` and `--check` passed; isolated config advertised terminal and non-terminal auth; setup was `ready`; Hermes was selectable; catalog reads left runtime `dormant`; refresh, safe restart, safe disable, and enable returned 200; final runtime was `active`. Explicit missing binary was `runtimeMissing`. Older/pre-ACP live binaries, targeted idle respawn, and client E2E were not executed. |
| Projects and sessions | **Blocked** | Partial Pass: explicit import completed with 2 projects and 3 persisted ACP sessions; ordinary project reads left Hermes dormant; repeated import was non-destructive. Failed/cancelled live import was not executed. |
| Session creation and options | **Blocked** | Partial Pass: bridge create returned 200 with Hermes identity and configured defaults; upstream `session/new` returned model and mode state. No model/mode picker was exercised. Client E2E was not executed. |
| Session turns | **Blocked** | Partial Pass: bridge create and second prompt returned 200; transcript grew from 3 to 5 normalized messages. Raw ACP emitted agent/user text, available-command, session-info, and usage updates and ended normally. Reasoning, tools, abort, concurrent sessions, and call-absence tracing were not completed. |
| Session history and recovery | **Blocked** | Partial Pass: raw ACP `session/load` succeeded for persisted data; bridge transcript retained all 5 messages after plugin restart; repeated bridge starts imported persisted ACP sessions. Synced reopen while the plugin is stopped was not executed. |
| Questions and permissions | **Blocked** | No real permission request was produced; once/reject/always, two-session correlation, and abort cleanup remain unexecuted. |
| Attachments and images | **Blocked** | No vision-capable production provider credential was available. Capability advertisement alone was not counted as evidence. |
| Tools and file changes | **Blocked** | No live tool lifecycle or replay was produced by the deterministic provider. |
| Session archiving and deletion | **Pass** | Bridge deletion returned 200; explicit re-import did not resurrect the deleted session; the isolated Hermes ACP row count increased from 3 to 4 and remained 4 after local deletion, confirming the documented upstream-retention limitation. |
| Compatibility | **Blocked** | Existing automated unknown-id fallback and Hermes branding checks pass from Steps 5-7. Older-client and older-bridge presentation E2E was not executed. |

Cleanup completed: the slot 1 bridge and the local provider were stopped, ports
9971 and 9981 were released, and no Hermes ACP or test bridge process remained.
The isolated Hermes home and its non-secret deterministic test data were kept in
the approved temporary directory so blocked rows can be resumed. Previous
contributor claims of a completed live run remain excluded because no durable
evidence accompanied them.

**Retirement status: Blocked.** Step 9 cannot proceed unless all required rows
pass or the owner explicitly accepts the recorded reduction in `PLAN.md`.
