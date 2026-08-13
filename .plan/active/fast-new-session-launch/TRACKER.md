# Fast New Session Launch: Tracker

## Current State

- **Plan slug:** `fast-new-session-launch`
- **Implementation base:** `origin/main` at `14a4e405`
- **Current branch:** `speed-up-new-session-load`
- **Series state:** Step 1/6 plan ready for delivery
- **Current step:** commit, push, and open plan PR
- **Next action:** deliver Step 1 and monitor its checks/review

## Locked Decisions

- [x] Sesori has a stable `ses_...` ID, but allocates it only after plugin
  creation; no pending stable route is added.
- [x] Send immediately renders detail-shaped launch UI on
  `/projects/<projectId>/sessions/new`.
- [x] Real route replacement waits for a durable, queryable Sesori session.
- [x] Metadata/title leaves the create-response critical path.
- [x] Initial prompt, attachment, and slash-command acceptance remain
  synchronous.
- [x] Dedicated worktrees use local curated `color-animal` names.
- [x] Pair collisions retry another pair; bounded exhaustion uses a secure
  suffix.
- [x] Failure automatically restores the filled composer; no automatic resend.
- [x] Because current server errors can occur after durable commit, every
  creation-originated error receives the duplicate-risk warning.
- [x] Back continues creation in the background.
- [x] Implementation stays backend-neutral; final matrix enumerates registered
  production plugins at execution time.
- [x] Detail snapshot staging is out of scope; its loading presentation becomes
  visually continuous with launch.
- [x] Performance proof uses tests plus recorded manual timings, not telemetry.

## Complexity Guardrails

- [ ] No database migration or pending-session persistence.
- [ ] No new client-to-bridge wire route/event/model; the existing auth metadata
  POST gains only a typed request source.
- [ ] No idempotency key, retry registry, polling, or newest-session heuristic.
- [ ] No plugin-name branch or per-plugin production implementation.
- [ ] No optimistic transcript/prompt row or partial detail snapshot.
- [ ] One client submission snapshot only; no hidden attachment cache.
- [ ] One transient sealed restore state consumes that snapshot once; ordinary
  rebuilds never reapply attachments.
- [ ] Background leave retains submission bytes only until the in-flight request
  settles; no additional cache or persistence extends that lifetime.
- [ ] `PromptInput` passes the exact trimmed `ComposerDraft`; do not reconstruct
  voice provenance from an input-mode enum.
- [ ] Preserve restoration snapshots and creation warnings across reconnect/
  discovery/options refreshes; clear only on consumption, explicit submission,
  or route exit as appropriate.
- [ ] Incrementally encode attachment-bearing create requests with bounded
  event-loop yields through base64, inner JSON, and outer relay-envelope
  JSON/UTF-8; do not copy bytes through isolates or couple the Cubit to frame
  lifecycle.
- [ ] A background failure after route exit must not restore shared draft state.
- [ ] In-route failure restores both the Cubit's cached draft and repository
  before `PromptInput` remounts.
- [ ] Preserve nullable title handoff; never convert missing title to `""`.
- [ ] Extend authenticated `SesoriServerApi` for metadata, including token
  acquisition and one 401 refresh/retry; do not split one provider by use case.
- [ ] One late-title future set; drain actual workflows, abort metadata HTTP on
  shutdown, and deadline-bound standalone token refresh.
- [ ] Keep the normalized event consumer alive through late-title drain, then
  drain its tails before dispatcher disposal.
- [ ] Shared encryption returns preallocated typed bytes without boxed integer
  framing; analyze/test shared crypto and bridge relay callers explicitly.
- [ ] Generalize the existing deletion stream/listener; do not add a second
  local mutation stream.
- [ ] Delete obsolete overlay, metadata naming, preferred-name, enrichment, and
  tests in the same owning steps.

## Delivery Steps

| Done | Step | Exact PR title | State |
|---|---|---|---|
| [ ] | 1/6 | `🌱 [fast-new-session-launch] docs: plan faster new-session launch [step 1/6]` | Drafting |
| [ ] | 2/6 | `🌿 [fast-new-session-launch] feat(bridge): use local workspace names [step 2/6]` | Blocked on Step 1 merge |
| [ ] | 3/6 | `🚧 [fast-new-session-launch] feat(bridge): return sessions before generated titles [step 3/6]` | Blocked on Step 2 merge |
| [ ] | 4/6 | `⚙️ [fast-new-session-launch] feat(client): open launching sessions immediately [step 4/6]` | Blocked on Step 3 merge |
| [ ] | 5/6 | `🌱 [fast-new-session-launch] docs: define launch regression coverage [step 5/6]` | Blocked on Step 4 merge |
| [ ] | 6/6 | `🌿 [fast-new-session-launch] test: verify faster new-session launch [step 6/6]` | Blocked on Step 5 merge |

## Step 1 Checklist

- [x] Trace client create, navigation, detail loading, and retry behavior.
- [x] Trace bridge stable/backend IDs, creation timing, event ordering, and
  failure behavior.
- [x] Inspect history, tests, regression docs, and prior rejected provisional
  state machinery.
- [x] Agree product experience, naming, failure, plugin, cleanup, and measurement
  choices with the user.
- [x] Inventory causal cleanup and explicit deferrals.
- [x] Record complexity budget, compatibility, L3 boundary, and required matrix.
- [x] Run architecture plan review and apply valid findings.
- [x] Run plan consistency checks and `git diff --check`.
- [ ] Commit, push, open Step 1 PR, and record its URL/review result.

## Cleanup Ledger

| Artifact | Decision | Owning step |
|---|---|---|
| Layer-skipping `MetadataService` and AI branch/worktree response fields | Replace with shared typed request plus title-only API/repository and regenerate | 3 |
| Preferred-name API/validator and tests | Delete | 2 |
| Current `session-*` random fallback | Replace with color-animal plus bounded suffix fallback | 2 |
| Synchronous generated-title await | Delete from response path | 3 |
| Single-session enrichment and unused plugin mapper helpers | Delete | 3 |
| Deletion-only local mutation stream/listener | Generalize/rename in place | 3 |
| Dimming `NewSessionLoadingOverlay` and overlay tests | Delete | 4 |
| Direct mobile `cue` dependency | Delete if no consumer remains | 4 |
| Friendly rotating-copy timer | Keep one instance in exported `module_prego` launch status | 4 |
| Composer submission bytes/text snapshot | Release on success/restoration or when a background request settles; never persist attachments | 4 |
| Auth response branch/worktree keys | Defer for released-bridge compatibility | External follow-up |
| Pending session/idempotency/detail staged load | Explicitly out of scope | Separate evidence-backed work |

## Verification Record

### Automated

- Step 1 merge-base size:
  `git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD -- .plan/active/fast-new-session-launch/PLAN.md .plan/active/fast-new-session-launch/TRACKER.md`
- Informational result including this record, within the 750-900 target:
  `PLAN.md +756`, `TRACKER.md +144`, total `+900 / -0`.

### Manual matrix

Pending Step 6. Enumerate `knownPlugins` from the build under test rather than
copying a historical list here.

### Timing evidence

Pending Step 6. Record only privacy-safe durations for launch view, real route,
and complete detail snapshot under matched baseline/final conditions.

## Plan Review

- **Reviewer:** `architecture-plan-review` sub-agent
- **Result:** Draft rejected on three under-specified ownership boundaries;
  findings applied directly without a second review, per repository policy.
- **Applied findings:** exact `OrchestratorSession` shutdown order; metadata
  API/repository layers; `module_prego` launch primitive with app-owned copy.
- **Consistency corrections:** one-shot attachment consumption, initial
  backend-title semantics, and penultimate-doc-step rationale.
