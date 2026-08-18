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
- The project uses Dart primary constructors shipped in Dart 3.13. This syntax
  is valid and supported by the pinned toolchain; do not rewrite it as invalid
  or replace it with legacy constructor syntax.
- Use enums for simple closed scalar sets and sealed classes for variants that
  carry different data or behavior. Parse external strings at the boundary;
  never use magic strings for domain state or decisions.
- Make impossible state combinations unrepresentable. When variants have
  different valid data, give each sealed variant only its required non-nullable
  fields instead of flattening them into nullable coordination fields, booleans,
  or sentinel values. Model independent state machines as separate sealed types
  and compose their non-null instances.
- Never use an empty string to represent missing data. Use `null` when absence
  is meaningful; do not avoid nullability when it accurately models the domain.
- Bridge code must resolve the user home directory with
  `resolveUserHomeDirectory` from `sesori_bridge_foundation`; never read `HOME`
  or `USERPROFILE` directly.
- For legacy transport omission, prefer an honest `@Default` over nullable
  modern state when one valid meaning exists. Add a dated compatibility comment
  with the legacy rationale and exact cleanup:
  `// COMPATIBILITY YYYY-MM-DD (vX.Y.Z): ...`
- For database fields that should always contain data after migration, prefer
  an honest backfill and a non-null column. Keep the field nullable when absence
  is genuinely meaningful or no valid backfill exists.
- Never hand-edit generated files. Change their source and run the generator.
- Add or update the relevant `docs/regression/` feature document when adding a
  feature or materially changing existing feature behavior.
- Create and update GitHub PR bodies with real multiline Markdown through
  `--body-file` or stdin; never pass escaped `\n` text.
- Every PR title starts with one implementation-complexity emoji: `🌱` trivial,
  `🌿` straightforward, `⚙️` moderate, `🚧` complex, or `🚨` very complex.
  Complexity is implementation/review difficulty, not the risk rating.
  Single-PR tasks use `<emoji> <normal title>`.
- Every PR body includes concise `## Complexity`, `## What`, `## Why`,
  `## Risk and test focus`, and `## Expected result` sections. State explicitly
  when there is no user-visible or database impact; keep verification as an
  additional section.
- Assume the user will not inspect local-only changes unless they explicitly say
  they will. Once a task is complete and ready for code review or implementation
  testing, commit, push, and open a PR by default. Leave changes local only when
  the user explicitly requests that.
- When splitting any task across multiple PRs, title every PR
  `<emoji> [<slug>] <description> [step <x>/<y>]`. For planned work,
  `<slug>` is the plan directory name under `.plan`; otherwise choose one
  stable, lowercase kebab-case slug. Keep one total for the whole series.
- Backward and forward compatibility is required only for transport
  contracts exchanged between the client and bridge, because an older app can
  use a newer bridge and a newer app can use an older bridge. Preserve those
  wire contracts with honest defaults or graceful degradation where possible;
  when an older peer cannot support new behavior, surface that limitation
  explicitly instead of silently breaking an existing flow.
- Compatibility baselines include only public production releases. Internal,
  prerelease, development, and otherwise unpublished builds do not create a
  compatibility obligation. Breaking changes between internal releases are
  explicitly allowed and should normally replace the old implementation
  cleanly. Never infer a migration or compatibility requirement merely because
  code existed on `main`, carried an internal tag, or was exercised by an
  internal build. When state, storage, a route, or a wire shape appeared only in
  those builds, remove the obsolete code, models, tests, and handlers; do not
  add migrations, fallbacks, shims, dual reads/writes/routes, or retained
  contracts solely for unpublished peers. Preserve compatibility only when the
  behavior actually reached a public production release or the user explicitly
  requires it.
- Dart/Flutter modules and plugin interfaces/packages have no external
  consumers outside this repository and update together. Do not add
  compatibility shims, optional parameters, or legacy API paths for those
  internal contracts; update every in-repository consumer in lockstep instead.
- A recovered failure that continues must remain observable. Do not add a
  redundant log when the error is rethrown or returned as an explicit failure.
- A failure response sent to a remote client does not replace a useful local log
  when only that log retains the original error, stack trace, or operation context.
- Preserve diagnostically useful errors, stack traces, paths, identifiers, and
  operation context in local bridge and client logs. Logs are not submitted
  automatically; users choose whether to inspect, anonymize, and share them.
  Strip only known user data that has no debugging value (for example prompt or
  transcript content), and remove that field selectively rather than suppressing
  an entire error or category because it might contain sensitive data.
- When translating a caught error into another error, retain the original in a
  typed `innerError` or `cause` field instead of discarding it. Keep the
  wrapper's presentation privacy-safe when the original may contain sensitive
  payload data.

## Analytics

- When adding a user-facing feature or action, consider whether analytics would
  answer a product decision, activation/retention question, or feature-adoption
  question. Do not track every tap. Load
  `.opencode/skills/add-analytics/SKILL.md` for the event-design, privacy,
  architecture, and reporting checklist.
- Instrument the authoritative outcome rather than a UI proxy, use closed
  bounded parameters, and never report source code, prompts, transcripts,
  paths, names, raw error text, or raw/hashed entity identifiers.
- The closed event source of truth lives under
  `client/module_core/lib/src/foundation/models/product_analytics/`. Consumers
  use `ProductAnalyticsService` for account-linked events and
  `InstallationAnalyticsService` only for the approved account-less login
  funnel. Product shells never send arbitrary names or parameter maps.

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
- Architecture review is handled by two skills — `architecture-plan-review`
  and `architecture-implementation-review` — that are architecture reviewers,
  not general implementation or code correctness reviewers. Invoke them only for
  architecture-bearing production work: new or moved production classes/files,
  dependency or DI ownership changes, public/wire/persisted contracts,
  cross-layer flow, lifecycle triggers, or shared boundaries. Both skills are
  invoked through a sub-agent: ask a sub-agent to perform the review using the
  skill, rather than loading the skill directly in the main agent context.
- Do not invoke the architecture reviewers for docs, instructions, agent/skill
  definitions, tests-only edits, formatting, copy, localized bug fixes, ordinary
  method logic, or non-architectural tooling changes. Broader wording in
  reviewer metadata applies only within this architecture scope.
- Apply valid `architecture-plan-review` findings directly without re-reviewing
  the fixes. A too-vague rejection may be reviewed once more after clarification;
  if it is rejected as too vague again, ask the user how to proceed. Considerable
  plan changes caused by new findings or user requests may also be reviewed again.
- Use `architecture-implementation-review` at most twice before asking the user
  how to proceed. If rejection is based only on an explicitly approved user
  decision, that decision supersedes the review; do not re-review or re-litigate
  it.
- Prefer a Git-defined implementation-review scope such as the current branch
  against `main`, a commit range, the last N commits, or a PR. File or directory
  scopes are also valid when useful; the reviewer uses Git history and diffs
  where available to avoid treating pre-existing code as part of the change.
- Do not let implementation review expand the work into a broad cleanup. If a
  finding would move, rename, or refactor pre-existing files, classes, or
  architecture beyond the current request, ask the user whether that scope
  expansion is acceptable before making it.
- These review rules supersede broader requirements in older roadmap or plan
  documents.
- Cleanup and refactoring are acceptable when the value is clear. Before a
  considerable refactor, explain its approximate size and ask the user to
  approve it. Prefer a dedicated PR without unrelated functionality changes
  when practical.

## Repeated Pitfalls

- Do not solve speculative edge cases with broad locks, registries, lifecycle
  machinery, or abstractions unless a plausible flow and meaningful impact exist.
- Edge cases are infinite; completeness is not the goal. Guarding a state no
  current flow produces adds code to the path that runs constantly, in order to
  defend a path that never runs. That trade is a net loss: the guard itself
  becomes a new failure point. Prefer leaving the unreachable case unhandled.
- Before adding a guard, name the concrete flow that reaches the bad state and
  the damage if it does. If you cannot name a real caller or sequence that
  produces it, do not write the guard. "An API technically accepts it" and "a
  misbehaving or future client might" are not flows.
- Defensive depth must stay proportional to damage. A rare case that degrades a
  screen, fails one request, or shows a stale value does not justify tree walks,
  cascade checks, extra queries on hot paths, or new coordination.
- Weigh every defense and compatibility measure as effort-versus-damage: the
  probability of the case actually occurring times the harm when it does,
  against the complexity the measure adds everywhere it touches. When the
  damage is very low — cosmetic residue, a slightly wrong display for old data,
  a rare leaked local file, a stale value that self-corrects — accept it and
  add nothing, even when a fix is straightforward.
- This explicitly covers low-damage backward compatibility: a new feature does
  not owe migrations, schema changes, backfills, or fallback paths just so
  pre-existing sessions or rows render perfectly. If the worst outcome for old
  data is a minor visual or informational imperfection, ship without the
  compatibility machinery and leave old data as-is. Reserve compatibility work
  for real damage: data loss, broken core flows, security, or a violated
  public wire contract.
- Enforce an invariant at the one place that owns it, on the entity the caller
  named. Do not extend it outward to parents, children, families, or related
  entities in case someone reaches them another way.
- Do not let backend concepts, identifiers, payload assumptions, or behavior
  escape the owning plugin package.
- Do not enter a verification spiral: once relevant evidence passes and inputs
  have not changed, finish the task.
