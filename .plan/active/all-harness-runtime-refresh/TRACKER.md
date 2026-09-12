# All Harness Runtime Refresh — Tracker

## Current state

- **Series:** nine top-level steps; plan-only at Step 1/9.
- **Branch/base:** `update-target-runtime-all-harnesses` /
  `8879ea1a62cc52104509c4483fe611c7eb0287bf`.
- **Publication scope:** documentation/reference revisions only. No production
  pin, installation, credential, or product-release change; no runtime testing.
- **Approved scope:** mechanical target refreshes, OMP Windows ARM64 mapping,
  and OMP-backed shared ACP multi-select questions. Floors remain unchanged;
  DeepSeek remains excluded.
- **Next:** resolve feedback on [plan PR #1453](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1453)
  and begin the local successor's release/hash/install/protocol gates.
  Pin-blocking configured/authenticated probes and OMP feature gates remain
  required. Recovered metadata digests are not manifest-ready evidence.

## Delivery ledger

| Done | Step | Exact PR title | Status |
|---|---|---|---|
| [ ] | 1/9 | `🌱 [all-harness-runtime-refresh] docs: publish runtime refresh plan [step 1/9]` | PR #1453 in review; no production changes |
| [ ] | 2/9 | `🌿 [all-harness-runtime-refresh] runtime: refresh mechanical targets [step 2/9]` | OpenCode/Codex/Copilot/Claude/Pi/OMP; each candidate independently gated; pending |
| [ ] | 3/9 | `⚙️ [all-harness-runtime-refresh] runtime: validate Antigravity and Cursor exact builds [step 3/9]` | Exact ACP pair and Cursor build/content gates pending |
| [ ] | 4/9 | `⚙️ [all-harness-runtime-refresh] runtime(hermes): resolve cleanup and refresh target [step 4/9]` | Blocked on empty-session cleanup seam |
| [ ] | 5/9 | `🌿 [all-harness-runtime-refresh] runtime(grok): refresh target [step 5/9]` | Channel/ACP probe pending; namespace/provenance policy corrected |
| [ ] | 6/9 | `⚙️ [all-harness-runtime-refresh] runtime(omp): add Windows arm64 asset [step 6/9]` | Approved eighth asset; hash/mapping/native Windows ARM64 install-version-ACP smoke/documentation gates pending |
| [ ] | 7/9 | `⚙️ [all-harness-runtime-refresh] acp: support OMP multi-select questions [step 7/9]` | Separate option/custom questions; widget/live OMP roundtrip gates plus same-PR question regression/capability docs pending |
| [ ] | 8/9 | `🌱 [all-harness-runtime-refresh] docs: reconcile runtime regression coverage [step 8/9]` | Penultimate; verified behavior only |
| [ ] | 9/9 | `🌿 [all-harness-runtime-refresh] verify: record matrix and retire plan [step 9/9]` | Final L2 target-only matrix; cannot retire with required gaps |

## Harness status matrix

| Harness | Current | Floor/exact policy | Candidate | Status |
|---|---:|---|---:|---|
| OpenCode | `1.18.19` | `1.14.0` unchanged | `1.18.30` | Recommended after six-asset/install/REST-SSE gates |
| Antigravity | package `1.0.0`; server `agy_acp_server_20260818_01_RC01` | Exact package/server/ACP 1; no semantic floor | package `1.1.1`; server pending | Probe-first |
| Codex | `0.153.4` | `0.139.0` unchanged | `0.154.0` | Recommended after independent WebSocket/stdio gates |
| GitHub Copilot | `1.0.80` | `1.0.78` unchanged | `1.0.83` | Recommended after six-asset/ACP gates |
| Cursor | `2026.08.11-e8db854` | date floor `2026.07.16` unchanged | `2026.09.10-fd3934a` | Probe-first; four content hashes and configured load/replay fixture pending; missing fixture blocks pin |
| Claude Code | `2.1.237` | `2.1.221` unchanged | `2.1.269` | Recommended after direct stream gate |
| Hermes Agent | `0.20.4` | `0.20.0` unchanged | `0.21.2` | Blocked; cleanup and configured new/load fixture prerequisites |
| Pi | `0.84.4` | `0.84.1` unchanged | `0.85.1` | Recommended after package/RPC/compaction gates |
| Oh My Pi | `17.3.8` | `17.2.13` unchanged | `18.1.18` | Pin-blocking configured authenticate/list/new/load/cleanup gate pending; approved Windows ARM64 follow-up |
| Grok Build | `1.0.5` | `1.0.5` unchanged | stable channel `1.0.30` | Blocked; reference-required authenticated new/prompt/replay/model-selection/close probes pending |
| DeepSeek | `0.1.5` | `0.1.5` unchanged | None | Explicitly excluded/unchanged |

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
- Recovered audit reports were consumed without repeating discovery.
- 33 candidate digest rows remain explicitly metadata/checksum evidence only;
  candidate bytes were not independently downloaded or installed here.
- No candidate was launched or protocol-probed; no credentials or live profiles
  were used. Required configured/authenticated fixtures remain unavailable and
  block their respective pins; multi-select and Windows ARM64 feature gates
  remain Blocked. Other non-macOS native paths remain Untested.
- No Dart/Flutter tests or analyzer ran because this is a documentation-only
  continuation. Future approved pin PRs run owning focused tests and
  `dart analyze --fatal-infos`; ACP multi-select also runs mapper and widget
  tests without generated churn.
- Validation for this slice is Markdown/link/inventory/title/diff hygiene and
  must not be reported as runtime validation.

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
