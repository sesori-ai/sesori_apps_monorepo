---
name: update-backend-runtimes
description: >-
  Plan a coordinated runtime-target refresh for every supported Sesori harness:
  OpenCode, Antigravity, Codex, GitHub Copilot, Cursor, Claude Code, Hermes Agent,
  Pi, Oh My Pi, DeepSeek, and Grok Build. Audit releases, managed assets, adapter
  release dependencies, capability gaps, and simplifications; ask before adopting
  extra features. Use for harness target updates, runtime pins, or release audits.
metadata:
  audience: maintainers
  workflow: github
---

# Update Backend Runtimes

Produce a code-informed plan to refresh **all registered harnesses**, not an
immediate batch of version edits. Audit the actual protocol seam Sesori uses,
report worthwhile upstream changes, and ask for guidance before adding them to
implementation scope. Updating this skill alone does not start a runtime audit.

This is the single runtime-update skill. Harness-specific details live in
[the harness reference](references/harnesses.md), not separate skills. Read that
reference for every harness being audited. Repository paths below are relative
to the repository root; linked reference and sibling skill paths are relative
to this skill directory.

## 1. Inventory every harness

Read relevant repository instructions, then inspect:

- `bridge/app/lib/src/runtime/plugin_registry.dart` (`knownPlugins`);
- each registered descriptor, its target/minimum declarations, launch policy,
  runtime manifest or release facts, and focused tests;
- `docs/HARNESS_CAPABILITIES.md` and affected `docs/regression/` documents.

The explicit inventory is:

| Harness | Plugin directory under `bridge/` | Target / compatibility authority |
|---|---|---|
| OpenCode | `sesori_plugin_opencode` | `lib/src/runtime/open_code_runtime_manifest.dart` |
| Antigravity | `sesori_plugin_antigravity` | `lib/src/foundation/antigravity_release.dart`; `lib/src/runtime/antigravity_runtime_manifest.dart` |
| Codex | `sesori_plugin_codex` | `lib/src/runtime/codex_runtime_manifest.dart` |
| GitHub Copilot | `sesori_plugin_copilot` | `lib/src/runtime/copilot_runtime_manifest.dart` |
| Cursor | `sesori_plugin_cursor` | `lib/src/runtime/cursor_runtime_manifest.dart` |
| Claude Code | `sesori_plugin_claude` | `lib/src/runtime/claude_plugin_descriptor.dart` |
| Hermes Agent | `sesori_plugin_hermes` | `lib/src/runtime/hermes_plugin_descriptor.dart` |
| Pi | `sesori_plugin_pi` | `lib/src/runtime/pi_runtime_manifest.dart` |
| Oh My Pi (OMP) | `sesori_plugin_omp` | `lib/src/runtime/omp_runtime_manifest.dart` |
| DeepSeek | `sesori_plugin_deepseek` | `lib/src/runtime/deepseek_runtime_manifest.dart` |
| Grok Build | `sesori_plugin_grok` | `lib/src/runtime/grok_plugin_descriptor.dart` |

Treat the registry, not this table or a capability-matrix column count, as truth.
Shared ACP, interface, foundation, and runtime packages are not harnesses.
Reconcile the registry, this inventory, reference sections, and plan rows before
claiming coverage. **If anything is omitted, add its inventory/reference entry
and an explicit skill-correction task to the same plan**, including discovery,
release ownership, verification, and unknowns. Do not drop a harness because it
is PATH-only, already current, blocked, proprietary, or unfamiliar. Correct stale
entries when registration changes. Even an explicitly user-scoped audit lists
all other harnesses as excluded by that request rather than silently omitting them.

## 2. Establish releases and dependencies

For every harness record current target, candidate version/date, compatibility
policy, release source, immutable revision when available, distribution/layout,
platform coverage, and required owning repositories. Use the reference to
identify the release channel; query it afresh rather than copying example pins.

- Prefer official stable releases. Do not silently substitute `main`, a
  prerelease, a fork, a different package, or a community adapter. Report channel
  disagreement or missing stable releases. Existing prerelease dependencies
  inside an adapter are recorded honestly, not silently replaced or upgraded.
- Distinguish upstream harness version, adapter version, protocol version,
  registry package version, and branded build identity. They need not match.
- For GitHub releases check draft/prerelease flags, tag, date, assets and digests.
  Compare npm's stable version where the reference calls for it. Parse official
  installers as text when necessary; never execute them merely for discovery.
- Resolve old/new public source tags to immutable commits before auditing;
  re-check their identities before finalizing the plan and before implementation.
  Stop that harness's pinning if a tag moved or evidence is ambiguous. For closed
  source, record the official distribution/build evidence and source limitation.
- Audit owned adapters as well as their underlying harness. DeepSeek may require
  changes and a release in `sesori-ai/sesori-deepseek-acp` **before** this repo can
  consume the new harness. Put producer changes, conformance, publication, asset
  verification, and consumer pinning in the same dependency-ordered plan.

Keep independent `minPathVersion` / `minVersion` backing values unchanged unless
raising them is separately approved. Targets describe validated releases, not
permission to reject otherwise-compatible PATH installs. Antigravity currently
has an exact identity/pair contract rather than an independent semantic floor;
report that exception and its replacement impact, never claim an unchanged
independent minimum. Ask before broadening or tightening its compatibility policy.

## 3. Audit changes and find opportunities

Compare the complete old/new release range in aggregate, then inspect relevant
source and intermediate release notes. Inventory every changed area, including
packaging, dependencies, helpers, schemas and launch wrappers. Check GitHub
compare pagination/truncation; a capped file list or missing patch is not proof
of absence. If needed, fetch source-only objects into a disposable bare Git store
under the allowed worktree and diff immutable commits there. Never fetch upstream
objects into Sesori's shared Git database, create another checkout/worktree when
prohibited, or execute upstream build code during source inspection. Retain
partial evidence until inspected or recorded as incomplete.

For each worthwhile change, trace serialization and forwarding to the production
seam: REST/SSE, app-server, stream-json, Pi RPC, or the specific ACP adapter.
An internal event, schema declaration, TUI feature, or generic ACP capability is
not proof that this harness exposes it. Record exact methods/fields, ordering,
acceptance versus completion, cancellation/queue ownership, and capability gates.
For proprietary runtimes, use official protocol evidence and bounded probes;
label what cannot be verified instead of inventing source access.

Explicitly look for:

1. **Simplifications:** native behavior that removes or shortens bridge/plugin/
   client workarounds, local history readers, polling, state, or custom adapters.
   Name the existing code and actual flow that would disappear or become simpler.
2. **Parity gaps:** compare every relevant row in `docs/HARNESS_CAPABILITIES.md`,
   including both not-implemented and previously not-supported cells. Name the
   harness, matrix row, old limitation, and new seam evidence that might lift it.
3. **Other material changes:** models/providers, authentication, approvals,
   security, sessions/history, subagents, tools/images, settings, performance,
   deprecations, platform support, packaging, licensing, and breaking changes.

Classify findings as **recommended**, **probe first**, **track only**, or
**not applicable**, with immutable sources where available, benefit, estimated
size/complexity, risks, and evidence limits. Report an explicit no-finding or
incomplete-audit outcome for each harness. Release-note silence is not a verified
absence. Do not upgrade matrix cells to implemented until Sesori implements and
verifies the behavior; record verified changes in upstream support separately.

## 4. Ask for guidance; write the plan

Before treating opportunities as approved work, present a compact decision list
and ask which to implement, probe, defer, or decline. Include simplifications,
parity improvements, and other material opportunities, not only new UI features.
Explain concrete benefits, approximate effort, risks, and recommended PR boundary.
Use the host's structured-question tool when available; group related decisions.
Do not interpret interest in an upstream release as approval for extra features,
considerable refactors, new authentication, compatibility-floor increases, or
publishing a separate adapter release. Record existing explicit approvals instead
of asking for the same decision again. If the user has not answered, retain
those items as decision-pending, not executable scope.

Use [sesori-plan-maker](../sesori-plan-maker/SKILL.md) to create/update a durable
plan under `.plan/active/<slug>/`. It must contain:

- one row per registered harness with current/candidate target, unchanged floor
  or exact-pin exception, upstream/adapter/protocol identities, distribution,
  update/already-current/blocked status, and evidence links;
- per-harness relevant findings, decisions, release dependencies, risks, and
  verification still needed, even when no target change is necessary;
- an explicit completeness check and any skill corrections made or still needed;
- dependency-ordered, independently reviewable PR steps: publish the plan first,
  then target refreshes and prerequisites; approved capability/simplification
  work normally gets dedicated PRs, separate from mechanical pins;
- affected regression documents, verification level/matrix and acceptance
  criteria, plus the plan maker's documentation and retirement steps;
- blockers and honest untested statuses. A source audit may produce a useful
  plan even when a required install or authenticated probe cannot yet run.

Do not pin production versions, publish adapters, or implement optional findings
merely to finish planning. An explicit implementation request authorizes its
stated scope; execute through [sesori-plan-worker](../sesori-plan-worker/SKILL.md)
after planning and applicable gates. Follow the repository-wide `PR Sizing And
Review Convergence` policy in `AGENTS.md`; execution-specific step sequencing
remains in the plan worker. Splitting never needs another permission request;
adding unapproved behavior does.
Respect the current workspace restrictions for separate-repo dependencies: record
an authorized handoff/blocker rather than creating a forbidden checkout.

## 5. Normal release checks for implementation

Record planned versus completed checks distinctly. A target refresh requires
official release evidence, integrity checks for **every managed asset**, isolated
current-host production installation/identity/protocol checks, and focused owning
package tests/analyzer. Use the harness reference for exceptions and extra gates.
Apply every named required gate in the approved plan, including detailed harness
prose; a shorter summary table does not silently replace it. Resolve contradictory
requirements with the owner before marking a pin Pass. A merge is not a waiver.

- Download and hash every managed asset as opaque bytes. Compare published
  digests and checksum lists where provided; distinguish metadata agreement from
  independently verified downloads. Cursor/Antigravity self-computed hashes are
  not upstream attestations. Never mix a new release URL with old digests or
  invent placeholders. Transfer digests from machine-readable hash records,
  not narrative reports; reconcile the final manifest against those records.
  Derive totals per harness, not a stale global count.
- Preserve formats, package-directory siblings, helpers, resources, raw-binary
  layouts, libc variants, and unsupported platforms. A packaging change is a
  compatibility finding, not permission to guess a new mapping.
- Before parsing/extracting/executing downloaded code, establish a disposable OS
  sandbox, VM/container, or restricted account with no sensitive mounts. Block
  outbound network for credential-free probes; allow loopback only where needed.
  Temporary HOME and environment filtering alone are not a security boundary.
- Use the production installer/extractor and candidate manifest/validator with
  disposable roots, not the descriptor's still-current pin or a generic tar
  extraction. Inspect the installer under
  `bridge/sesori_plugin_runtime/lib/src/provisioning/` and
  `bridge/sesori_bridge_foundation/lib/src/archive_extractor.dart`. Apply path/
  link rejection, preserve the full payload, and verify the installed digest
  sentinel. Direct-CLI candidates require no invented managed-install pipeline.
- Launch absolute candidate entrypoints from an empty project with isolated
  HOME/profile/config/cache roots and an explicit allowlisted environment. No
  ambient tokens, credential helpers, SSH agent, sessions, MCP configuration,
  prompts, or user files. Keep production profiles and approval policy unchanged.
- Bound process startup, reads and shutdown; correlate protocol responses by ID,
  distinguish server requests, and check exact identity plus required surfaces.
  Use `try/finally` and terminate the entire process group/Windows Job Object
  before deleting evidence or disposable files, on success or failure. A denied
  process-presence check is unknown, not proof of absence; preserve evidence
  and distinguish probe-cleanup failures from candidate protocol regressions.
- Authenticated feature checks need an explicitly authorized procedure, test
  credentials and network scope. Do not borrow the user's live session. Record
  required-but-unavailable checks as blocked; mocks or version output do not
  prove live behavior. Preserve useful source findings while pinning is blocked.
- For lifecycle gates without a real-auth requirement, a controlled loopback
  model fixture may drive the actual candidate. Never fabricate runtime events
  as native evidence. Separate exercised production seams from merely inspected
  code, and distinguish a replayed current prompt from persisted history. Record
  controller wait budgets honestly: `Future.timeout` does not cancel its source.
- Keep reports/commits free of secrets, prompts, transcripts, user-local paths,
  account identifiers and raw provider payloads. Record bounded outcomes and
  immutable public source links instead; preserve diagnostic detail in local
  logs under the repository's logging policy, not in public audit artifacts.

Only the current host requires live install/launch probes for a normal refresh;
other platforms are **untested**, not blockers or implicitly validated. Add
platform-specific checks only for a concrete change/regression. All managed
asset hashes remain required. Source-to-binary attestations and reproducible
builds are optional reporting evidence, never routine gates or reasons to ask
for an exception. A failed required check blocks that harness's bump, not the
remaining inventory or source audit.

For approved implementation, update target/digests and target-specific fixtures
in lockstep. Preserve historical protocol observations and minimum-version tests.
Prefer one tolerant plugin-local path over version branches; retain compatibility
only for real supported callers and meaningful damage. If a floor increase was
approved, remove the code/tests/docs made obsolete by that decision. Follow the
repository's dated compatibility-marker and public-production baseline rules.
Never leak backend concepts outside their plugin or hand-edit generated code.

Run directly relevant tests and analyze each changed owning package; extend to
shared packages only when affected. Reconcile capability/regression docs when
behavior or verified limitations change, not for target-only tombstones. Apply
architecture-review skills only for architecture-bearing production plans/changes,
not this skill, documentation, or a mechanical pin edit.

## 6. Improve this skill and deliver

Correct outdated release channels, paths, asset layouts, checks and assumptions
when current evidence disproves them. Missing harnesses **must** be added during
planning. Also save reusable discoveries that materially speed up or improve the
next run: adapter publication order, reliable discovery commands, probe pitfalls,
or newly verified seam constraints. Update this skill/reference in the same plan
or directly related PR; summarize why, with a source/date for version-sensitive
facts. No extra approval is needed for evidence-backed maintenance, but do not
use self-improvement to weaken approval, privacy, compatibility or safety gates.
Keep transient release values, hashes, logs and progress in the plan/report, not
an ever-growing skill diary. Remove obsolete advice rather than append conflicts.

For skill/docs-only work validate frontmatter, links, inventory coverage and diff
hygiene; do not run Dart/Flutter suites. Follow repository commit/push/PR rules,
real multiline bodies and complexity/series titles. Start `monitor-pr` immediately
after opening a PR; never auto-merge or invent polling when monitoring is absent.

Final report: plan/PR link, **every harness's** target/minimum or exact-pin status,
producer-release dependencies, recommended/approved/deferred findings, integrity
and probe evidence, tests, blockers, untested platforms, and skill improvements.
A completed plan or audit is not an implemented runtime update.
