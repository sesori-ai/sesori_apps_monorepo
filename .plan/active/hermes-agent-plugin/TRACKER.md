# Hermes Agent Harness Plugin: Tracker

## Current State

- **Plan slug:** `hermes-agent-plugin`
- **Owner review:** in progress since 2026-08-15
- **Current open PR:** Step 7/9, #927
- **Local successor:** Step 8/9 verification branch
- **Next action:** address Step 7 review/CI, merge #927, then continue the local Step 8 evidence matrix
- **Retirement:** blocked on the Step 8 matrix in `PLAN.md`

## Delivery

| Done | Step | PR | State |
|---|---|---|---|
| [x] | 1/9 | #895 | Merged; original contributor plan, now corrected by owner review. |
| [x] | 2/9 | #915 | Merged package scaffold. |
| [x] | 3/9 | #916 | Merged ACP plugin core. |
| [x] | 4/9 | #917 | Merged descriptor/setup implementation. |
| [x] | 5/9 | #919 | Merged registration and CI coverage. |
| [ ] | 6/9 | #921 | Open; branding implementation and supplied artwork corrections. |
| [ ] | 7/9 | pending | Local corrective plan/runtime/ACP pass. |
| [ ] | 8/9 | pending | Regression documentation and real Hermes matrix. |
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

Every row in `PLAN.md` must record Pass/Fail/Blocked, exact versions and
platforms, privacy-safe observations, and cleanup. Previous contributor claims
of a completed live run are not accepted as evidence because the checklist was
unchecked and no durable result was recorded.
