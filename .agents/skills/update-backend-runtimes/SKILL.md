---
name: update-backend-runtimes
description: >-
  Plan and deliver a coordinated runtime-target refresh for every supported Sesori harness:
  OpenCode, Antigravity, Codex, GitHub Copilot, Cursor, Claude Code, Hermes Agent,
  Pi, Oh My Pi, DeepSeek, and Grok Build. Audit releases, managed assets, adapter
  release dependencies, capability gaps, and simplifications; ask before adopting
  extra features. Use for harness target updates, runtime pins, or release audits.
metadata:
  audience: maintainers
  workflow: github
---

# Update Backend Runtimes

Plan and deliver current stable targets for **every included harness**. Audit
the actual protocol seam Sesori uses and report worthwhile upstream changes;
ask before adding optional features, not before doing the requested update.
Updating this skill alone does not start a runtime audit.

## Update-first policy

- An implementation request authorizes bringing every included target up to
  date. Keeping old pins because testing is inconvenient or unavailable is not
  an acceptable completion outcome. Preserve separately approved scope exclusions
  and compatibility floors; updating a target does not authorize raising a floor.
- Missing credentials, configured fixtures, native runners, or incomplete
  verification are **final-plan follow-ups**, not routine pin blockers. Deliver
  the update, run useful available checks, then group unresolved tests, feature
  questions and user-assisted validation in the final plan stages. Do not ask
  repeatedly whether to proceed, hold a version, or obtain a fixture now.
- Distinguish update status from verification status. A target can be updated
  while a check is `Not run`, `Blocked` or `Fail`; never turn that into a false
  pass, conceal a failure, or declare the whole plan verified.
- Fix demonstrated compatibility problems as update work rather than allowing
  permanent divergence. Only an exceptional, concrete risk—such as credible
  data loss, a security regression, or a demonstrated unusable core flow—can
  justify a **temporary** hold. State the harm, evidence, smallest resolution,
  responsible follow-up and condition for lifting it. A missing test, uncertain
  fixture, or probe-controller failure alone is not that evidence.
- This policy changes delivery order, not security or truthfulness. Never invent
  release identities/digests, weaken runtime validators, reuse live credentials,
  broaden a sandbox to obtain a pass, or fabricate native evidence. Resolve
  actual artifact/producer problems; move unavailable testing to final follow-up.

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
Count actual `knownPlugins` entries, including named `.production()` factories;
counting only bare constructor calls misses registered harnesses. For assets,
count platform mappings, not every digest literal or checksum-file entry.
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
  If a newer stable release appears, reconcile its source delta and changed
  asset set. Keep earlier native evidence attributed to its actual version;
  a patch-version increment does not guarantee a small diff.
- Resolve old/new public source tags to immutable commits before auditing;
  re-check their identities before finalizing the plan and before implementation.
  Resolve moved tags or ambiguous identities from official evidence; never guess
  a version/digest or turn uncertainty into a permanent old pin. Escalate an
  exceptional unresolved supply-chain problem under the temporary-hold policy.
  For closed source, record official distribution/build evidence and source limits.
- Audit owned adapters as well as their underlying harness. DeepSeek may require
  changes and a release in `sesori-ai/sesori-deepseek-acp` **before** this repo can
  consume the new harness. Put producer changes, conformance, publication, asset
  verification, and consumer pinning in the same dependency-ordered plan.

Keep independent `minPathVersion` / `minVersion` backing values unchanged unless
raising them is separately approved. Targets identify the selected stable
release; verification is recorded separately. They are not permission to reject
otherwise-compatible PATH installs. Antigravity currently
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
absence. Mark a matrix cell implemented only when Sesori implements it, with
explicit verification limits. Record verified changes in upstream support
separately from Sesori implementation.

## 4. Ask for guidance; write the plan

Ask one compact, grouped decision list only for opportunities beyond the
requested update: optional features, considerable refactors, floor changes or
separate producer-release authority. Explain benefit, approximate size and risk.
Reuse existing explicit approvals; do not repeatedly ask whether to update an
included harness or keep its old version. An unavailable authenticated test does
not require an immediate credentials questionnaire: record its exact procedure
and required help in the final follow-up batch, then continue implementation.
Do not interpret update authorization as permission to access live accounts or
publish a separate adapter. Keep unapproved optional work decision-pending.

Use [sesori-plan-maker](../sesori-plan-maker/SKILL.md) to create/update a durable
plan under `.plan/active/<slug>/`. It must contain:

- one row per registered harness with current/candidate target, unchanged floor
  or exact-pin exception, upstream/adapter/protocol identities, distribution,
  updated/pending-update/exceptional-temporary-hold status, separate verification
  status, and evidence links;
- per-harness relevant findings, decisions, release dependencies, risks, and
  verification still needed, even when no target change is necessary;
- an explicit completeness check and any skill corrections made or still needed;
- dependency-ordered, independently reviewable PR steps: publish the plan first,
  then target refreshes and prerequisites; approved capability/simplification
  work normally gets dedicated PRs, separate from mechanical pins;
- affected regression documents, verification level/matrix and acceptance
  criteria, plus final grouped follow-ups, user-assisted checks, documentation
  and retirement steps;
- honest untested/failed checks without treating them as default reasons to keep
  old versions. Retain a temporary-hold entry only for an exceptional concrete
  problem with an explicit resolution path.

Do not pin production versions, publish adapters, or implement optional findings
merely to finish planning. An explicit implementation request authorizes its
stated scope; execute through [sesori-plan-worker](../sesori-plan-worker/SKILL.md)
after planning and applicable gates. Follow the repository-wide `PR Sizing And
Review Convergence` policy in `AGENTS.md`; execution-specific step sequencing
remains in the plan worker. Splitting never needs another permission request;
adding unapproved behavior does.
Respect the current workspace restrictions for separate-repo dependencies: record
an authorized handoff/blocker rather than creating a forbidden checkout.

## 5. Implement updates and collect proportional evidence

Keep official release evidence and real digests for **every selected managed
asset**. Update targets/assets and affected fixtures together; run focused owning
package tests/analyzer and useful safely available native checks. Reuse accepted
results whose inputs have not changed. Do not delay all updates until every
provider, platform or lifecycle scenario can run.

Retain named checks from the approved plan, including detailed harness prose,
but place unavailable or inconclusive checks in the final follow-up stage under
the update-first policy. Record what failed, its actual impact, the smallest next
check/fix and any help needed. A merged target is not evidence that a deferred
check passed. Respect an owner's explicit change to verification timing rather
than re-asking the same decision or enforcing superseded pin-blocking language.

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
- Before parsing/extracting/executing downloaded code, inspect the actual
  launcher, OS sandbox, environment and trusted outer controller. Use a disposable
  boundary with no sensitive mounts, read-only runtime/source inputs and writes
  limited to owned state/project/temp roots. Deny external network for
  credential-free probes; allow only the owned loopback endpoint when needed,
  not arbitrary localhost services. Fresh HOME alone is not a security boundary.
  Diagnose a denied path precisely; required ancestor metadata does not justify
  broad filesystem, execution, write or network access.
- Use the production installer/extractor and candidate manifest/validator with
  disposable roots, not the descriptor's still-current pin or a generic tar
  extraction. Inspect the installer under
  `bridge/sesori_plugin_runtime/lib/src/provisioning/` and
  `bridge/sesori_bridge_foundation/lib/src/archive_extractor.dart`. Apply path/
  link rejection, preserve the full payload, and verify the installed digest
  sentinel. Direct-CLI candidates require no invented managed-install pipeline.
- Launch absolute candidate entrypoints through the real CLI/production seam,
  not direct internal-module dispatch that bypasses startup. Use an empty
  project, isolated profile/config/cache roots and an explicit allowlist; disable
  environment inheritance at native spawn. Exporting selected variables or
  extending inherited `PYTHONPATH` is not filtering. These are probe controls,
  not a request to change production credential inheritance. Use a probe-owned
  injectable process factory/host adapter to filter both passed environment maps
  and disable actual spawn inheritance; inspect the final ACP/OS boundary and
  disclose the test-only override. If the seam cannot do this safely, record the
  check as unavailable, not compliant. No ambient tokens, credential helpers,
  SSH agent, sessions, MCP config or user files. Preserve production launch flags
  and approval policy; use the existing narrow production API when sufficient.
- Start the trusted outer bound before fixture setup/compilation, not only the
  final probe. Bound startup, reads and shutdown; correlate responses by ID and
  distinguish server requests. Own process handles/groups or Windows Job Objects;
  clean them on success and failure, including setup failure. Verify current
  identity/ownership before signaling; never signal a historical PID blindly.
  Denied presence checks mean unknown, and absence of a reparented process is not
  `wait(2)` reaping. Record actual exits and final owned-resource state. A broken
  probe/controller is not automatically a runtime regression or a reason to hold
  an otherwise updatable target.
- Authenticated checks still need an authorized procedure, isolated test
  credentials and network scope. Never borrow a live session. Missing access
  goes into final user-assisted verification, not a hold-or-update questionnaire.
  Version output, mocks and source inspection do not prove authenticated behavior.
- For lifecycle gates without a real-auth requirement, a controlled loopback
  model fixture may drive the actual candidate. Never fabricate runtime events
  as native evidence. Separate exercised production seams from merely inspected
  code, and distinguish a replayed current prompt from persisted history. Record
  controller wait budgets honestly: `Future.timeout` does not cancel its source.
- Preserve immutable per-attempt results, profile/database state and logs before
  resets or retries. Tool-owned `REPORT.md` output may be overwritten; keep a
  separate substantive attempt report. Deleted databases or replaced fixture
  logs cannot be reconstructed and called original evidence. Recovery resumes
  the retained agent/protocol; it is not permission to switch execution modes or
  repeat accepted work. Cleanup-only recovery proves cleanup, not lost tests.
- Check each semantic outcome, not only a driver's `success: true` or zero exit.
  A completed script can contain failed load/replay checks. Use actual production
  validators rather than candidate-specific predicates; keep historical native
  captures separate from explicitly synthetic current-version fixtures.
- Keep reports/commits free of secrets, prompts, transcripts, user-local paths,
  account identifiers and raw provider payloads. Record bounded outcomes and
  immutable public source links instead; preserve useful diagnostics locally.

The current host is the normal native-check scope; other platforms remain
**untested**, not implicitly validated. New platform coverage still needs its
native check, but an unavailable runner belongs in final follow-up. Never label
another architecture's run as that proof. Keep all selected managed hashes real.
Source-to-binary attestations and reproducible builds are optional reporting
facts, not extra routine gates or reasons to ask for an exception.

Preserve historical protocol observations and minimum-version tests. Fix
meaningful adapter incompatibilities locally rather than accumulating version
branches. Retain compatibility only for real supported callers and meaningful
damage. If a floor increase was approved, remove the obsolete code/tests/docs;
follow dated compatibility-marker and public-production baseline rules. Never
leak backend concepts outside their plugin or hand-edit generated code.

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
Honor explicit owner waivers of unavailable automated review after checking
current-head CI and new feedback; do not keep waiting for the waived reviewer.
GitHub mutations can partially succeed despite response errors: read back the
exact body/thread/merge state before retrying, and retry only missing operations.

Final report: plan/PR link, **every included harness's updated target** and
unchanged minimum/exact policy, real asset integrity, executed checks, failed or
untested boundaries, and one grouped follow-up list. For each unresolved check,
name the minimal reproduction, expected result and required user help. Do not
present old pins as a successful refresh; justify any exceptional temporary hold
with its resolution path. Do not retire unresolved coverage without recording the
owner's acceptance. An audit, update or merge is not proof of unexecuted tests.
