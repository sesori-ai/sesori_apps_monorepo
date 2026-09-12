# All Harness Runtime Refresh — Tracker

## Current state

- **Series:** nine top-level steps; Steps 1–2 merged, Step 3 verification active.
- **Branch/base:** `all-harness-runtime-refresh-step-3` /
  `ba3264eab93a1775d4e4c24e7672cab8bebe2d67`.
- **Delivered scope:** PR #1455 merged four target updates, 18 managed digests,
  and focused target fixtures. Its additional Pi/Claude lifecycle evidence was
  accepted after merge; no required gate was waived. No new capabilities,
  generated files, wire/database changes, or product release were introduced.
- **Approved scope:** mechanical target refreshes, OMP Windows ARM64 mapping,
  and OMP-backed shared ACP multi-select questions. Floors remain unchanged;
  DeepSeek and unrelated upstream changes remain outside this series.
- **Next:** accept independent Antigravity/Cursor release/install/protocol
  evidence and apply only passing targets. Codex teardown proof and required
  configured/authenticated fixtures remain blocking only for their respective
  pins. See [Step 2 verification](STEP-2-VERIFICATION.md) and its
  [lifecycle follow-up](STEP-2-LIFECYCLE-VERIFICATION.md).

## Delivery ledger

| Done | Step | Exact PR title | Status |
|---|---|---|---|
| [x] | 1/9 | `🌱 [all-harness-runtime-refresh] docs: publish runtime refresh plan [step 1/9]` | PR #1453 merged as a644652e0c; no production changes |
| [x] | 2/9 | `🌿 [all-harness-runtime-refresh] runtime: refresh mechanical targets [step 2/9]` | PR #1455 merged as ba3264eab9; four targets verified including post-merge Pi/Claude follow-up; Codex/OMP remain blocked and unchanged |
| [ ] | 3/9 | `⚙️ [all-harness-runtime-refresh] runtime: validate Antigravity and Cursor exact builds [step 3/9]` | Independent exact-pair/build/hash/install probes running; no target applied yet |
| [ ] | 4/9 | `⚙️ [all-harness-runtime-refresh] runtime(hermes): resolve cleanup and refresh target [step 4/9]` | Blocked on empty-session cleanup seam |
| [ ] | 5/9 | `🌿 [all-harness-runtime-refresh] runtime(grok): refresh target [step 5/9]` | Channel/ACP probe pending; namespace/provenance policy corrected |
| [ ] | 6/9 | `⚙️ [all-harness-runtime-refresh] runtime(omp): add Windows arm64 asset [step 6/9]` | Approved eighth asset; hash/mapping/native Windows ARM64 install-version-ACP smoke/documentation gates pending |
| [ ] | 7/9 | `⚙️ [all-harness-runtime-refresh] acp: support OMP multi-select questions [step 7/9]` | Separate option/custom questions; widget/live OMP roundtrip gates plus same-PR question regression/capability docs pending |
| [ ] | 8/9 | `🌱 [all-harness-runtime-refresh] docs: reconcile runtime regression coverage [step 8/9]` | Penultimate; verified behavior only |
| [ ] | 9/9 | `🌿 [all-harness-runtime-refresh] verify: record matrix and retire plan [step 9/9]` | Final L2 target-only matrix; cannot retire with required gaps |

## Harness status matrix

| Harness | Branch target | Floor/exact policy | Candidate | Status |
|---|---:|---|---:|---|
| OpenCode | `1.18.30` | `1.14.0` unchanged | `1.18.30` | Pass: six hashes, install, REST/SSE, read-only catalog, focused tests/analyzer |
| Antigravity | package `1.0.0`; server `agy_acp_server_20260818_01_RC01` | Exact package/server/ACP 1; no semantic floor | package `1.1.1`; server pending | Probe-first |
| Codex | `0.153.4` | `0.139.0` unchanged | `0.154.0` | Partial / blocked: assets/install/both transports pass; scratch sandbox group teardown fails after one focused retry |
| GitHub Copilot | `1.0.83` | `1.0.78` unchanged | `1.0.83` | Pass: six hashes, install, ACP initialize, focused tests/analyzer |
| Cursor | `2026.08.11-e8db854` | date floor `2026.07.16` unchanged | `2026.09.10-fd3934a` | Probe-first; four content hashes and configured load/replay fixture pending; missing fixture blocks pin |
| Claude Code | `2.1.269` | `2.1.221` unchanged | `2.1.269` | Pass: CLI/SDK launch, native controlled-provider approval/replay/interrupt/reuse/cleanup plus production parsing/history mapping; tests/analyzer |
| Hermes Agent | `0.20.4` | `0.20.0` unchanged | `0.21.2` | Blocked; cleanup and configured new/load fixture prerequisites |
| Pi | `0.85.1` | `0.84.1` unchanged | `0.85.1` | Pass: six hashes/install/RPC, native production-plugin settlement/manual-compaction abort/ordering/reuse/cleanup; tests/analyzer |
| Oh My Pi | `17.3.8` | `17.2.13` unchanged | `18.1.18` | Blocked: seven hashes/install/initialize pass; authorized authenticate/list/new/load/cleanup fixture absent |
| Grok Build | `1.0.5` | `1.0.5` unchanged | stable channel `1.0.30` | Blocked; reference-required authenticated new/prompt/replay/model-selection/close probes pending |
| DeepSeek | Upstream main | Outside this series | None | Explicitly excluded; unrelated upstream changes are neither audited nor modified here |

## Approved and deferred decisions

- **Approved:** preserve every floor and Antigravity exact-pair policy;
  refresh named stable candidates after gates; add OMP Windows ARM64; support
  ACP array `items.anyOf` forms for OMP through shared mapping and existing UI.
- **Still prerequisite:** Hermes narrow not-found cleanup treatment must be
  confirmed by candidate source/probe before pinning. Required configured gates
  are also pin-blocking: Cursor load/replay; OMP authenticate/list/new/load and
  persisted cleanup; Hermes new/load; and Grok authenticated
  new/prompt/replay/model-selection/close. Missing fixtures block their
  respective pins; optional broad provider/model/catalog/child exploration is
  Blocked but non-gating, with no implied waiver.
- **Resolved policy:** Cursor official installer content may be self-hashed;
  no publisher checksum, signature, immutable release, or source-binary
  attestation gate is required. Grok `x.ai/...` source spelling normalizes to
  `_x.ai/...` wire names; no namespace blocker remains. Pi npm comparison uses
  `@earendil-works/pi-coding-agent`.
- **Analytics:** reuse existing authoritative question-answer instrumentation.
  Add no new event; add zero new persistent or in-memory coordination parts; no generated churn is expected.
- **Estimates:** approximately 200-450 authored lines for multi-select and
  40-100 for OMP Windows ARM64 mapping; refine against local implementation
  without widening scope.
- **Declined/deferred:** upstream optional models/providers, auth/login beyond
  named required probes, sub-agents, plan UX, shell-command claims,
  cancellation redesign, floor changes, and broad cleanup/refactors.

## Feature gates

These gates are tracked independently from the target-only L2 matrix.

| Feature/gate | Minimum sufficient scope | Required evidence | Status |
|---|---|---|---|
| Cursor configured load/replay | Pin-blocking configured fixture | Authorized isolated configured load/replay; missing fixture blocks Cursor pin | Blocked |
| OMP configured lifecycle | Pin-blocking configured fixture | `authenticate(agent)`, list/new/load, persisted cleanup; missing fixture blocks OMP pin | Blocked |
| Hermes configured lifecycle | Pin-blocking configured fixture | Configured new/load; missing fixture blocks Hermes pin | Blocked |
| Grok authenticated seam | Pin-blocking authenticated fixture | New/prompt/replay/model-selection/close; missing fixture blocks Grok pin | Blocked |
| OMP Windows ARM64 | L2 Routine platform-specific gate before platform claim/retirement | Native Windows ARM64 install/version/ACP smoke; missing Windows runner blocks feature, never implicit acceptance | Blocked |
| OMP ACP multi-select | L2 Routine scoped to OMP ACP form questions, independent of target-only L2 | Existing-widget automation plus authoritative live OMP `askDialog`/ACP array roundtrip on at least one supported client: two choices+custom, selected values, required omission/cancel, single-choice unchanged | Blocked |

## Verification log

- Registry reconciled: 11 total, ten included, DeepSeek excluded.
- Architecture plan review on 2026-09-12 rejected four ownership gaps. Applied
  the ownership clarifications for plugin/shared reply flow, immutable field
  encoding, OMP live-versus-scratch form policy, and plugin-local Windows assets.
  PR review simplified grouping to one property/question so option/custom
  provenance stays unambiguous without wire changes; feature docs now land in
  their feature PRs, and the OMP asset reference uses durable discovery guidance.
  No scope expansion or new coordination state was needed; no re-review is claimed.
- Step 1 recovered the source audit and validated documentation only. Its
  metadata snapshot remains in `AUDIT.md`; it is not runtime execution evidence.
- Step 2 independently verified 18 adopted managed archives and current-host
  installer/identity/protocol gates for OpenCode/Copilot/Pi, plus Claude's
  direct-CLI/SDK gate. Codex and OMP also passed their asset/install gates but
  remain unpinned because required teardown/configured-lifecycle evidence is
  incomplete. The Codex cleanup-only retry did not waive its failure.
- A Copilot macOS ARM64 report transcription error was reconciled against raw
  metadata and a targeted byte rehash before applying its verified digest.
- Post-pin focused tests: OpenCode 160, Copilot 17, Pi 162, Claude 10; total 349
  passed. All four owning analyzers and formatting for nine Dart files passed
  with pinned Dart 3.13.3. Older compatible PATH fixtures and historical protocol
  observations remain unchanged.
- Review caught missing named Pi/Claude lifecycle evidence. The owner chose to
  complete it, not relax the plan. PR #1455 merged with those threads still
  open; the subsequent accepted checks verify Pi settlement/compaction abort
  through the production plugin, and Claude native approval/replay/interrupt
  with production parsing/history mapping. Controlled loopback providers only;
  real-provider behavior and deadline-expiry fault injection are not claimed.
- No real credentials or live profiles were used. Required configured fixtures,
  multi-select, and Windows ARM64 native gates remain blocked; other non-macOS
  native paths remain untested. Full evidence and limits are in
  [STEP-2-VERIFICATION.md](STEP-2-VERIFICATION.md).

## Completion rule

Mark each harness only after official release/source, every managed-asset hash,
current-host macOS arm64 install, exact identity/protocol, pin-blocking
configured/authenticated probes, and owning focused tests/analyzer pass. Steps
6–7 include their feature-owned regression/capability docs; Step 8 reconciles
broader runtime documents for verified behavior. Step 9
records `Pass`, `Partial`, `Fail`, `Blocked`, or `Not run` with explicit
platform/account boundaries. The independent multi-select matrix and OMP
Windows ARM64 native gate must pass before their claims are published, or an
explicit accepted exception must be recorded; a missing fixture or Windows
runner is not implicit acceptance. Move this directory to
`.plan/completed/all-harness-runtime-refresh/` only when required gaps pass or
an explicit exception is recorded in `PLAN.md`; DeepSeek remains untouched.
