# Codex Plugin Stability Feedback

## Status

- **Plan slug:** `codex-plugin-stability-feedback`
- **Status:** Active — preparing Step 4/11 after Step 3 PR
  [#732](https://github.com/sesori-ai/sesori_apps_monorepo/pull/732) merged
- **Plan date:** 2026-08-04
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at
  `5aaf979dd25b645a69964d0211eda5cd92126037`
- **Stack root:** merged Codex image-history fix `2408b574`
- **Delivery:** nine existing deep-test branches in their exact ancestry order,
  one additional confirmed finding fix, and one plan-retirement PR
- **Plan PR:** [#724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724),
  merged as `149e7914`; it combined the plan with the first unmerged production
  fix at the user's direction

This document and `TRACKER.md` are the implementation authority for the
remaining Codex stability series. The evidence report at
`docs/codex-plugin-stability-report.md` remains the detailed validation record;
it is not the delivery tracker.

## Goal

Deliver the already-tested Codex deep-stability stack without rewriting its Git
history, close the confirmed repository-instruction history leak, and preserve
one durable record that maps every observed finding to its owning branch,
commit, PR, behavior, and verification.

The completed series must keep Codex sessions consistent while live, after
navigation, after reconnect, and after cold bridge restart. It must also let the
mobile app submit images only when the selected bridge plugin explicitly
declares support.

## Success Criteria

1. The existing `codex-stability-deep-test-1-*` through
   `codex-stability-deep-test-9-*` branches merge in their current order without
   rebase, reset, cherry-pick, or commit reordering.
2. Every F-01 through F-12 finding has an individual acceptance entry below and
   a matching state in `TRACKER.md`.
3. Generated shell/image wrappers, command and file identities, interrupted
   lifecycle state, archive behavior, and replay policy remain consistent live
   and after reload.
4. Mobile image prompts reach Codex through a backend-neutral declared
   capability; unsupported, unresolved, and older bridges fail closed.
5. Codex-generated `AGENTS.md` repository instructions do not render as authored
   user messages, while real authored text and near matches remain visible.
6. No prompt, transcript, source content, image data, repository instructions,
   local path, raw capture, or entity identifier is added to logs, analytics, or
   this plan.
7. Each implementation PR stays below the 1,500 changed-line soft cap unless a
   coherent split is impossible and the tracker records why.
8. The final PR records every merge and verification result and moves this plan
   from `.plan/active/` to `.plan/completed/`.

## Evidence And Current Behavior

The stability pass exercised a real bridge, Codex runtime, and iOS simulator.
It compared live normalized events, bridge session snapshots, and rendered
mobile state through navigation, reconnect, restart, lifecycle actions, and
deletion. Privacy-sensitive raw captures remain outside the repository.

Evidence levels are intentionally explicit:

- **Observed ordinary user flows:** F-01 through F-12. Each changed or exposed
  user-visible session history, tool state, identity, attachment, or lifecycle
  behavior during normal creation, reload, reconnect, archive, abort, or image
  submission.
- **Accepted bounded observations:** one transient incomplete initial history
  self-healed on the next refresh and did not recur after navigation; one bridge
  shutdown stall did not reproduce; empty upstream reasoning summaries contain
  no renderable reasoning. These are not promoted into coordination machinery or
  extra production steps without new evidence.
- **Separately owned defect:** the unsupported relay message-version `123` error
  was found and is being fixed outside this plan at the user's direction.

## Scope

### Included

- The exact existing D1 through D9 production commits and their tests.
- The existing stability report commits on D7 through D9.
- A localized post-D9 F-12 fix for generated repository-instruction history.
- Plan/tracker maintenance and final retirement.
- Merge-forward propagation between stacked branches as each predecessor is
  updated or merged.

### Excluded

- The separately owned relay framing/version `123` fix.
- New Codex runtime versions or runtime provisioning changes.
- Database schema changes, migrations, or data backfills.
- New relay protocol variants or attachment payload types.
- New analytics events or parameters.
- Broad parsing frameworks, generic wrapper interpreters, global identity
  registries, cross-plugin coordination, or speculative lifecycle machinery.
- Rendering invented reasoning when upstream supplies no summary.
- Fixing bounded self-healing UI refresh behavior without a reproducible cause
  and meaningful impact.

## Ownership And Data Flow

### Generated wrapper projection

`CodexRolloutToolMapper` owns backend-specific recognition of generated rollout
wrappers. Steps 1 and 3 extend only exact known Codex wrapper forms. Mixed-purpose
code, malformed directives, additional tool calls, and variable mismatches remain
visible rather than being guessed away.

```text
Codex rollout response item
  -> CodexRolloutToolMapper
  -> canonical PluginToolState / image-generation projection
  -> shared bridge message mapping
  -> client renderer
```

### Live tool identity and lifecycle

`CodexToolLifecycleTracker` owns app-server-to-rollout identity correlation.
`CodexPlugin` supplies typed events and authoritative item/turn lifecycle. Steps
2, 4, and 5 keep command and file correlations narrow, per thread/turn, and
retire aliases at the authoritative item completion boundary.

No bridge-global identity registry is added. The observed duplicate cards are
backend-specific and remain inside `sesori_plugin_codex`.

### Replay terminalization and typed boundaries

`CodexSessionService` owns the policy decision derived from authoritative
session activity. `CodexMessageRepository` reconstructs messages, while
`CodexToolLifecycleTracker` applies the explicit replay disposition. Step 6
first delivers the proven behavior; Step 8 replaces raw status/map decisions
with sealed typed values without changing that behavior.

```text
CodexPlugin reads bridge session status
  -> CodexSessionService maps status to CodexReplayToolDisposition
  -> CodexMessageRepository reads typed rollout records
  -> CodexToolLifecycleTracker preserves or terminalizes unresolved tools
```

### Archive authority

The bridge database remains the sole archive-state authority. Codex has no
symmetric backend unarchive callback, so Step 7 removes the destructive backend
archive call while retaining destructive delete behavior.

### Mobile prompt-attachment capability

Step 9 keeps backend knowledge in plugin descriptors and carries only a neutral
boolean contract across shared and client layers:

```text
BridgePluginDescriptor.supportsPromptAttachments
  -> RegisteredPluginMetadata
  -> PluginLifecycleService
  -> PluginMetadata wire response
  -> PluginRepository
  -> NewSessionCubit / SessionDetailLoadService
  -> SessionDetailCubit state
  -> composer visibility and send guard
  -> CodexThreadRepository data-image input
```

OpenCode and Codex declare support. Cursor inherits false. Existing-session
capability lookup is optional to transcript loading and fails closed. A
disconnect clears capability provenance before queued attachments can drain
through a different bridge; successful refresh explicitly restarts draining.

### Generated repository-instruction history

`CodexMessageRepository` already owns F-01 generated-context filtering and the
submitted-user-message evidence that protects authored text. Step 10 extends
that same local boundary for Codex 0.146.0's observed complete shape:

```text
# AGENTS.md instructions[ for <directory>]

<INSTRUCTIONS>
...
</INSTRUCTIONS>
```

At Step 10 start, capture and sanitize one fresh structural fixture to confirm
whether the envelope exists only in rollout history. If so, change only
`CodexMessageRepository` and its rollout tests. Do not modify live app-server
mapping unless a captured ordinary flow proves the same envelope is emitted
there. If evidence expands the fix into cross-layer state or authored-message
coordination, stop and ask before broadening the step.

## Compatibility, Persistence, Privacy, And Analytics

### Compatibility

- Steps 1 through 8 and Step 10 alter internal plugin behavior/contracts only;
  all in-repository consumers move together and need no compatibility shim.
- Step 9 adds `PluginMetadata.supportsPromptAttachments` to the client/bridge
  transport. Older bridges omit it, so `@Default(false)` keeps attachment UI and
  sends disabled rather than risking silent image loss.
- No unpublished alternate route, dual contract, or backend-specific identifier
  escapes the plugin boundary.

### Persistence

- No database schema or migration changes.
- Step 7 changes archive side effects, not persisted bridge archive shape.
- Steps 6 and 8 change replay interpretation, not rollout persistence.
- Step 10 changes projection only; stored Codex rollout content is untouched.

### Privacy and security

- The F-12 fix is privacy-relevant because generated instructions can contain
  repository content and local paths.
- Tests use marker-only, sanitized fixtures and never commit real instructions.
- Local diagnostic policy remains unchanged: useful errors and stack traces stay
  available, while prompts, transcripts, images, and instruction bodies remain
  excluded.

### Analytics

No new analytics event is planned. The stability fixes are passive projection,
identity, and lifecycle corrections. Step 9's authoritative session/message
outcome already flows through existing product analytics; adding an image tap or
plugin-specific event would not answer a distinct product decision and could
expose sensitive content/provider context. Product behavior remains independent
of analytics delivery.

## Finding Acceptance Steps

These are individual product acceptance items. Their numbering follows the
evidence report; PR delivery numbering separately preserves the existing stacked
branch order because some findings span more than one commit and several were
already merged before this durable plan existed.

### Finding step F-01 — Generated internal context rendered as user text

- **State:** Fixed on `main`.
- **Observed impact:** Cold history inserted generated context as a large user
  message and displaced authored transcript content.
- **Cause/fix:** `CodexMessageRepository` now excludes complete generated
  envelopes while preserving mixed/authored text using submitted-user evidence.
- **Delivery:** `codex-stability-2-user-context`, PR
  [#710](https://github.com/sesori-ai/sesori_apps_monorepo/pull/710), commit
  `0dc0c6ec`.
- **Acceptance:** Existing F-01 regressions remain green throughout this series.

### Finding step F-02 — One shell command had two live identities

- **State:** Direct path fixed on `main`; code-mode continuation is Delivery
  Step 2/11.
- **Observed impact:** One command appeared as app-server `exec-*` and rollout
  `call_*` cards before reload collapsed it.
- **Delivery:** direct fix `e5cb9d86` on `codex-stability-3-tool-identity`, PR
  [#712](https://github.com/sesori-ai/sesori_apps_monorepo/pull/712); code-mode
  fix `58585e1f` on `codex-stability-deep-test-2-code-mode-tool-identity`.
- **Acceptance:** Direct and exact single-command wrappers retain one canonical
  ID from running through terminal replay.

### Finding step F-03 — Interrupted historical tools stayed running

- **State:** Fixed on `main`.
- **Observed impact:** Aborted/interrupted commands without ordinary output
  replayed forever as running.
- **Delivery:** `codex-stability-4-tool-lifecycle`, PR
  [#713](https://github.com/sesori-ai/sesori_apps_monorepo/pull/713), commit
  `f70bdbcb`.
- **Acceptance:** Durable turn evidence settles historical tools into one honest
  terminal card.

### Finding step F-04 — Prompt images disappeared from history

- **State:** Fixed on `main`.
- **Observed impact:** Codex received the image, but navigation/restart lost the
  expandable prompt attachment.
- **Delivery:** `codex-stability-5-prompt-images`, PR
  [#715](https://github.com/sesori-ai/sesori_apps_monorepo/pull/715), commit
  `6930b3a9`.
- **Acceptance:** One bounded text part and PNG file part survive navigation and
  restart with stable identities.

### Finding step F-05 — Debug SSE disconnected on non-Latin-1 text

- **State:** Fixed on `main`.
- **Observed impact:** A curly apostrophe terminated the debug stream and removed
  its client.
- **Delivery:** `codex-stability-1-debug-sse`, PR
  [#709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/709), commit
  `025ba43b`.
- **Acceptance:** Explicit UTF-8 output preserves the same SSE connection for
  non-Latin-1 and following events.

### Finding step F-06 — Failed commands became completed after reload

- **State:** Fixed on `main`.
- **Observed impact:** A command that exited with code 7 replayed as successful.
- **Delivery:** `codex-stability-6-failed-tool-status`, PR
  [#717](https://github.com/sesori-ai/sesori_apps_monorepo/pull/717), commit
  `20521cc2`.
- **Acceptance:** Error state, useful output, marker, and exit code remain stable
  live and cold.

### Finding step F-07 — Generated output images did not converge

- **State:** Durable image history fixed on `main`; wrapper continuations are
  Delivery Steps 1/11 and 3/11.
- **Observed impact:** Live and cold views differed in wrapper card count,
  identity, title, filename, or attachment.
- **Delivery:** merged `2408b574` on `codex-stability-7-image-generation-history`,
  PR [#718](https://github.com/sesori-ai/sesori_apps_monorepo/pull/718);
  directed wrapper `c3ab5fcb` on D1; complete forwarded wrapper `36ee48e9` on D3.
- **Acceptance:** Every generation has one completed `image_generation` card and
  one expandable attachment; mixed-purpose code remains visible.

### Finding step F-08 — Late completion forked an aborted tool

- **State:** Fixed on stack in Delivery Step 4/11.
- **Observed impact:** A process outlived its aborted turn and later appeared as a
  second completed native command.
- **Delivery:** `a32b6c29` on
  `codex-stability-deep-test-4-late-abort-tool-identity`.
- **Acceptance:** Started unfinished aliases survive turn termination only until
  item completion updates the original failed card.

### Finding step F-09 — Code-mode file changes had two identities

- **State:** Fixed on stack in Delivery Steps 5/11 and 8/11.
- **Observed impact:** App-server file changes and rollout wrappers produced
  different live/cold cards and lost edit projection.
- **Delivery:** behavior fix `9da8f2e1` on D5; typed boundary follow-up
  `d4e30b87` on D8.
- **Acceptance:** Fresh create/update/delete operations produce exactly one edit
  card each with stable IDs, titles, patches, and completion.

### Finding step F-10 — Restart left an active tool running forever

- **State:** Fixed on stack in Delivery Steps 6/11 and 8/11.
- **Observed impact:** After bridge restart, session status was idle while an
  unresolved command still displayed running.
- **Delivery:** behavior fix `8f0f4ece` on D6; service-owned sealed replay policy
  `d4e30b87` on D8.
- **Acceptance:** Idle interrupted calls replay failed; genuinely active calls
  remain running until normal completion.

### Finding step F-11 — Archive removed readable Codex history

- **State:** Fixed on stack in Delivery Step 7/11.
- **Observed impact:** Backend archive moved the rollout out of the readable
  catalog, so Sesori archive/unarchive lost transcript access.
- **Delivery:** `cdd3a305` on
  `codex-stability-deep-test-7-local-archive-history`.
- **Acceptance:** Rename/archive/unarchive preserve transcript; delete still
  removes the disposable session and rollout.

### Finding step F-12 — Repository instructions appeared as a user message

- **State:** Confirmed and documented in Delivery Step 9/11; fix required in
  Delivery Step 10/11.
- **Observed impact:** A fresh iOS-created session rendered generated repository
  instructions and a local path as a large authored user message before the real
  image prompt.
- **Likely boundary:** Existing `CodexMessageRepository` generated-context
  filtering does not recognize Codex's non-angle-bracket AGENTS header.
- **Delivery:** discovery/report update in `ef2356c4` on D9; fix branch
  `codex-plugin-stability-feedback-f12-generated-repository-instructions`.
- **Acceptance:** Complete generated AGENTS envelopes disappear from cold
  history; authored marker-like text, mixed content, and near matches remain.

## Delivery Rules

- The series has exactly eleven PRs. Every title uses the fixed
  `[codex-plugin-stability-feedback] ... [step <x>/11]` form below.
- At the user's direction, Step 1 combines this plan/tracker with the first
  unmerged production fix rather than using a plan-only PR.
- Steps 1 through 9 preserve the exact D1 through D9 branch order. Do not rebase,
  reset, cherry-pick, reorder, or recreate existing production commits.
- Merge current `main` and predecessor updates forward. Before each successor PR,
  merge its updated predecessor into that successor so the plan/tracker and all
  prior fixes remain ancestors.
- A successor may target its immediate predecessor while both are open, but
  merges occur in numeric order. Do not delete a predecessor branch while a
  dependent PR uses it as a base.
- After a merge notification, immediately continue with the next numbered step
  without waiting for another user prompt. Stop only for a material decision or
  blocker.
- Count additions plus deletions, generated code, tests, and plan updates against
  each PR base. Reassess near 1,300 lines; prefer a coherent split before 1,500.
- Generated files change only through their generators.
- Update `TRACKER.md` in every step with actual base, line count, verification,
  review, PR, merge, and cleanup evidence.
- Run `aristotle-impl-review` only for architecture-bearing Steps 6, 8, and 9,
  unless implementation evidence changes another step's architecture scope.
- Step 10 starts with sanitized runtime-shape confirmation. It stays localized
  unless ordinary-flow evidence proves another projection boundary is required.
- Step 11 contains no production changes and moves the complete plan directory
  to `.plan/completed/codex-plugin-stability-feedback/`.

## Delivery Sequence

| Step | Branch | Exact PR title | Existing/target size | Primary finding |
|---|---|---|---:|---|
| 1/11 | `codex-stability-deep-test-1-image-wrapper-directive` | `🌿 [codex-plugin-stability-feedback] fix(codex): recognize directed image wrappers [step 1/11]` | 1,100 total | F-07 |
| 2/11 | `codex-stability-deep-test-2-code-mode-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): unify code-mode command identity [step 2/11]` | 73 | F-02 |
| 3/11 | `codex-stability-deep-test-3-image-wrapper-projection` | `⚙️ [codex-plugin-stability-feedback] fix(codex): hide generated image wrappers [step 3/11]` | 118 | F-07 |
| 4/11 | `codex-stability-deep-test-4-late-abort-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): retain late command identity after abort [step 4/11]` | 86 | F-08 |
| 5/11 | `codex-stability-deep-test-5-file-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): unify file change identity [step 5/11]` | 214 | F-09 |
| 6/11 | `codex-stability-deep-test-6-restart-tool-terminalization` | `⚙️ [codex-plugin-stability-feedback] fix(codex): settle interrupted tools after restart [step 6/11]` | 70 | F-10 |
| 7/11 | `codex-stability-deep-test-7-local-archive-history` | `🌿 [codex-plugin-stability-feedback] fix(codex): preserve locally archived history [step 7/11]` | 308 | F-11 |
| 8/11 | `codex-stability-deep-test-8-typed-boundaries` | `🚧 [codex-plugin-stability-feedback] refactor(codex): type replay and item boundaries [step 8/11]` | 1,084 | F-09, F-10 |
| 9/11 | `codex-stability-deep-test-9-mobile-images` | `🚧 [codex-plugin-stability-feedback] feat(codex): support mobile image prompts [step 9/11]` | 707 | F-12 discovery plus image support |
| 10/11 | `codex-plugin-stability-feedback-f12-generated-repository-instructions` | `🌿 [codex-plugin-stability-feedback] fix(codex): hide generated repository instructions [step 10/11]` | target 70–140 | F-12 |
| 11/11 | `codex-plugin-stability-feedback-retire-plan` | `🌱 [codex-plugin-stability-feedback] docs: retire Codex stability feedback plan [step 11/11]` | target 40–100 | Lifecycle |

## Per-Step Review Briefs

### Step 1/11 — Directed image wrappers plus plan

- **Complexity:** Straightforward — two localized Codex mapper/test files plus
  durable delivery documentation.
- **What:** Recognize the exact generated `// @exec: {...}` directive preceding
  directed image wrappers; add this plan and tracker.
- **Why:** Generated wrapper shells otherwise appear beside the durable image
  result, and the remaining stack needs one explicit delivery authority.
- **Risk and test focus:** Exact directive matching, malformed directives,
  mixed-purpose code, and plan/title/branch consistency.
- **Expected result:** One image card for directed generated wrappers. No wire,
  database, client, or analytics change.
- **Verification:** Focused wrapper lifecycle tests, full Codex tests, fatal
  analysis, `git diff --check`, and architecture plan review.

### Step 2/11 — Code-mode command identity

- **Complexity:** Moderate — per-turn correlation across app-server and rollout
  identity domains.
- **What:** Correlate only wrappers containing exactly one
  `tools.exec_command(...)` invocation to the canonical rollout call.
- **Why:** The merged direct-command fix does not cover generated code-mode
  wrappers.
- **Risk and test focus:** Multiple calls, turn isolation, FIFO order, cleanup,
  and unchanged direct-command behavior.
- **Expected result:** One command ID live and cold. No user-visible change
  beyond duplicate removal; no wire/database change.
- **Verification:** Focused tracker tests, full Codex tests, fatal analysis, and
  `git diff --check`.

### Step 3/11 — Complete generated image wrappers

- **Complexity:** Moderate — exact syntax, tool-count, and variable-identity
  constraints protect against hiding real code.
- **What:** Recognize forwarded/content-forwarded generated image wrappers and
  suppress only complete generated forms.
- **Why:** Forwarded forms still create extra shell cards.
- **Risk and test focus:** Mixed code, extra calls, mismatched variables,
  malformed wrappers, and direct/forwarded/directed/preview variants.
- **Expected result:** One durable image-generation card and attachment. No
  wire/database/client change.
- **Verification:** Focused wrapper matrix, full Codex tests, fatal analysis,
  and `git diff --check`.

### Step 4/11 — Late abort completion identity

- **Complexity:** Moderate — alias lifetime crosses turn termination and item
  completion.
- **What:** Retain aliases only for started unfinished items, then retire them at
  authoritative item completion.
- **Why:** Late native completion otherwise forks the original failed card.
- **Risk and test focus:** Alias leaks, abort-before-start, ordinary completion,
  and restart replay.
- **Expected result:** The original failed card receives the terminal update. No
  wire/database/client change.
- **Verification:** Focused abort/late-completion tests, full Codex tests, fatal
  analysis, and `git diff --check`.

### Step 5/11 — File-change identity

- **Complexity:** Moderate — a second correlated item type carries edit-specific
  patch output.
- **What:** Recognize exact single-`apply_patch` wrappers, correlate app-server
  file changes per turn, and project the patch as an edit.
- **Why:** Live and cold identity diverge and edit presentation is lost.
- **Risk and test focus:** Create/update/delete, multi-operation patches,
  malformed strings, command/file queue separation, and failure state.
- **Expected result:** One stable edit card per logical operation. No
  wire/database/client change.
- **Verification:** Focused file-correlation tests, full Codex tests, fatal
  analysis, and `git diff --check`.

### Step 6/11 — Interrupted replay terminalization

- **Complexity:** Moderate — replay policy crosses plugin, service, repository,
  and tracker seams.
- **What:** Supply authoritative session activity to replay and terminalize
  unresolved chronology only when the session is idle.
- **Why:** Restart can leave a visible running tool with no active backend turn.
- **Risk and test focus:** Busy/provisional/retry states, idle restart, active
  snapshots, and false premature failure.
- **Expected result:** Interrupted idle tools become failed; active tools remain
  running. No wire/database/client change.
- **Verification:** Active-versus-idle replay tests, full Codex tests, fatal
  analysis, `git diff --check`, and implementation architecture review.

### Step 7/11 — Local archive authority

- **Complexity:** Straightforward — remove one destructive backend side effect
  and retain evidence documentation.
- **What:** Keep archive state bridge-local and add the completed stability
  evidence report.
- **Why:** Codex archive removes readable rollout history and has no symmetric
  unarchive callback.
- **Risk and test focus:** Archive/unarchive transcript, rename persistence,
  delete remaining destructive, and no backend archive call.
- **Expected result:** Archived sessions remain readable and reversible. No
  schema/wire/client change.
- **Verification:** Archive/delete write-path tests, full Codex tests, fatal
  analysis, report consistency, and `git diff --check`.

### Step 8/11 — Typed replay and item boundaries

- **Complexity:** Complex — generated typed variants, parser ownership, tracker
  migration, and service-owned replay policy across 25 files.
- **What:** Introduce typed command/file events and sealed replay disposition;
  remove raw map/status interpretation from downstream owners.
- **Why:** F-09/F-10 behavior is correct but impossible states and misplaced
  decisions remain representable.
- **Risk and test focus:** Unknown/malformed input, status mapping, parser
  privacy, code generation, composition, and behavior equivalence.
- **Expected result:** Same visible behavior with typed owner-correct boundaries.
  No wire/database/client change.
- **Verification:** Codegen, parser/tracker/service/repository tests, all Codex
  tests, fatal analysis, `git diff --check`, and implementation architecture
  review.

### Step 9/11 — Mobile image prompts

- **Complexity:** Complex — backward-compatible shared wire capability plus
  bridge, plugin, client service/state, reconnect, queue, and UI flow.
- **What:** Declare prompt-attachment capability, enable Codex data-image input,
  replace the hardcoded plugin gate, and fail closed when capability provenance
  is unresolved.
- **Compatibility acceptance:** Keep the dated
  `COMPATIBILITY 2026-08-04 (v1.8.0)` comment beside `@Default(false)`,
  documenting older bridge omission and the exact cleanup when those bridge
  versions become unsupported.
- **Why:** Codex supports image input, but mobile previously exposed attachment
  selection only through an OpenCode-specific temporary gate.
- **Risk and test focus:** Older bridges, different-bridge reconnect, queued
  images, lookup failure, unsupported plugins, generated output, and history.
- **Expected result:** Mobile Codex image prompts work without silent loss.
  User-visible and compatible wire change; no database change.
- **Verification:** Shared/client codegen; relevant tests and fatal analysis in
  shared, plugin interface, OpenCode, Codex, bridge app, client core, and mobile;
  widget tests, real iOS E2E, `git diff --check`, and implementation architecture
  review.

### Step 10/11 — Generated repository instructions

- **Complexity:** Straightforward — localized but privacy-sensitive history
  classification.
- **What:** Confirm the sanitized Codex shape, then recognize only complete
  AGENTS instruction envelopes at the existing history projection boundary.
- **Why:** F-12 exposes generated repository instructions and paths as authored
  user history.
- **Risk and test focus:** False positives: optional directory header, no-path
  form, mixed text, authored exact marker with submitted-user evidence, near
  matches, incomplete markers, casing, and outer whitespace.
- **Expected result:** Generated instructions disappear; authored content stays.
  User-visible privacy fix; no wire/database/client/analytics change.
- **Verification:** Failing regression first, focused rollout tests, all Codex
  tests, fatal analysis, `git diff --check`, report/tracker update. No
  architecture implementation review unless captured evidence broadens scope.

### Step 11/11 — Retire the plan

- **Complexity:** Trivial documentation lifecycle work.
- **What:** Record final PR/merge/verification evidence and move the entire plan
  directory from active to completed.
- **Why:** Completed work must not remain actionable.
- **Risk and test focus:** Missing links, wrong hashes/titles, incomplete finding
  acceptance, or a stale active copy.
- **Expected result:** One immutable completed record. No production,
  user-visible, wire, database, or analytics change.
- **Verification:** Cross-check all 12 finding items and 11 PRs; run
  `git diff --check`. No Dart/Flutter suites.

## Cleanup Assessment

- **Step 4:** Replace unconditional alias clearing with settled-item cleanup and
  retire aliases at item completion.
- **Step 5:** Generalize command-only correlation naming only where file changes
  use the same invariant; keep command and file queues distinct.
- **Step 7:** Remove the obsolete backend `thread/archive` request and its
  best-effort catch. Bridge archive persistence remains required.
- **Step 8:** Remove raw item-map inspection, the command-only lifecycle enum,
  and plugin-layer replay-policy decisions after typed owners replace them.
- **Step 9:** Delete `composer_attachment_support.dart` and its hardcoded
  plugin-name gate. Keep generated files because they are required outputs.
- **Step 10:** Reuse the existing generated-context filter; add no parser
  framework, path registry, raw payload logging, or persisted flag.
- **Step 11:** Move, rather than copy, the plan tree. After all dependent PRs
  merge, obsolete remote D1-D9 and Step 10 delivery branches/worktrees may be
  removed separately.
- **Retained intentionally:** `docs/codex-plugin-stability-report.md` remains the
  privacy-safe test evidence artifact, while this plan/tracker owns delivery.
  Existing wire fields, bridge archive data, rollout files, and tool identities
  remain product data, not cleanup candidates.

## Material Risks And Mitigations

- **Stack drift:** Updating D1 without forwarding it would make successor PRs
  appear to delete the plan. Merge each predecessor forward before opening its
  successor; never rebase.
- **False wrapper suppression:** Exact bounded structural checks remain local to
  known generated forms. Mixed-purpose code remains visible.
- **Accepted wrapper-language boundary:** The scanner balances the observed
  invocation through strings/comments and rejects visible nested `tools.*`
  calls. It intentionally does not tokenize JavaScript regex literals, template
  interpolation expressions, or complete brace/bracket grammar without an
  observed Codex fixture. The owner accepted this bounded risk on 2026-08-04.
- **Identity leaks or over-correlation:** Correlation remains per thread/turn and
  exact wrapper type, with authoritative completion cleanup.
- **False replay terminalization:** Only service-owned authoritative activity
  selects preserve-running; idle selects terminalization.
- **Attachment compatibility:** Missing capability means false. Disconnect clears
  provenance before queued attachment delivery.
- **F-12 false positives:** Require the full generated envelope and preserve
  exact authored text when submitted-user evidence exists. Do not expand to
  other upstream contextual markers without observed fixtures.
- **Scope expansion:** If F-12 requires live/cold cross-layer coordination or any
  later finding grows beyond its current owner and estimate, stop and ask before
  adding shared state or compatibility machinery.

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Verdict:** Approved with no findings.
- **Date:** 2026-08-04
- **Review scope:** `.plan/active/codex-plugin-stability-feedback/`
- **Applied corrections:** None required. The reviewed version passed the
  pre-review gate and the bridge, shared, and client architecture checks.

## Completion Criteria

The plan is complete only when all eleven delivery PRs merge in order, all
twelve finding acceptance entries are checked, Step 10 proves F-12 fixed without
hiding authored text, the stability report and tracker contain final evidence,
the plan directory is moved to `.plan/completed/`, and no successor PR still
depends on a branch scheduled for cleanup.
