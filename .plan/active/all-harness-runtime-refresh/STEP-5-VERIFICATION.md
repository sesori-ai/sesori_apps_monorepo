# Step 5 — Remaining targets and update-first delivery

## Scope and owner direction

On 2026-09-13 the owner directed this series to update every included harness,
not retain old targets because tests, credentials or runners are unavailable.
Unresolved checks and concrete user-assisted validation belong at the end of
this plan. Only an exceptional demonstrated problem can justify a temporary
hold with a specific resolution. No such exception is established here.

This step changes five production target declarations and 17 managed digests,
plus owning test expectations. The runtime skill/reference and plan/tracker
record that policy and the isolation/evidence lessons from earlier attempts.
No production class is added or moved; no launch, authentication, floor, schema,
wire, lifecycle, generated file or capability implementation changes. DeepSeek
is excluded. Windows ARM64 and multi-select remain separate approved steps.

## Applied targets

| Harness | Previous target | New target | Unchanged floor | Distribution |
|---|---|---|---|---|
| Codex | `0.153.4` | `0.154.0` | `0.139.0` | Six canonical package archives |
| Cursor | `2026.08.11-e8db854` | `2026.09.10-fd3934a` | `2026.07.16` | Four complete package archives |
| Hermes | `0.20.4` | `0.21.2` | `0.20.0` | Direct configured/PATH CLI |
| OMP | `17.3.8` | `18.1.19` | `17.2.13` | Seven existing direct-binary mappings |
| Grok | `1.0.5` | `1.0.30` | `1.0.5` | Direct configured/PATH CLI |

These are target updates, not claims that every native check passed. Compatible
older PATH installations remain accepted. Existing minimum/older-version tests
and historical protocol captures were not mechanically relabeled as new evidence.
Hermes/Grok target comments now say targeted, not fully validated.

## Release and integrity evidence

Official release/installer recheck began at `2026-09-13T10:20:52Z`:

- [Codex rust-v0.154.0](https://github.com/openai/codex/releases/tag/rust-v0.154.0):
  stable, not draft/prerelease. Annotated tag object
  `36eab01061df3cde5f95ec20a526777b430091ba` peels to commit
  `6b9826e3aa83b1a5947db50f4332cb9c65f1b340`, matching retained evidence.
  Six independent archive-hash records still match current release digests;
  the earlier publisher-checksum reconciliation remains valid.
- [Cursor official installer](https://cursor.com/install), fetched as text and
  not executed, still selects `2026.09.10-fd3934a`. Four independently downloaded
  package hashes from Step 3 were reused. They are local integrity records, not
  publisher attestations. Complete package layout and date policy are unchanged.
- [Hermes v2026.9.11](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.11):
  latest release name reports CLI `0.21.2`, not draft/prerelease. Tag object
  `2160b2d59c87316e82f749d77c1f25969bea1533` peels to retained commit
  `939e45c91d751fadd94dcd1b873ac3cb44846213`. Zero managed assets.
- [OMP v18.1.19](https://github.com/can1357/oh-my-pi/releases/tag/v18.1.19):
  newly selected latest stable, published `2026-09-12T23:57:09Z`, direct commit
  `e4dd2ec3b487f216c569281e2cdb7ec476a81f2e`. It supersedes the earlier audited
  `18.1.18`. All eight platform binaries and `SHA256SUMS.txt` were downloaded
  afresh as opaque bytes. Sizes/GitHub digests match; all eight binary hashes
  also match the publisher checksum file. Seven mappings change here; the
  Windows ARM64 artifact is reserved for Step 6, not advertised by this PR.
- [Grok stable channel](https://x.ai/cli/stable) returned HTTP 200 and `1.0.30`
  at `2026-09-13T09:57:32Z`. Zero managed assets; no Grok candidate was downloaded
  or executed. Stable metadata does not prove branded native identity or auth.

The final three manifests' **17 asset-name/hash pairs** were reconciled
programmatically against independent machine-readable records, not report prose.
No accepted Codex/Cursor download or install was repeated. No binary parsing,
archive extraction, installer execution or candidate invocation occurred in Step 5.

OMP's incremental compare reports 172 commits and 235 changed files, with no
ACP/elicitation/ask-dialog-named path changes. This is a partial source audit,
not proof that session/provider behavior is unchanged. Broader source/native
follow-up remains in the final queue; no extra upstream feature is adopted here.

Local retained records under `.dart_tool/runtime-refresh-validation/`:

- `codex/metadata/independent-sha256.txt` and original publisher records;
- `cursor/official/selected-assets.tsv`;
- `step-5/metadata/` release JSON, installer text, resolved tags, incremental
  compare and `omp-independent-integrity.json`;
- `step-5/omp-assets/` opaque binaries/checksum file, including reserved ARM64;
- `step-5/checks/` command records, per-package JSON test output and analyzer logs.

## Focused verification

Pinned Dart 3.13.3 from Flutter 3.47.4-stable was used. Each package ran the named
files with `dart test --reporter=json`, followed by `dart analyze --fatal-infos`.

| Owning package | Suites under its `test/` directory | Distinct passing cases |
|---|---|---:|
| `sesori_plugin_codex` | `runtime/codex_runtime_manifest_test.dart` (5), `runtime/codex_runtime_policy_test.dart` (11), `runtime/codex_plugin_descriptor_setup_test.dart` (22) | 38 |
| `sesori_plugin_cursor` | `runtime/cursor_runtime_manifest_test.dart` (5), `cursor_plugin_descriptor_availability_test.dart` (21) | 26 |
| `sesori_plugin_omp` | `omp_runtime_manifest_test.dart` (5), `omp_runtime_asset_repository_test.dart` (4), `omp_plugin_descriptor_test.dart` (18) | 27 |
| `sesori_plugin_hermes` | `hermes_plugin_descriptor_test.dart` | 18 |
| `sesori_plugin_grok` | `grok_plugin_descriptor_test.dart` | 12 |

**121 cases across 10 suites pass**, with no failed/skipped counted cases; all
five test invocations report `done.success: true`. All five analyzers exit zero.
Dart formatting checked 12 changed Dart files, with zero formatting changes.
Counts come from non-hidden `testDone` events mapped to suites, not compact
progress labels or source declarations. These are unit/fake-process checks,
not candidate execution. Full repository CI remains CI-owned.

## Retained limits and final follow-ups

| Harness/check | What remains unresolved |
|---|---|
| Codex | Existing native package/install and both transports passed, but probe automatic teardown failed. Prior owned processes were cleaned; no further cleanup retry is authorized. Target adoption does not erase that failure. |
| Cursor | Existing macOS ARM64 install/initialize/cleanup passed. Configured load/replay/model/mode remains unverified. |
| Hermes | Step 4's fresh load failed; launch/isolation/evidence was not accepted, original DB/logs were lost, and configured persisted deletion was not proven. No native rerun occurred or is newly authorized. |
| OMP | Earlier native install/version/initialize observations are **18.1.18 only**. Current 18.1.19 native/production-seam and configured lifecycle/cleanup checks are deferred to the grouped final OMP verification, not reported as passes. |
| Grok | Native identity/exact launch and authenticated new/prompt/replay/model-selection/close remain unverified. Test authorization is conditional on a secure separate credential and precise endpoint scope; no ambient login may be used. |
| Approved features | Native Windows ARM64 smoke and the live multi-select roundtrip remain separate final checks after implementation. |

See the concrete final follow-up batch in [PLAN.md](PLAN.md) and independent
update/verification rows in [TRACKER.md](TRACKER.md). Historical details remain in
[Step 2](STEP-2-VERIFICATION.md), [Step 3](STEP-3-VERIFICATION.md) and
[Step 4](STEP-4-VERIFICATION.md); their former pin-blocking policy is superseded,
not their actual results. Do not retire the plan or claim these gaps resolved
without final evidence or explicit owner acceptance.
