# Hermes Agent Harness Plugin: Tracker

## Current State

- **Plan slug:** `hermes-agent-plugin`
- **Owner review:** in progress since 2026-08-15
- **Current open PR:** none
- **Local successor:** none; Step 9 retirement is blocked
- **Next action:** exercise the remaining blocked matrix rows — `Questions and permissions`, `Session turns` (reasoning streaming), `Projects and sessions` (failed/cancelled import), and `Compatibility` — or record explicit owner acceptance
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
| [x] | 8/9 | #929 | Merged regression evidence; blocked rows prevent retirement. |
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
- Bridge source: branch `hermes-agent-plugin-step8-takeover` (PR #929), whose
  tested tree contained merged Step 7 commit
  `d4e6733062abf424ee10b0dfbbeb8d42ae18003b` (PR #927). PR #929 landed on `main`
  as merge commit `1f67127cfc288d7e73436a5c45d7cf67ec1618cf`.
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

## Step 8 Evidence: iOS Client E2E

Execution date: 2026-08-18. This run resolves rows the 2026-08-15 run recorded
as Blocked, using a real provider and a real client instead of a deterministic
local mock.

- Hermes Agent: `0.20.1` (unchanged isolated install).
- Bridge: `origin/main` at `780f838f4`, slot 1, `--hermes-bin` pointed at the
  isolated executable.
- Client: Flutter debug build on iOS simulator `sesori-dev-1`, iPhone 17,
  iOS 26.5. Traffic went phone -> relay -> bridge -> Hermes, not debug HTTP.
- Provider: a real OpenAI-compatible endpoint on loopback, exercised with
  `cu/default` and then `generic-high`. The credential was removed from the
  isolated Hermes config after the run.

| Matrix row | Result | Privacy-safe evidence |
|---|---|---|
| Plugin setup and lifecycle | **Pass** | Setup reported Hermes Agent `0.20.1` `ready`. The harness picker listed "Hermes Agent" with NousResearch artwork in correct alphabetical position, and the selection persisted into the next new-session screen. Safe restart returned 200 twice mid-session, and disable/enable returned 200. Old-binary handling was exercised with stub executables: a `0.19.0` install reported `unavailable` with "The configured Hermes CLI path points to an unsupported version...", and a pre-ACP install rejecting the `acp` subcommand reported `runtimeMissing` with "The installed Hermes does not expose the `acp` subcommand...". Targeted L4 idle respawn was not exercised; see the note below. |
| Session creation and options | **Pass** | A session was created from the phone with the Hermes harness; the bridge attributed it `pluginId: hermes`. A title was generated and a dedicated worktree/branch was provisioned. No model picker was populated, matching the documented configured-model-only scope. |
| Session turns | **Blocked** | Text streaming, tool streaming, status updates, and abort all passed from the phone, including a 1-to-400 enumeration ending `text_response(finish_reason=stop)`. Concurrent sessions passed: two Hermes sessions created distinct ids and advanced to seven messages each under simultaneous prompts. Call-absence tracing passed: Hermes advertises no `session/close`, and no `session/close`, `elicitation/create`, or `session/set_config_option` call appeared in bridge logs. Remaining gap: an explicit chain-of-thought prompt produced no `agent_thought_chunk`, so reasoning streaming is unverified against this model. |
| Tools and file changes | **Pass** | A prompt drove `tool_turns=2`. The client rendered `write:` and `read:` tool entries plus the final message. `e2e.txt` was verified on disk containing `OK` inside the session worktree, and the File Changes screen rendered `1 file changed +1 -0` with hunk `@@ -0,0 +1,1 @@`. |
| Attachments and images | **Pass** | A 64x64 solid-red PNG sent as an image part reached the provider and the model answered with the correct single colour, visible in phone history. An earlier malformed fixture was rejected upstream with "Could not process image"; that was a bad test fixture, not a Sesori defect. |
| Session history and recovery | **Pass** | After a mid-session plugin restart the phone transcript still rendered every prior turn, and the bridge served 9 persisted messages for the same session. Synced reopen while stopped passed: with `runtimeState: disabled`, the bridge still served the full transcript from its own storage without starting Hermes. Bridge-restart convergence passed: after a full bridge stop and start, the same session returned the same message count with Hermes back at `dormant` / setup `ready`. |
| Session archiving and deletion | **Pass** | Swipe-to-delete warned "Worktree has unstaged changes" and required explicit Force Delete rather than silently discarding work. After confirmation the session left the list, its worktree was removed from disk, and an explicit re-import did not resurrect it while upstream Hermes retained its ACP rows. |
| Questions and permissions | **Blocked** | The provider completed file tools without emitting an ACP permission request, so once/reject/always and two-session correlation remain unexercised. |
| Projects and sessions | **Blocked** | Explicit import, non-destructive re-import, and dormant catalog reads passed. A failed or cancelled in-flight import was still not exercised. |
| Compatibility | **Blocked** | Older-client and older-bridge presentation E2E still requires a second build pair. |

Two required items remain unexercised and keep their rows honest rather than
being folded into a Pass. Targeted L4 idle respawn was not driven, because it
needs a controlled idle-timeout window rather than an interactive session. No
prompt in this run produced an ACP permission request, so the
questions-and-permissions row has no evidence at all.

Observed upstream limitation, not a Sesori defect: `cu/*` models returned empty
completions through this endpoint (`completion_tokens: 0`), so Hermes correctly
reported `empty_response_exhausted`. The client surfaced that as a bounded,
actionable message rather than hanging, which is the desired failure behavior.
`generic-high` returned normal content and was used for the remaining rows.

Turn abort was additionally confirmed: the phone's stop control produced
`Cancelled session` and `Turn ended: reason=interrupted_during_api_call` with
the upstream stream force-closed, and the session accepted a normal turn
immediately afterwards.

Cleanup completed: the app was terminated, the simulator shut down, the slot 1
bridge stopped, port 9971 released, the temporary project hidden, and the
provider credential removed from the isolated Hermes configuration.
