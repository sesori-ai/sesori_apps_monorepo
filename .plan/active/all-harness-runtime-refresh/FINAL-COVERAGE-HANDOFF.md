# Runtime Refresh — Coverage And Final Handoff

## Delivery and decision status

As of 2026-09-13, all ten included targets, the narrow Hermes scratch-cleanup
fix, OMP Windows ARM64 mapping, and shared ACP multi-select implementation are
merged. Step 7 merged through [PR #1468](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1468)
as `fa0111b153f48b1bf4739f3fe95e2e4b1521f8cc` at `13:11:04Z`; terminal CI passed
19/19, current-head Cubic/Codex feedback settled, and the sole documentation
finding was corrected and resolved.

**Delivery is complete; verification and retirement are not.** Missing fixtures,
credentials and runners did not hold targets. No exceptional temporary version
hold is established. The owner has not yet accepted the remaining coverage
limits. This document consolidates existing evidence and the one final help
batch; it does not authorize execution or describe new test passes.

The registry contains 11 harnesses: ten included and DeepSeek explicitly
excluded. Direct-CLI targets are recommendation metadata, not an upgrade of the
user's installed CLI. Compatible PATH and explicit-binary authority remain
unchanged. Antigravity retains its exact-pair policy rather than a separate
semantic minimum.

## Target and evidence matrix

`Pass` below means the named **scoped target-update gates**, not comprehensive
provider, client or platform verification. `Partial` retains an actual missing
or failed check. Native evidence is macOS ARM64 unless stated otherwise.

| Harness | Adopted target | Unchanged floor / exact policy | Managed assets | Verification result and boundary |
|---|---|---|---:|---|
| OpenCode | `1.18.30` | `1.14.0` | 6 | **Pass, scoped:** install, version, health/SSE, typed reads, read-only catalog and shutdown. Database/WAL unchanged; transient SQLite SHM bookkeeping changed. No provider/account turn. [Step 2](STEP-2-VERIFICATION.md) |
| Antigravity | package `1.1.1`; server `agy_acp_server_1.1.1` | Exact package/server/ACP 1 | 5 | **Pass, scoped:** archive integrity/layout and actual production validator/initialize/teardown. No current-target OAuth/session/model/delegation run; older authenticated evidence is not relabelled. [Step 3](STEP-3-VERIFICATION.md) |
| Codex | `0.154.0` | `0.139.0` | 6 | **Partial:** install/helpers and both stdio/WebSocket initialize/list paths passed; automatic probe teardown failed. Historical resources were cleaned; no retry authorized. No account prompt/history/approval proof. [Step 5](STEP-5-VERIFICATION.md) |
| GitHub Copilot | `1.0.83` | `1.0.78` | 6 | **Pass, scoped:** install, branded version, exact ACP launch/initialize and advertised login method. No login, entitlement or provider turn. [Step 2](STEP-2-VERIFICATION.md) |
| Cursor | `2026.09.10-fd3934a` | date `2026.07.16` | 4 | **Partial:** current-target native package/initialize/cleanup passed; configured load/replay/model/mode is not run. [Step 3](STEP-3-VERIFICATION.md), [Step 5](STEP-5-VERIFICATION.md) |
| Claude Code | `2.1.269` | `2.1.221` | 0 | **Pass, scoped:** controlled-provider CLI permission/replay/interrupt/reuse plus production event/transcript mapping. Not full session-service orchestration or real authentication/provider coverage. [Lifecycle follow-up](STEP-2-LIFECYCLE-VERIFICATION.md) |
| Hermes Agent | `0.21.2` | `0.20.0` | 0 | **Partial:** narrow cleanup and descriptor tests pass. Fresh load failed under an unaccepted procedure; native load/replay/persisted deletion is not qualified. Original deleted state cannot be recovered as evidence. [Step 4](STEP-4-VERIFICATION.md), [Step 5](STEP-5-VERIFICATION.md) |
| Pi | `0.85.1` | `0.84.1` | 6 | **Pass, scoped:** install/RPC and required production-plugin settlement, manual-compaction abort, ordering and reuse. No real-provider/account claim or injected deadline-failure proof. [Lifecycle follow-up](STEP-2-LIFECYCLE-VERIFICATION.md) |
| OMP | `18.1.19` | `17.2.13` | 8 | **Partial:** current asset hashes and mapping/plugin/widget tests pass. Native observations were `18.1.18`; current-target native/configured lifecycle and live array roundtrip remain not run. [Step 5](STEP-5-VERIFICATION.md), [Step 6](STEP-6-VERIFICATION.md), [Step 7](STEP-7-VERIFICATION.md) |
| Grok Build | `1.0.30` | `1.0.5` | 0 | **Partial:** official stable-channel and descriptor-unit evidence only. Native identity/exact launch/ACP and authenticated lifecycle are not run. [Step 5](STEP-5-VERIFICATION.md) |
| DeepSeek | Not assessed | Excluded | — | No target, producer, feature or verification assessment in this series; no obligation to restore its historical snapshot. |

The **41 mapped assets** belong to seven included managed harnesses. Their real
hashes were independently verified in Steps 2–6; current runtime authorities and
registry are unchanged since the Step 6 merge. This reconciliation reuses those
records without downloading or rehashing bytes. Antigravity's two separately
hashed extracted siblings and publisher checksum files are not extra platform
mappings. Local hashing is not a publisher signature or source-to-binary
attestation. The three direct-CLI harnesses have no managed assets.

Source audits were focused, not exhaustive. In particular, the OMP
18.1.18→18.1.19 comparison covered 172 commits and 235 changed files, with no
ACP/elicitation/ask-dialog-named path changes; broader behavior remains only
partially audited. Grok's captured source identity is not a verified association
to the stable-channel binary. Neither limitation is a newly invented attestation
gate or a reason to restore an old target.

## Required verification scope

| Workstream / check | Minimum scope | Current result |
|---|---|---|
| Included runtime updates | L2 Routine target-only, named current-host gates | **Partial overall:** five scoped passes and five partial rows above; not blanket all-harness verification |
| OMP Windows ARM64 feature | L2 native ARM64 install/version/ACP/teardown | **Not run:** implementation and ten manifest/asset-service cases pass; other hosts and ordinary Windows CI do not prove native ARM64 |
| OMP multi-select feature | L2 scoped form path, widget automation plus live OMP/client roundtrip | **Partial:** 75 mapper/plugin/bridge/widget cases and four analyzers pass; live roundtrip not run |
| Codex probe automatic teardown | Both transport attempts finish with owned-resource cleanup | **Fail, recorded:** controller attempts failed; subsequent authorized cleanup does not repair that gate |
| Hermes attempted fresh load | Fresh-process model state and replay | **Fail, recorded under an unaccepted procedure:** not a verified production regression or an accepted native pass |
| New Codex/Hermes execution | Procedure review and explicit authorization | **Blocked:** current stop boundaries remain in force |

Other non-macOS native paths remain untested unless their individual report says
otherwise. Full client L3, broad provider/authentication, unrelated child/tool/
model exploration, and unexercised deadline fault paths are not claimed. A
passing install, source inspection, helper exit, synthetic frame, or widget test
cannot substitute for a named native/configured result.

### Focused automation retained by step

| Step | Successful cases | Scope |
|---|---:|---|
| 2 | 349 | OpenCode/Copilot/Pi/Claude owning suites; four analyzers |
| 3 | 68 | Antigravity owning suites; analyzer; affected fixture rerun already included |
| 4 | 11 | Hermes cleanup API and catalog repository; analyzer |
| 5 | 121 | Codex/Cursor/OMP/Hermes/Grok target suites; five analyzers |
| 6 | 10 | OMP manifest and asset repository/service; analyzer |
| 7 | 75 | ACP mapper/registry, OMP plugin, bridge question repository and shared widget; four analyzers |

These are revision-bound step counts, **not an additive total of unique tests**;
suites overlap across steps. Step 7's counts are 23/15/16/21, mapped from JSON
suite/test identities, with no counted skips/failures and all `done.success`
values true. Its architecture implementation review approved the production
change. Documentation reconciliation does not rerun unchanged passing suites or
native probes.

## One grouped remaining-check and help batch

The following are checks to complete or explicitly accept as limited, not
requests to hold already-delivered updates. Every procedure inherits the
[verification contract](PLAN.md#verification-contract): read-only inputs, owned
writable roots, no native environment inheritance or ambient secrets, precisely
scoped networking, and trusted deadline/cleanup ownership starting before setup
and compilation. Before execution, agree on the exact procedure and fixture.
Where source/fixture support is uncertain, verify the actual trigger first; do
not fabricate native frames to satisfy a checklist.

### 1. Codex controller failure — review before any retry

- **Known result / harm:** automatic cleanup did not reliably stop the owned
  WebSocket process group. A probe could leave background processes/listeners;
  this is a controller problem, not established evidence of a production Codex
  regression. Historical groups were cleaned.
- **Smallest next work:** review the retained controller and postmortems, then
  propose bounded ownership/cleanup for the real stdio and WebSocket launches.
  Cover setup and failure paths, not just normal completion. No new retry is
  currently authorized, and historical PIDs are never signaling targets.
- **Evidence to close:** an explicitly permitted attempt records actual exits
  and absence of its currently owned process group/listener on success and
  failure, without broadening the candidate's access.
- **Needed help:** procedure/supervisor review followed by explicit owner retry
  authorization. No account credential is needed for initialize/list checks.

### 2. Cursor configured session and options

- **Gap / harm:** initialize works, but restoring a configured session and changing
  model/mode have not been exercised; regressions there could break continuation
  or option selection.
- **Smallest check:** through the actual adapter, create a synthetic persisted
  session, restart/load it, verify replay, and select advertised model/mode
  values. Use the normal production endpoint/launch, not a probe-only endpoint
  substitution; clean up the owned fixture afterward.
- **Evidence to close:** correlated native load/replay and option results,
  correct session ownership, and bounded cleanup.
- **Needed help:** a separately authorized disposable Cursor login/configuration
  or scoped test credential, or owner-assisted execution of the agreed procedure.
  Do not borrow the normal Cursor profile.

### 3. Hermes faithful load and persisted deletion

- **Known result / harm:** two attempts failed fresh load. Their launcher,
  inherited inputs, sandbox, deadline coverage and reset/lost evidence were not
  accepted. A helper's `success: true` did not mean its load/replay gates passed.
  If reproduced faithfully, a restore issue could prevent continuation; no
  regression versus the old release is established.
- **Smallest next work:** review a corrected procedure before any fixture or
  candidate execution. Use real `hermes acp` CLI dispatch and isolated owned
  state; persist a synthetic turn, settle, load/replay it in a fresh process, then
  delete that named persisted session through the production API. Investigate
  provider/base-URL restoration only if the faithful attempt reproduces it.
- **Evidence to close:** successful fresh-load model state/replay and actual
  persisted-session deletion, with immutable per-attempt DB/log records and
  bounded cleanup. Deleting the whole profile is not that evidence.
- **Needed help:** procedure/supervisor review and explicit authorization to
  resume this stopped work. A suitable dummy-credential loopback provider may
  suffice; real-provider credentials are not inherently required. Original
  deleted DB/logs cannot be reconstructed as original evidence.

### 4. OMP current-target lifecycle

- **Gap / harm:** `18.1.19` bytes are verified but current native lifecycle is
  untested; `18.1.18` observations cannot qualify install, replay or cleanup for
  the adopted target.
- **Smallest check:** finish the relevant source delta, then use production
  installation/validation and an isolated configured native `18.1.19` fixture
  for `authenticate(agent)`, new/list, fresh load/replay and persisted cleanup.
  Preserve exact launch and approval policy.
- **Evidence to close:** exact native identity, correlated production-seam
  outcomes and final owned-resource state. Source-only conclusions are separate.
- **Needed help:** an approved disposable fixture/procedure. A supported
  controlled loopback model may avoid real credentials. Reuse the same qualified
  fixture for the multi-select check below where practical.

### 5. Grok native and authenticated lifecycle

- **Gap / harm:** only stable-channel metadata and unit tests qualify `1.0.30`.
  Native launch, authentication, replay, model selection and close could still
  fail; no candidate was downloaded or executed by this refresh.
- **Smallest check:** verify branded `grok <version> (<build>)`, exact
  `grok --no-auto-update agent --no-leader stdio`, ACP 1 and actual capability
  declarations; then bounded authenticated new/prompt/replay/model-selection/
  close. Never add `--always-approve` or `--yolo`, or accept ACK/idle as replay.
- **Evidence to close:** correlated native outcomes at the official agreed
  endpoint, synthetic content, bounded time/requests/spend and owned cleanup.
- **Needed help:** testing is authorized in principle, but a separate test
  credential, secure out-of-band provisioning, precise endpoint scope, budget
  and final procedure still need agreement. No secrets in chat, PRs or logs;
  never borrow cached login/session credentials. Dummy fixtures do not qualify
  these real-authenticated gates.

### 6. Native Windows ARM64 installation

- **Gap / harm:** the correct mapping is implemented, but package usability,
  native version/ACP and teardown are not proven on the new architecture.
- **Smallest check:** on real Windows ARM64, use a native ARM64 bridge/toolchain
  and disposable state to select/install `omp-windows-arm64.exe`, verify its
  pinned digest and `omp.exe` placement, confirm `omp/18.1.19`, initialize ACP,
  and settle its owned process.
- **Evidence to close:** native architecture/identity, production install and
  protocol results, and bounded cleanup. macOS, x64 emulation and simulated
  platform-selection tests do not qualify.
- **Needed help:** a native ARM64 runner/VM or owner-assisted execution, with a
  reviewed isolated procedure and Windows process ownership/cleanup.

### 7. Live OMP multi-select on a supported client

- **Gap / harm:** constituent mapper/reply/widget paths pass, but no actual
  `askDialog`→ACP→client→native-answer roundtrip has run. A full-path mismatch
  could lose choices, confuse custom text or leave a turn awaiting input.
- **Smallest check:** select two native options, supply separate custom text
  identical to an option, and verify array/string values under their original
  keys. Cover optional omission, required omission/rejection, cancellation and
  unchanged single choice using supported native triggers.
- **Evidence to close:** an authoritative native/client roundtrip and its
  cleanup, not injected/replayed ACP frames or widget automation relabelled live.
  Report any native fixture limitation rather than manufacturing a schema.
- **Needed help:** at least one supported client attached to disposable bridge
  state and the authorized OMP fixture; owner-assisted interaction is acceptable.
  This can share preparation with item 4.

## Remaining policy and optional-feature decision

The review-raised **mixed-build managed-cache policy** is separate from the
completed target changes. Existing selection is pinned-first, and installation
cleanup can reclaim non-pinned versions. An older bridge starting after a newer
one populated the same state needs a bounded reproduction: inspect which
version it selects, whether it schedules an install, and which directories are
retained. If a newer cached runtime is reclaimed or selection rolls backward,
that may affect mixed-build reuse; the exact impact is not yet reproduced.

The inventory/selection/installer/cleaner were unchanged by this refresh. There
is no claim that this concern is fixed or harmless. The next decision is whether
to track a dedicated investigation or explicitly expand scope to that bounded
reproduction. Any retention/selection fix needs a separately agreed rollback
policy and focused tests; do not silently change all managed harnesses, including
excluded scope, or add broad coordination machinery here.

Other upstream models/providers, login/auth changes, sub-agent or plan UX,
shell-command claims, floor changes and broad refactors remain unapproved or out
of scope. The focused audit found no safe code-removal opportunity. This is not
an exhaustive absence claim, and no additional optional feature is being adopted
by this handoff.

## Step 8 reconciliation verification

Seven Markdown documents were checked for scope, privacy and relative links;
50 relative links/anchors and all nine exact PR titles reconciled. All ten
adopted target/floor rows matched the unchanged runtime authorities; registry
and managed mappings reconciled to 11/ten/41. Skill frontmatter parsed as valid
YAML using the system Ruby parser after Python's optional PyYAML was unavailable;
no dependency was installed. Production, test and generated files are unchanged.
Only documentation checks ran locally, not Dart/Flutter or native candidates.

## Step 9 acceptance and retirement

Present this batch once and ask the owner which named checks to complete and
which remaining limits to accept. Possible dispositions are selected further
QA, explicit acceptance of documented limits, or keeping the plan active.
Selecting future QA does not itself approve an unreviewed procedure, provision
credentials, or override the Codex/Hermes stop boundaries. The PR #1460 review
waiver was limited to that PR; it was not runtime-coverage acceptance.

For each selected check, record its actual `Pass`, `Partial`, `Fail`, `Blocked`
or `Not run` result and evidence. Any genuinely reproduced in-scope issue gets
the smallest justified correction; a broader change requires a separate scope
decision. Preserve rejected/lost-evidence history. Before retirement, record the
owner's explicit acceptance of each remaining limit and disposition of the cache
policy question. Until then keep `.plan/active/all-harness-runtime-refresh/`
active. No update is rolled back merely because a final check is unavailable.
