# Harness Runtime Refresh 2026-10

## Status and constraints

- **Plan slug:** `harness-refresh-2026-10`.
- **Status:** planned. Step 1 publishes this plan.
- **Planning baseline:** `main` at `6be008b529` (2026-10-06).
- **Procedure:** `.agents/skills/update-backend-runtimes/SKILL.md`. Read-only release
  audits for all eleven registered harnesses ran on 2026-10-06.
- **Scope:** every harness in `bridge/app/lib/src/runtime/plugin_registry.dart`
  (11 entries, reconciled with the skill inventory). Nothing is excluded.

## Owner decisions (2026-10-06)

- **D1:** Claude Code target follows npm/GitHub `latest` (**2.1.291**), not the
  stable channel's 2.1.285.
- **D2:** OpenCode v2 keeps floor 2.0.11; no `parentID` feature. Round 1 chose the
  raise. Round 2 found that no production flow creates parent-linked sessions
  (`session_creation_service.dart:79,146` always pass `null`), and the owner
  dropped it. Restate the matrix row at 2.0.24: the native API accepts `parentID`
  since 2.0.23, but Sesori has no parent-creation flow.
- **D3:** Pi floor **0.84.1 → 0.99.0**, plus a separate PR that simplifies turn
  acceptance using the prompt response `disposition`.
- **D4:** Codex floor 0.139.0 → 0.148.0, **pending round 3**. Round 1 chose it on
  the premise that it deletes a guard, and that premise was wrong (see the Step 3
  findings). Step 3 runs only if the owner keeps the raise.
- **D5:** DeepSeek: plan the adapter migration to upstream `0.2.0-rc.2` in
  `sesori-ai/sesori-deepseek-acp`, then pin the consumer to the new adapter release.
- **D6:** Cursor: adopt native ACP sub-agent child sessions in a feature PR after
  the pins.
- **D7:** Copilot: fix the stale sub-agent footnote ⁴ now; re-probe ACP sub-agent
  identity in the follow-ups.
- **D8:** Grok per-model context-window selection: track only.
- **D9:** Hermes history-replay compaction marker: track only.
- All other floors stay unchanged. Antigravity keeps its exact identity/pair
  contract.

## Harness inventory

| Harness | Target: current → candidate | Floor | Digests |
|---|---|---|---|
| OpenCode | 2.0.18 → **2.0.24** (`e7a34f09`) | v1 1.14.0, v2 2.0.11 | npm + self (6) |
| Antigravity | 1.2.1 → **1.3.0** (registry `f6c0f4e8`) | exact pair | self (6 + 2 members) |
| Codex | 0.156.1 → **0.160.1** (`d27764b8`) | 0.139.0 (→ 0.148.0 if D4) | SHA256SUMS (6) |
| Copilot | 1.0.88 → **1.0.92** (`a9ba11a1`) | 1.0.78 | SHA256SUMS (6) |
| Cursor | 2026.09.23-86fc751 → **2026.10.01-e373342** | 2026.07.16 | self (4) |
| Claude Code | 2.1.281 → **2.1.291** (`8e60c4ca`) | 2.1.221 | PATH only |
| Hermes | 0.21.5, already latest (`f97608f1`) | 0.20.0 | PATH only |
| Pi | 0.87.1 → **1.0.4** (`7c10bd43`) | 0.84.1 → **0.99.0** | SHA256SUMS (6) |
| OMP | 18.3.0 → **18.6.3** (`09327511`) | 17.2.13 | SHA256SUMS (8) |
| DeepSeek | adapter 0.1.7 → **0.2.x** (harness 0.2.0-rc.2) | 0.1.5 | adapter assets |
| Grok | 1.0.41 → **1.0.46** | 1.0.5 | PATH only |

Work per harness:

- **OpenCode:** pin; REST model regeneration (fixes the `chunkTimeout: false`
  decode failure seen on PATH 2.0.23+); bump the SSE manifest comment.
- **Antigravity:** pin, fixtures and docs; native initialize identity probe.
- **Codex:** pin; the floor raise only if D4 is kept.
- **Copilot:** pin; footnote ⁴.
- **Cursor:** pin; then the D6 feature.
- **Claude Code, Grok:** pin.
- **Hermes:** none.
- **Pi:** pin, floor, `/llama` source fix, compat removal; then the D3
  simplification.
- **OMP:** pin (18.6.3 was released the same day, so re-check for a newer stable);
  model-restore probe.
- **DeepSeek:** the D5 external adapter release comes first.

Re-resolve each candidate immediately before its PR. When a newer stable release
exists, take it and re-check its delta. Hashes come from machine-readable records,
never from this table.

### Release evidence

Verification status starts as **Not run** for every harness; each step's PR
records its own results.

| Harness | Release source | Distribution |
|---|---|---|
| OpenCode | npm `@opencode/cli@2.0.24`; tag `anomalyco/opencode` v2.0.24 | managed tgz, 6 platforms |
| Antigravity | `agentclientprotocol/registry` `antigravity-acp/agent.json` @ `f6c0f4e8` | managed zip, 6 |
| Codex | `github.com/openai/codex` release `rust-v0.160.1` | managed tgz, 6 |
| Copilot | `github.com/github/copilot-cli` release `v1.0.92` | managed, 6 |
| Cursor | `cursor.com/install` (2026-10-06 text) | managed tgz, 4 (no Windows) |
| Claude Code | npm `@anthropic-ai/claude-code@2.1.291` (`latest`) | PATH |
| Hermes | `NousResearch/hermes-agent` release `v2026.9.24` | PATH |
| Pi | `github.com/earendil-works/pi` release `v1.0.4` | managed, 6 |
| OMP | `github.com/can1357/oh-my-pi` release `v18.6.3` | managed bare binaries, 8 |
| DeepSeek | `sesori-ai/sesori-deepseek-acp` (new release pending) | managed, 6 |
| Grok | `x.ai/cli/stable` = 1.0.46 | PATH |

- **Protocol identities:** ACP v1 everywhere, except Codex (app-server v2),
  OpenCode (REST/SSE v2), Pi (RPC) and Claude (stream-json).
- **DeepSeek:** keeps extension protocol v2 unless the adapter bumps it.

## Findings that shape implementation

- **Pi `/llama` regression (fix in Step 7).** Since Pi 0.99.0, built-in extensions
  report `builtin:<name>` instead of `<inline:name>`. The exclusion in
  `pi_backend_catalog_repository.dart:48-53` therefore stops matching and `/llama`
  reappears. With the 0.99.0 floor, replace the entry with `builtin:llama.cpp`.
  The `/mcp` built-in is only partly usable in RPC (sign-in needs interactive
  mode). Probe it, and hide it the same way if it can't be used.
- **Pi compat removal (Step 7).** The 0.99.0 floor makes the
  `COMPATIBILITY 2026-08-31` note in `pi_event_dispatcher.dart:477-481` (Pi ≤
  0.84.2) and the matching doc lines in `api/models/pi_assistant_delta.dart:10-12,103`
  obsolete. Delete the marker and those lines. The DTO keeps `toolId`/`toolName`
  nullable, and the `toolId == null` check stays as ordinary tolerance for
  malformed foreign stdout, without a compat marker; no DTO or parse change.
  Update the floor tests in `pi_plugin_descriptor_test.dart` (0.84.x cases → 0.98.x
  rejected, 0.99.0 accepted).
- **Pi turn acceptance (Step 8).** `prompt`/`steer`/`follow_up` responses carry
  `data.disposition` (`started | queued | handled`) since 0.99.0. Sesori currently
  ignores the response body and always runs a one- or two-snapshot `get_state`
  barrier (`pi_session_service.dart:574-608`) to decide whether an accepted prompt
  produced agent work.
  - **Boundary:** add `enum PiPromptDisposition { started, queued, handled }` in
    `lib/src/models/`. `PiSessionProcessRepository.dispatchPrompt`
    (`pi_session_process_repository.dart:442`) parses `data.disposition` from the
    response and returns it. A missing or unknown value maps to `handled`, which
    keeps today's barrier. No strings reach the service. `dispatchCompaction` is
    unchanged.
  - **Decision in `PiSessionService`** (after `responseSucceeded`; command turns keep
    their existing `getState` at :563 unchanged):

    - Any disposition with `agentSettled`: `_finish`, unchanged.
    - `started` or `queued`, not settled, and no settlement observed before
      acceptance: skip the barrier. Set `agentStarted = true` and
      `state.agentRunning = true`, then `_moveInFlight`. `effectiveSelection` keeps
      the value from `applySelection` (:528); for a prompt turn the barrier's
      refresh only re-reads what `applySelection` just returned.
    - `started` or `queued`, not settled, but a settlement was observed before
      acceptance: the existing barrier (the ordering is ambiguous, so keep the
      proven path).
    - `handled` or unknown, not settled: the existing one- or two-snapshot
      barrier, unchanged. An extension command can start a turn through
      fire-and-forget `sendUserMessage`.

    `queued` means Pi steered the input into the running agent (Sesori always sends
    `streamingBehavior: steer`), so agent work exists for the turn. `_PiQueuedPromptTurn`
    queue state is Sesori's own pre-dispatch queue and is not affected.
  - **Deleted:** nothing structural; the barrier remains for `handled`. The gain is no
    `get_state` round trip on ordinary prompts and steers.
- **Codex floor (Step 3, re-asked in round 3).** The audit claimed that raising the
  floor to 0.148.0 deletes a ~3-line guard. Code reading disproves that.
  - `_recordAcceptedTurn` (`codex_plugin_impl.dart:1318-1337`) uses the
    `if (!_activeTurnByThread.containsKey)` block for every accepted turn. On a fresh
    turn it records the provisional id until `turn/started`; on a steer it avoids
    overwriting the authoritative id. Both still apply at ≥0.148, so only the
    `COMPATIBILITY` comment would change.
  - The 0.144.x notes in `codex_rollout_tool_mapper.dart:496,550` depend on rollout
    content, not the floor, and stay.
  - If the owner still wants the raise: update `minPathVersion`, its rationale
    comment, the `COMPATIBILITY` marker → plain rationale, tests and docs. Otherwise
    drop Step 3.
- **Codex interrupted turns.** From 0.160 an interrupted `turn/completed` can carry
  `turn.error` (opt-in Guardian `tooManyDenials`). Check it in the interrupt smoke;
  an error row is acceptable if it reflects a real denial stop.
- **OMP model restore (Step 5).** From 18.6.3, ACP `loadSession`/`resumeSession`
  throw `Could not restore model` when a session's saved model is gone. Probe history
  open and Sesori's resume-based cleanup (`omp_session_cleanup_repository.dart:38-50`).
  - Step 5 itself is the pin plus the probe.
  - History-open for such a session must surface a typed failure through the existing
    plugin failure path, not a crash.
  - If the probe shows cleanup cannot delete these sessions, the fix becomes its own
    step 5.b and gets a fresh architecture review before implementation. The fix
    must actually delete the session. A "skipped" failure alone is not enough:
    `DeletedSessionStorageCleanupService` already catches, logs and retries each
    cleanup failure on every startup. Candidates, in order of preference:
    1. a resume parameter or option that skips model restore;
    2. a named `OmpSessionStorageApi` behind the existing repository that deletes
       the session files (a new Layer-1 owner, so last resort).

    If neither is feasible, record the owner's explicit acceptance of the orphaned
    storage instead of shipping a no-op fix.
- **Antigravity (Step 4).** The `.par` embeds `__version__ = "1.3.0"`. Confirm the
  build label, `agentInfo` version, protocol 1, advertised load/list/resume/logout
  and the absence of close, all through `AntigravityRuntimeVersionValidator` in an
  isolated probe before merge. Also check the Linux x64 extracted size (926.5 MB)
  against the shared installer limits.
- **OpenCode regen (Step 6).** Run:

  ```sh
  dart run tool/generate_opencode_client.dart --tag v2.0.24 \
    --surface tool/opencode_v2_surface.json --out-dir lib/src/v2
  ```

  Expected real model changes: `provider_settings` (`chunkTimeout` becomes `Object?`,
  new `headerTimeout`), `server_info`, `session_structured_error`. Audit and
  regenerate the v2 SSE events; there are no event-shape changes, so only the
  header/comment updates. v1 output is untouched.
- **Cursor sub-agents (Steps 9, 10).** Cursor enables ACP child sessions when
  the client advertises `clientCapabilities.subagents` or
  `clientCapabilities._meta.subagents`.
  - Child sessions are linked to the parent Task call, stream
    text/thinking/tools/terminal state, and replay on `session/load`. Cursor then
    advertises `sessionCapabilities.subagents`.
  - **9 (probe only, no production code):** record in a step note the exact wire
    shape: the capability response, the child-creation/link notification, the
    child updates, terminal state, cancel semantics, and what `session/load`
    replays for sessions created before and after the capability.
  - **10 (implementation):**
    - **Capability:** advertise `_meta.subagents` through Cursor's existing
      `CursorBinary.acpCapabilityMeta` → `initializeCapabilityMeta`
      (`acp_plugin.dart:240-242`). No change to the shared `buildClientCapabilities`.
      If 9 shows that only the standard field works, add a per-plugin getter that
      defaults to `false` (like `supportsFormElicitation`) rather than enabling it
      for every ACP harness.
    - **Mapping:** the child↔parent Task link is mapped in `CursorEventMapper`
      through the shared hooks `AcpEventMapper.isSubagentSpawnToolCall` /
      `mapExtension` → `mapChildSpawned` and the finish calls
      (`acp_event_mapper.dart:650-675`). Lifecycle stays with the single existing
      owner, `AcpChildSessionTracker`. There is no Cursor-side tracker or registry.
    - **Replay:** state how `session/load` replay reaches the tracker, based on 9.
    - **Stop:** declare the scoped-stop capability matching 9's observed cancel
      semantics. `cursor_plugin_impl.dart` currently derives
      `requiresProcessResidency`, `hasUnresolvedResidentWork` and
      `activeScopedStopWorkCount` (plus `registerProcessResidencyChanges`) from
      `CursorTaskTracker`. Step 10 must back these hooks with
      `AcpChildSessionTracker` state for native children. Otherwise the root-cancel
      path loses its confirmation and its check for surviving children. Removing
      the hooks is allowed only together with a capability that makes no such
      guarantee.
  - **Cleanup:**
    - **Delete with the native live path:** the live `cursor/task` handling in
      `cursor_event_mapper.dart`, `trackers/cursor_task_tracker.dart`, the task
      references in `cursor_approval_registry.dart`, and the wiring in
      `cursor_plugin_impl.dart`.
    - **Also delete, if 9 shows `session/load` replays old sessions' sub-agents
      natively:** `api/models/cursor_task_dto.dart` (+ `.g`/`.freezed`),
      `repositories/mappers/cursor_task_mapper.dart` and
      `repositories/trackers/cursor_task_replay_tracker.dart`.
    - **Otherwise keep exactly these three** for pre-capability transcripts and
      delete the rest.
  - **Review:** 10 gets a fresh architecture review after 9's note exists.
- **DeepSeek adapter (Step 11).** Upstream 0.2.0-rc.2 changes are covered in the
  adapter repo, not here:
  - `agent/session-start` → async `agent/created`;
  - deprecated `snapshotEvents` (adapter `src/sessions.ts:2544,2553`);
  - V4 session logs vs the strict `assertKnownEvents` (`src/sessions.ts:564`);
  - settings moved into the Profile (`src/runtime.ts:678`);
  - subagent limits and team-mode tool changes;
  - model catalog removals.

  This workspace may not create another checkout, so the adapter change and
  release are a handoff (see Step 11). The consumer pin follows the published
  release, with the extension protocol still v2 unless the adapter bumps it.

## Steps

| Step | Title | Size |
|---|---|---|
| 1 | 🌱 Publish this plan | docs |
| 2 | 🌿 Mechanical pins for Claude, Copilot (+ footnote ⁴), Cursor, Grok, Codex | ~150 lines |
| 3 | 🌱 Codex floor 0.148.0 (only if round 3 keeps D4; no code deletion) | ~20 lines |
| 4 | 🌿 Antigravity 1.3.0 with native initialize identity probe | ~120 lines |
| 5 | 🌿 OMP 18.6.3 (or newer stable) with model-restore probe (fix → 5.b, re-reviewed) | ~50 lines |
| 6 | ⚙️ OpenCode 2.0.24 with REST model and SSE regeneration | ~300–500 lines, mostly generated headers |
| 7 | ⚙️ Pi 1.0.4, floor 0.99.0, `/llama` and `/mcp` catalog fix, compat removal | ~150 lines |
| 8 | ⚙️ Pi turn acceptance via prompt `disposition` | ~100–200 lines |
| 9 | 🌱 Cursor ACP sub-agent wire probe note | note |
| 10 | 🚧 Cursor native ACP sub-agent child sessions + task-path cleanup | ~400–700 lines incl. deletions |
| 11 | 🌿 DeepSeek consumer pin to the migrated adapter (after external release) | ~80 lines |
| 12 | 🌱 Reconcile regression documents and `docs/HARNESS_CAPABILITIES.md` | docs |
| 13 | 🌱 Final coverage run and plan retirement | docs |

PR titles: `<emoji> [harness-refresh-2026-10] <description> [step <x>/13]`.

- **Total:** 13 counts every row above. If Step 3 is dropped, renumber the
  remaining PRs to a 12-step total. If Step 5.b is activated, insert it after
  Step 5 and raise the total.
- **Already open:** keep the titles of open PRs in sync with the current total.

Each pin PR updates, together:
- the manifest/descriptor;
- the focused manifest/descriptor tests;
- the target column in `docs/regression/plugin-setup-and-lifecycle.md`;
- harness-specific docs (`docs/ANTIGRAVITY.md`, README target lists);
- `.agents/skills/update-backend-runtimes/references/harnesses.md`, wherever its
  facts changed.

Historical verification notes keep their original versions.

### Step 11 handoff (external dependency)

1. In `sesori-ai/sesori-deepseek-acp`, migrate to `@deepseek-ai/dsh-*` `0.2.0-rc.2`
   (or a newer RC/stable published by then). Address the five areas listed above,
   run adapter conformance on all six native packages, and publish a release
   (expected v0.2.0).
2. Only then pin the consumer: `deepseek_runtime_manifest.dart` target and six
   digests, plus tests.

This needs a session with that repository checked out. Record the blocker in
`TRACKER.md` and keep Step 11 open; it does not hold the other steps.

## Verification

- **Per step:** run focused owning-package tests and `dart analyze --fatal-infos`
  for each changed package.
- **Managed pins:** install through the production installer/manifest into a
  disposable root, verify the digest sentinel, and run `--version` on the current
  host (macOS arm64).
- **Highest level: L2 Routine.** Do one normal turn per updated harness through the
  production seam, where credentials are available, plus the feature checks:
  - Codex: initialize and list over **both** app-server transports. Sessions use
    the WebSocket transport; authentication uses stdio.
  - Pi: catalog with no `/llama`; disposition-driven settlement for prompt, steer
    and a silent command.
  - Cursor: sub-agent child session live and after reload, and stop.
  - OMP: open and delete a session whose model is gone.
  - OpenCode: provider list with `chunkTimeout: false`.
- **Matrix:** the macOS arm64 host for native checks. Other platforms are covered by
  digest agreement only and stay **untested**.
- **Unavailable checks:** authenticated turns that need credentials I don't have go
  to the final follow-up list. They do not hold back the pins.
- **Retirement gate:** these checks remain part of the L2 matrix. Step 13 retires
  the plan only after they pass or after the owner's explicit acceptance of each
  remaining gap is recorded in this file (`docs/regression/README.md`).
- **Regression docs affected:**
  - `plugin-setup-and-lifecycle.md`
  - `plugin-runtime-installation.md`
  - `antigravity-descriptor-and-setup.md`
  - `session-turns.md` (Pi acceptance)
  - `session-history-and-recovery.md` and `tools-and-file-changes.md` (Cursor
    sub-agents, OMP restore)
  - `session-creation-and-options.md` (Pi catalog)

## Complexity budget

- **New mutable state:** none planned for the pins.
  - Step 8 adds one enum return value and skips the existing barrier at runtime for
    `started`/`queued`; it adds no fields.
  - Step 10 keeps child lifecycle in the existing `AcpChildSessionTracker`; there
    is no Cursor-side tracker or registry.
- **Deliberately not added:** version branches for runtimes below the new floors
  (Pi, Codex); dual `/llama` source matching; Grok context-window or Hermes
  compaction features (D8, D9).

## Cleanup assessment

- **Codex:** nothing to delete. A kept D4 only rewrites the `COMPATIBILITY` comment
  (Step 3).
- **Pi:** the ≤0.84.2 compat note and the `<inline:llama.cpp>` entry are deleted
  (Step 7). Step 8 deletes no structure; the barrier stays for `handled`.
- **Cursor:** the live task path is deleted, and the replay path is deleted or kept
  per the 10 cleanup list.
- **Antigravity:** the legacy `agy_acp_server_` prefix and `YYYYMMDD_NN_RCNN`
  parsing would only reclassify pre-1.2.1 installs from "unknown" to "outdated".
  Leave them as they are; the value is low.

## Risks

- **Pi 1.0 is a major line.** The floor raise forces PATH users on 0.84–0.98 to
  update; they get the existing "outdated" setup action.
- **Codex floor raise (only if round 3 keeps D4).** PATH users on 0.139–0.147 are
  asked to update.
- **Antigravity exact pair.** 1.2.1 users must upgrade, as with every bump.
- **Self-computed digests.** Cursor and Antigravity digests are not upstream
  attestations.
- **DeepSeek.** The migration depends on upstream RCs and on a separate repo
  release.

## Plan review

`architecture-plan-review`, 2026-10-06:
- **First pass:** rejected. Steps 3, 5, 8 and 9 were too vague, and Step 7 left DTO
  nullability unstated.
- **Second pass:** confirmed the design passes. It rejected only on stale cleanup,
  budget and risk text, which has since been fixed as text-only edits without
  another review.
- **Still needed:** Step 10 and the conditional Step 5.b each need their own
  review before implementation.
