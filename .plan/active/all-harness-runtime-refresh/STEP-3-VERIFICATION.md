# Step 3 — Antigravity and Cursor exact builds

## Decision and scope

- **Antigravity: adopt** registry package `1.1.1`, exact server identity
  `agy_acp_server_1.1.1`, ACP 1. Archive/install/initialize, actual production
  validator, teardown and focused checks pass. The five existing platform
  mappings remain.
- **Cursor: blocked, unchanged** at `2026.08.11-e8db854`. Candidate
  `2026.09.10-fd3934a` passed its no-credential checks, but required configured
  load/replay and model/mode checks are incomplete.
- Every independent minimum remains unchanged. Antigravity's `minPathVersion`
  follows the exact package identity; it is not an independent semantic floor.
  Its earlier server pair no longer passes the exact check. Explicit binaries
  remain authoritative and must be replaced as a complete pair.
- No authentication policy, capability, platform, wire/database contract,
  generated production model, or analytics event is added. DeepSeek and
  unrelated upstream changes remain outside this series.

## Antigravity release and integrity

Official registry commit `d30bc9a7c011b522e8502281d5fbcfca51abd5ff`, release
`v2026.09.12-d30bc9a`, declares package `1.1.1` and five Google-hosted ZIPs.
Each selected archive was independently downloaded and SHA-256 hashed. HTTP
content lengths and local sizes agreed. These are local integrity records,
not publisher checksum attestations or source-to-binary proofs.

| Platform | Archive bytes | SHA-256 |
|---|---:|---|
| macOS arm64 | 316014828 | `fdfa915652cdb7ba8085cc8fffed072cbe009251aa2c951aabdda07a8c28a189` |
| Linux arm64 | 656572786 | `ed69e64b308fcb123ab54bf3277bf9cb0d651064f885ea5aab0ff520c7175398` |
| Linux x64 | 681969407 | `38f62d01b32deb0907b3d39a71ec301fd36369f6ffd1cf262d4af385177f79df` |
| Windows arm64 | 468521191 | `35f4b1f47ba6a3fea7b0a3e30010df5ea73a64b4f0e7cf991cddc673ddfbcafc` |
| Windows x64 | 468238392 | `47cb50eef14f0a4655d78cfcfda869bcea7aaee5f9787e936bc2935ea612c3b8` |

All five static ZIP inspections found the expected server/harness siblings.
Archive URLs, hashes, archive sizes, and both member sizes were reconciled
against the production release constants by platform, not copied from prose.
The macOS ARM64 installed members additionally match:

- Server SHA-256: `9d900b93031fc42397f88206e14eba4193729bbef631a70b18e7a19631a6dfac`.
- Harness SHA-256: `e0a8ef9d80a1ffb178f945159dda33f73d4a5be65516642542352584b834fa2a`.

The exact URLs and byte counts live in
`bridge/sesori_plugin_antigravity/lib/src/foundation/antigravity_release.dart`.
No macOS x64 mapping is introduced. Linux/Windows native execution remains
**Untested**; static archive inspection is not native platform verification.

## Antigravity native boundary

The macOS ARM64 candidate ran in fresh synthetic project/state directories
under a restrictive OS sandbox with filtered environment, no ambient
credentials, and no external network. Production managed installation,
checksum validation, extraction, staging and placement used the independently
captured bytes through an exact-URL-checking local download adapter.

Candidate-aware manifest/validator projections were necessary while the
production constants still selected `1.0.0`. Native probing exercised
`AntigravityRuntimeStorage`, `AntigravityRuntimeRepository`,
`AntigravityAcpApi`, `AntigravityLaunchSpecBuilder`, and
`AntigravityEnvironmentBuilder`. This is not a claim that the unmodified
old-pin `AntigravityRuntimeVersionValidator` accepted the new identity.
Post-pin unit checks separately cover that production validator. A bounded
native follow-up on 2026-09-13 also passed the actual production path, reusing
the installed candidate without downloading or reinstalling it:

`AntigravityRuntimeVersionValidator.validate` →
`AntigravityRuntimeService.validateManagedCandidate` →
`AntigravityRuntimeRepository.inspectPair/probe` →
`AntigravityAcpApi.initializeOnly`.

Recording wrappers called production `super` methods. No custom final
predicate, fake frame or recorded-snapshot replay was substituted.

Its first launch failed before Dart `main()` with current-directory access
denied by the sandbox; no candidate started and no validator result was
produced. The outer controller exited 255 after 0.586 seconds, without timeout,
and recorded no survivors. One same-protocol retry explicitly used an allowed
scratch cwd and an unchanged wrapper copy inside the existing read grant.
The compiled helper and sandbox policy were unchanged.

That retry entered `AntigravityRuntimeVersionValidator.validate` and
`AntigravityRuntimeService.validateManagedCandidate`, but production pair
inspection failed at `FileSystemEntity.resolveSymbolicLinksSync` with
`Operation not permitted`. The service returned `AntigravityRuntimeStorageFailed`
and the validator returned `false`; repository probe, ACP initialize and native
candidate spawn were never reached. This is not candidate rejection evidence.
The helper exited 2 after 0.13 seconds, without timeout or surviving owned
processes. The owner then authorized one minimal read-only path-resolution
correction and same-protocol retry. A new profile added only exact
metadata/existence literals for `/` and the owned validation tree's
`antigravity/install-state` and `antigravity/install-state/antigravity` ancestors.
No additional file-content, write, execute, signal or network access was granted;
the original profile, helper and wrapper were preserved unchanged.

That final attempt reached native initialize and returned validator `true`
with the selected managed contract `agy_acp_server_1.1.1`. Native exit `-15`
was observed through production teardown. The outer controller exited 0 in
**1.434 seconds**, did not time out, and recorded no surviving owned processes.
These were infrastructure corrections, not a candidate rejection or gate waiver.

Initial discovery, candidate-aware validation and final production-validator
initialize observations agree on:

- Agent `antigravity-acp`, version `agy_acp_server_1.1.1`, protocol 1.
- Session load/list/resume advertised; standard close absent.
- Authentication logout advertised; methods `oauth-personal`, `oauth-business`,
  `gemini-api-key`, and `agent-platform`.
- No OAuth, session creation, prompt, model operation, or authenticated probe.
  Sesori still exposes **personal OAuth only**.

The production install retained both siblings, correct permissions and the
archive-digest sentinel, with no symlinks or validation staging residue.
Production launch kept the sibling harness path and isolated profile behavior;
Linux `--uid=` and Windows filename policies were not changed.

Both initial install/probe native processes exited with `-15` during normal teardown.
The trusted outer controller completed with exit 0 in **38.603 seconds**, did
not time out, and recorded an empty final owned-process scan. An in-sandbox
presence denial is not evidence of absence. Deadline-expiry fault injection
was not performed.

## Cursor candidate boundary and blocker

The official installer at `https://cursor.com/install` was captured, not
executed. Its exact candidate URLs use
`https://downloads.cursor.com/lab/2026.09.10-fd3934a/` followed by
`{darwin|linux}/{arm64|x64}/agent-cli-package.tar.gz`.

| Platform | Archive bytes | SHA-256 |
|---|---:|---|
| macOS arm64 | 174178929 | `aec0b01ae056de48a02fe315fbf0580eb91377752d993307499988cbe0285423` |
| macOS x64 | 181409095 | `964cc72e88125c6b48ecaaebef68bf7cb752eb7b9d010a5535cf9f8e677dcf83` |
| Linux arm64 | 177655979 | `e0494438b01c37bc34848491d1f3478ef469494c56caf020de11796d146db64a` |
| Linux x64 | 179673253 | `27997c8391ad853a5a732b1845db8ef82a8ba6afb0f7829cc739464f8966e96e` |

All four records come from independently downloaded bytes; no publisher
checksum or source attestation is claimed. Native evidence is macOS ARM64 only:

- Production installer/extractor/staging/checksum/version validation through
  candidate metadata and an exact-URL-checking local byte adapter.
- Complete package retained: 568 entries, no symlinks, executable entrypoint,
  matching sentinel, and no staging residue. Worker/runtime/native-module
  siblings were not reduced to a single binary.
- Exact `--version` succeeded; production `cursor-agent acp` launch initialized
  ACP 1, advertising `cursor_login`, load/list and parameterized model picker.
  No endpoint override, authentication, session or model/mode request was made.
- Restricted OS sandbox, synthetic state/project and filtered environment;
  external network and ambient credentials were unavailable.
- Candidate exit 143 was observed. Trusted outer cleanup handled an owned
  orphaned `rg --files` descendant and confirmed an empty final group. It
  passed in **6.929 seconds**, within the 120-second deadline, without timeout.

Configured persisted-session load/replay remains required before pinning;
model/mode checks are also `BLOCKED_AUTH_REQUIRED`. Completion needs explicit
owner authorization for an isolated disposable Cursor login/profile or scoped
API credential, the normal Cursor endpoint, one persisted synthetic-project
session, and bounded list/load/replay/model/mode/cleanup operations. No ambient
profile, credentials or provider access may be inferred from “continue”.

Cursor's date floor, explicit-binary precedence, full package layout, endpoint
behavior, and Darwin/Linux-only support remain unchanged. Its source and
post-pin tests are untouched because no Cursor pin was applied.

## Post-pin verification and recovery

Pinned Dart **3.13.3** completed Antigravity's owning analyzer with
`analyze --fatal-infos`. Formatting all five changed Dart files made no changes.
**68 distinct tests across nine files passed**, using the latest execution of
each affected suite rather than counting retries as additional coverage:

- Release/launch, historical initialize fixture, runtime manifest, storage,
  version validator, runtime service, descriptor, plugin, authentication composer.
- The first eight-file run exposed two descriptor failures: its current-runtime
  fake reused the historical `1.0.0` initialize capture. The descriptor and
  authentication composer now use a separate, explicitly synthetic current
  fixture. The historical capture remains unchanged and its decoder test checks
  its historical identity. The affected 19 tests passed on the focused follow-up;
  the seven unchanged passing suites were not rerun.

No production classes, ownership, launch policy or internal/wire contracts
changed, so a new architecture review was not required. Full repository tests
and analysis remain CI-owned. No initial download/install/protocol probe was
repeated for a documentation-only change or handoff recovery.

The parent async runner disappeared before writing its result, independently
of the successful native controller outcomes. Both completed reports survived,
were preserved, and were recovered through their retained native child sessions.
Recovery performed no candidate execution, stale-PID signaling or tracked/Git
mutation. Parent reconciliation accepted the raw evidence and completed the actual
production-validator follow-up before accepting Antigravity's target. Runner failure was neither a candidate regression
nor permission to weaken the candidate sandbox.

Private supporting records remain beneath
`.dart_tool/runtime-refresh-validation/`:

- `antigravity/metadata/{integrity-summary,archive-layout}.json`;
  `antigravity/logs/final-probe{.controller,-summary}.json`;
  `antigravity/probe/antigravity_candidate_probe.dart`; `antigravity/post-pin/`;
  `antigravity/production-validator/retry-2/` report, native result, controller
  result, permission diff and ownership records.
- `cursor/official/selected-assets.tsv`; `cursor/probe/runs/install-protocol/`
  install/ACP/outer-owner/outer-result records; both lane reports and preserved
  handoff copies.

These records contain local diagnostic context and are not uploaded wholesale.
The public evidence above contains no credentials, prompts, provider payloads,
account identifiers, or user-local absolute paths.
