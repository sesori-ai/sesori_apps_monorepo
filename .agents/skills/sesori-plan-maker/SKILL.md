---
name: sesori-plan-maker
description: Create or update practical, code-informed plans and trackers. Use ONLY when the user explicitly asks to make or change a plan or tracker. It may also self-invoke while planning a new feature, larger refactor, or other large effort that would benefit from multiple steps or PR splits. Do not self-invoke for routine implementation, small fixes, or ordinary single-step work.
---

# Plan Maker

When this skill is loaded, turn a user's goal into a practical implementation
plan grounded in the current codebase. Keep the process proportional to the
work. Prefer a short useful plan over a large planning system.

## User Direction

The user has final authority. Do not reject a request merely because it is not
planning work or is outside this skill's usual duty.

If a request is clearly outside planning and the user has not already
acknowledged that, say so briefly and ask once whether they want you to proceed.
If they confirm, or if they already explicitly told you to proceed despite the
planning context, do the work without questioning the choice again. This
includes implementation, tests, configuration, Git tasks, and plan updates when
permitted by the active environment.

Follow the user's latest explicit instruction when it conflicts with an older
plan or process preference. Explain concrete risks when useful, but do not use
the role, a plan, or a reviewer as a reason to overrule a confirmed decision.

## Planning

- Inspect relevant repository instructions, code, tests, history, and external
  references before making assumptions.
- Ask only questions that materially affect the result and cannot be answered
  from available context. Avoid exhaustive interviews and arbitrary checklists.
- Make scope, current behavior, proposed changes, ownership/data flow, important
  compatibility concerns, and verification concrete enough to implement.
- Scale detail to the task. A small change may need only a concise plan in chat;
  a multi-step effort may benefit from durable files under `.plan/active/<slug>/`.
- When updating an existing plan, preserve its useful structure rather than
  forcing a new schema. Keep its tracker or execution state in sync when needed.
- Do not invent stages, waves, PR boundaries, worktrees, or process artifacts
  unless they help the current work or the user asks for them.
- When intentionally splitting any task across multiple PRs, require every PR
  title to use
  `<emoji> [<slug>] <description> [step <x>/<y>]`. For durable planned
  work, `<slug>` is exactly the plan directory name under `.plan`; do not invent
  a separate series slug. Without a durable plan, choose one stable, lowercase
  kebab-case slug. Fix the step order/total for the whole series, including each
  step's complexity emoji, and do not apply the slug/step wrapper to a single-PR
  task.
- Target no more than 1,500 changed lines per PR as a soft cap, counting
  additions plus deletions, generated code, and tests. Prefer a coherent split
  before exceeding it; when a smaller independently valid PR is not practical,
  record the reason for the expected overage in the plan.
- For durable planned work, the first PR step always raises the plan under
  `.plan/active/<slug>/` before implementation begins. The penultimate step
  reconciles and completes the affected feature documents under
  `docs/regression/`. The final step runs the level and matrix already recorded
  in `PLAN.md`, records the result, and retires the plan by moving it to
  `.plan/completed/<slug>/` only after that coverage passes.
  Include all three lifecycle steps in the fixed step total.

For a new durable plan, `PLAN.md` should normally capture the goal, scope,
relevant current behavior, concrete implementation steps, verification, and
material risks or decisions. Add a lightweight `TRACKER.md` or step files only
when they will help execution.

The plan must identify affected regression feature documents, the highest
coverage level needed for the delivered behavior, and any required plugin,
platform, client, packaged, or external-service matrix. Follow the proof-boundary
and retirement rules in `docs/regression/README.md`; choose enough coverage to
prove every materially delivered behavior through its complete authoritative
boundary, never a lower level merely because it is cheaper. Any reduction to
the recorded matrix requires explicit user acceptance in `PLAN.md` before
retirement.

## Evidence And Proportionality

### Prefer Elegant, Low-State Designs

- Before adding persistence or coordination, inspect existing fields, event
  shapes, and relevant Git history. Reuse a semantically adequate signal and
  narrow the product claim when needed rather than duplicating state solely to
  manufacture perfect provenance for a low-impact heuristic.
- Treat every new mutable field, map, queue, registry, timer, subscription,
  dedupe set, pending state, and lifecycle hook as a new failure point with an
  ongoing maintenance cost. Count mutable parts explicitly before accepting a
  design, not only changed lines or PR size.
- First find the narrowest existing owner that already knows the authoritative
  outcome. Prefer one post-success write at that seam over reconstructing intent
  later from events, payload shapes, timing, or backend-specific classifiers.
- A backend-neutral behavior should not require custom production logic in each
  plugin unless the behavior genuinely depends on backend semantics. If a plan
  touches every plugin to infer the same product fact, treat that as a design
  alarm: look for a bridge-core action or normalized contract that already owns
  the fact, or narrow the promised behavior.
- Prefer an honest product limitation over machinery that guesses unobservable
  provenance. Supporting fewer authoritative flows cleanly is better than
  claiming broad support through dedupe caches, correlation state, reconnect
  reconciliation, and plugin-specific heuristics.
- Before finalizing a plan, include a complexity budget: name the new persistent
  and in-memory mutable parts, justify each one, and state which tempting pieces
  are deliberately not being added. If the feature's coordination machinery is
  larger than its primary behavior, redesign or ask the user before proceeding.
- When review feedback adds mutable coordination one edge case at a time, stop
  and reconsider the root seam instead of accumulating guards. Do not let a
  sequence of locally valid findings turn a simple behavior change into a state
  machine without explicit user approval.

- Classify each planned safeguard as addressing an observed failure, an ordinary
  reachable user flow, or a theoretical interleaving. A reviewer suggestion or
  a test that can synthetically force a race is not by itself product evidence.
- Before adding coordination, state the concrete flow, user/data consequence,
  and what happens if nothing changes. Account for existing ordering, retries,
  recovery, idempotency, and refresh behavior instead of assuming every
  transient state must be made impossible.
- Require observed evidence or a plausible ordinary flow with meaningful impact
  before adding locks, lanes, registries, provisional states, lifecycle owners,
  compatibility paths, or exhaustive cross-repository filtering. Explicitly
  accept bounded transient or self-healing behavior when its impact is minor.
- Prefer the coarsest simple mechanism that preserves the required invariant.
  Do not add per-resource concurrency, parallelism, or bypass closure when a
  small serialized domain boundary is sufficient and throughput is unproven.
- Treat cross-cutting coordination as a scope alarm. If an unobserved safeguard
  grows into shared state across several owners/layers, materially exceeds its
  estimate, or becomes comparable in size to the primary feature, stop and ask
  the user whether that risk justifies the complexity before planning or applying
  more fixes.
- Re-run this proportionality check when architecture review or PR feedback
  expands scope. Apply findings that protect the approved core behavior, but do
  not treat architectural completeness as a reason to implement increasingly
  defensive machinery around a low-impact theoretical edge.
- For durable plans, record both the evidence level and any intentionally
  accepted risk. This keeps later reviewers from reopening a declined theoretical
  concern without new evidence.

## PR Complexity and Communication

Assign every planned or opened PR one implementation-complexity level represented
by its fixed emoji:

- `🌱` — trivial: isolated documentation, copy, or mechanical work;
- `🌿` — straightforward: localized implementation with a small blast radius;
- `⚙️` — moderate: several files or layers, meaningful state, or notable edge
  cases;
- `🚧` — complex: cross-layer flow, persistence, concurrency, lifecycle,
  compatibility, or security-sensitive behavior; and
- `🚨` — very complex: several coupled high-complexity concerns or a broad,
  high-stakes migration.

Complexity describes implementation and review difficulty, not risk by itself.
Choose it from the actual coupling, state transitions, migration/codegen,
concurrency, compatibility, privacy/security, and verification burden; do not
rate every PR in a series identically by default.

For a single-PR task, prefix the normal title with `<emoji>`. For a multi-PR
task, place the emoji first:
`<emoji> [<slug>] <description> [step <x>/<y>]`. Treat the emoji as part of
the fixed exact title. If implementation evidence changes the estimate before
the PR opens, update the plan/tracker title rather than knowingly publishing a
stale rating.

Make every planned PR concrete enough that its eventual PR body can briefly and
clearly state:

- **Complexity:** level plus a one-sentence rationale;
- **What:** what the PR changes;
- **Why:** why that change is needed now;
- **Risk and test focus:** risk level, potentially impacted flows, screens,
  data, integrations, or functionality, and the highest-value checks; and
- **Expected result:** what a reviewer should observe after running it,
  explicitly covering user-visible behavior, persisted/database changes, and
  pure internal/refactor effects as applicable.

Use an explicit `None` or `No user-visible/database change` rather than omitting
a category. Keep these summaries proportional; they are an operational review
aid, not a duplicate design document.

Whenever you create or materially update a PR yourself, render those categories
as `## Complexity`, `## What`, `## Why`, `## Risk and test focus`, and
`## Expected result`, followed by the relevant verification section. Use real
multiline Markdown through `--body-file` or stdin.

## Cleanup Assessment

For every feature plan, actively inspect what the new behavior makes obsolete.
Consider calculations and data generation, model fields, database columns,
transport fields, caches, flags/settings, jobs/watchers/listeners, compatibility
paths, UI state, tests, and documentation. Look for causal cleanup such as data
that no longer needs to be generated, persisted, transported, or rendered.

Record one honest outcome in the plan:

- include small, safe, directly caused cleanup in the appropriate feature PR;
- place a larger but valuable cleanup in its own coherent planned PR;
- defer cleanup when migration, compatibility, rollout, or risk requires it and
  state the reason; or
- state that no relevant cleanup was found.

Do not keep obsolete artifacts solely for auditing when Git history already
preserves them. Cleanup is still not permission for speculative scope growth:
preserve required wire/data compatibility, and explain approximate size and ask
the user before planning a considerable refactor.

## Plan Review

Use `architecture-plan-review` only for architecture-bearing production plans,
as defined by repository instructions. Ask a sub-agent to perform the review
using the skill. Apply valid findings directly and do not invoke it again merely
to approve those fixes.

If the reviewer rejects a plan as too vague, clarify the listed gaps and invoke
it once more. If the second review also rejects the plan as too vague, ask the
user how to proceed. A reviewed plan may also be reviewed again after
considerable changes caused by new findings or user requests; routine edits do
not require another review.

If applying a finding would change user intent or materially expand scope, ask
the user for that decision. Record the review result and resulting corrections
honestly; do not claim the reviewer approved a revised plan unless that version
was reviewed and passed.

## Working Style

Follow repository instructions and normal Git safety rules. Make the smallest
change that satisfies the request, keep unrelated work intact, verify what you
change, and state clearly what remains unresolved. Include tests only when they
provide meaningful confidence.

Apply the cleanup assessment above without mixing unrelated refactors into a
feature. Prefer a dedicated PR when a coherent cleanup is independently useful.
