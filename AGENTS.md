# Sesori Agent Context

`AGENTS.bak.md` is a historical archive, not active instruction. Do not use it
as guidance unless the user explicitly asks to inspect the old rules.

## Project And Stakes

Sesori lets developers monitor and control AI coding sessions from phone and
desktop surfaces. A local bridge connects those surfaces to coding backends
through a relay and a plugin boundary.

This is security-sensitive developer tooling. Source-code privacy,
authentication, encryption, and persisted session integrity are high-stakes;
ordinary UI polish should not receive the same verification cost.

## North Star

Sesori is becoming an ambient developer cockpit:

- Multiple surfaces and multiple bridges are first-class, not future edge cases.
- Backend-specific behavior stays inside its plugin package. Shared code and
  clients consume backend-neutral contracts and declared capabilities.
- Shared business logic stays surface-neutral; phone, desktop, and future web
  shells remain thin.
- Bridge capabilities remain usable headlessly, without a desktop GUI.
- Local E2E and managed trusted modes are separate trust postures. Never weaken
  one to simplify the other.
- Humans and future automation control sessions through the same API seam.

Direction breaks ties between otherwise-good designs. It does not justify
building abstractions before a current requirement needs them.

## High-Level Shape

- `bridge/` is pure Dart and owns the headless bridge plus backend plugins.
- `client/` contains Flutter product shells and pure-Dart shared business logic.
- `shared/sesori_shared/` contains cross-product protocol and crypto primitives.
- The main data path is client <-> relay <-> bridge <-> backend plugin.
- Within a product area, dependencies flow
  `Foundation -> API -> Repository -> Service -> Consumer`. Do not skip layers.

The code is the source of truth for exact files, classes, and current behavior.
Scoped `AGENTS.md` files and deeper docs contain area-specific context. Read
them when the task touches that area or they appear relevant; do not load them
eagerly "just in case."

## Working Rules

- Prefer the smallest change that fully solves the demonstrated problem. Do not
  add machinery for hypothetical consumers, rare timing windows, or future work.
- Use named parameters with `required`, including nullable parameters. The only
  positional exception is the primary text/message argument of logging APIs.
- Use enums for simple closed scalar sets and sealed classes for variants that
  carry different data or behavior. Parse external strings at the boundary;
  never use magic strings for domain state or decisions.
- Never use an empty string to represent missing data. Use `null` when absence
  is meaningful; do not avoid nullability when it accurately models the domain.
- For legacy transport omission, prefer an honest `@Default` over nullable
  modern state when one valid meaning exists. Add a dated compatibility comment
  with the legacy rationale and exact cleanup:
  `// COMPATIBILITY YYYY-MM-DD (vX.Y.Z): ...`
- For database fields that should always contain data after migration, prefer
  an honest backfill and a non-null column. Keep the field nullable when absence
  is genuinely meaningful or no valid backfill exists.
- Never hand-edit generated files. Change their source and run the generator.
- Create and update GitHub PR bodies with real multiline Markdown through
  `--body-file` or stdin; never pass escaped `\n` text. Read the body back with
  `gh pr view` and verify that it has no literal newline escapes or wrapping quote.
- App/bridge public and wire changes must consider compatibility in both
  directions: older app -> newer bridge and newer app -> older bridge. Preserve
  existing behavior with honest defaults or graceful degradation where
  possible; when an older peer cannot support new behavior, surface that
  limitation explicitly instead of silently breaking an existing flow.
- A recovered failure that continues must remain observable. Do not add a
  redundant log when the error is rethrown or returned as an explicit failure.

## Verification And Review

- For localized production changes, run directly relevant tests and analyze the
  owning package or module. CI runs the full test and analyzer matrix; investigate
  failures reported by the PR monitor rather than duplicating that matrix locally.
- Instruction, documentation, plan, agent, and skill changes need only their own
  relevant validation. Do not run Dart/Flutter suites for non-code changes.
- Add tests only when they provide meaningful confidence; do not create tests
  solely to satisfy a process checklist.
- Do not rerun an unchanged passing command or reread unchanged files solely for
  additional confidence. Expand verification only when impact or a failure gives
  a concrete reason.
- Aristotle is an architecture reviewer, not a general implementation or code
  correctness reviewer. Invoke it only for architecture-bearing production work:
  new or moved production classes/files, dependency or DI ownership changes,
  public/wire/persisted contracts, cross-layer flow, lifecycle triggers, or
  shared boundaries.
- Do not invoke Aristotle for docs, instructions, agent/skill definitions,
  tests-only edits, formatting, copy, localized bug fixes, ordinary method logic,
  or non-architectural tooling changes. Broader wording in reviewer metadata
  applies only within this architecture scope.
- Apply valid `aristotle-plan-review` findings directly without re-reviewing the
  fixes. A too-vague rejection may be reviewed once more after clarification;
  if it is rejected as too vague again, ask the user how to proceed. Considerable
  plan changes caused by new findings or user requests may also be reviewed again.
- Use `aristotle-impl-review` at most twice before asking the user how to proceed.
  If rejection is based only on an explicitly approved user decision, that
  decision supersedes the review; do not re-review or re-litigate it.
- Prefer a Git-defined implementation-review scope such as the current branch
  against `main`, a commit range, the last N commits, or a PR. File or directory
  scopes are also valid when useful; the reviewer uses Git history and diffs
  where available to avoid treating pre-existing code as part of the change.
- Do not let implementation review expand the work into a broad cleanup. If a
  finding would move, rename, or refactor pre-existing files, classes, or
  architecture beyond the current request, ask the user whether that scope
  expansion is acceptable before making it.
- These review rules supersede broader Aristotle requirements in older roadmap
  or plan documents.
- Cleanup and refactoring are acceptable when the value is clear. Before a
  considerable refactor, explain its approximate size and ask the user to
  approve it. Prefer a dedicated PR without unrelated functionality changes
  when practical.

## Repeated Pitfalls

- Do not solve speculative edge cases with broad locks, registries, lifecycle
  machinery, or abstractions unless a plausible flow and meaningful impact exist.
- Do not let backend concepts, identifiers, payload assumptions, or behavior
  escape the owning plugin package.
- Do not enter a verification spiral: once relevant evidence passes and inputs
  have not changed, finish the task.
