# Desktop Distribution — Tracker

Status values: `pending`, `in-progress`, `done`, `blocked`. Evidence belongs with
its completed step; this table tracks implementation, not transient PR reviews.

## Delivery

| Step | PR ordinal | Scope | Status |
|---|---|---|---|
| 1 | 1 | Align platform distribution and update plan | done |
| 2 | 2 | Qualify six-target packaging prerequisites | done |
| 3.a | 3 | Bind desktop builds to bundled bridge identity | done |
| 3.b | 4 | Surface packaged helper repair guidance | done |
| 4.a | 5 | Package and notarize native macOS builds | done |
| 4.b | 6 | Keep desktop startup independent of native notifications | in-progress |
| 5 | 7 | Apply macOS updates through safe application quit | pending |
| 6 | 8 | Publish isolated desktop channels and macOS downloads | pending |
| 7 | 9 | Package signed per-user Windows installers | pending |
| 8 | 10 | Deliver manual Windows updates and winget discovery | pending |
| 9 | 11 | Publish signed native DEB and RPM repositories | pending |
| 10 | 12 | Offer shipped desktop downloads during onboarding | pending |
| 11 | 13 | Reconcile distribution regression coverage | pending |
| 12 | 14 | Verify six-target releases and retire distribution plan | pending |

Exact PR titles, dependencies and the 14-PR total live in [PLAN.md](PLAN.md).
Stable IDs 1, 2, 3.a, 3.b, 4.a, 4.b, 5…12 map to PR ordinals 1…14. Platform ship gates
remain checkpoints within original steps 6, 8 and 9, not additional PRs.

## Alignment — 2026-09-15

The user chose macOS-first delivery, Windows direct download, DEB/RPM for Linux,
installation on normal application quit for app-managed updates, all six native
OS/CPU targets, and GitHub installer downloads plus static GCS feeds/repositories.
The user subsequently authorized automatic implementation after the plan PR merges.
Start step 2 on the merge notification using `sesori-plan-worker`; thereafter keep
one series PR open and at most one successor step local. This supersedes the earlier
plan-only hold. Material scope/security decisions, missing credentials/infrastructure,
and the recorded public-release prerequisites remain gates; do not silently waive
or bypass them. Private signing qualification is underway; no infrastructure was
provisioned and no product was published. Private macOS test packages are now notarized.

Subsequent user clarification (2026-09-15): trusted, widely used, simple tooling
outranks automatic updates. A dedicated manual update button is acceptable.
Windows now uses signed Inno Setup installers and a Download update action, with
no embedded updater. The user explicitly accepts installer-only emulation on
Windows ARM64 and has no Windows ARM QA device. Installed application binaries
remain native; unavailable interactive QA is not passing evidence.

The parent [desktop-app tracker](../desktop-app/TRACKER.md) still records Gate C
and steps 21–22 as pending. This plan starts early at the user's request; those
statuses remain unchanged. Parent closeout is a first-public-release prerequisite
unless the user explicitly accepts a changed prerequisite. The merged
[desktop-ux plan](../desktop-ux/PLAN.md) redirects Gate C's shell/navigation checks
to its step-12 checklist; retain that incoming handoff and its separate ownership of
UI, autostart defaults and app logs. Distribution remains parallel, not a duplicate
UX implementation or a claim that its new checklist has passed.

## Unattended execution — user direction, 2026-09-15

Continue the entire implementation series without further questions. Never stop,
take over or replace the user's running bridge, including indirectly through the
active local desktop. The user selected fresh native CI for both Mac QA targets.
Run every safe autonomous check available; record checks requiring human input,
credentials, unavailable hosts or interactive permissions for the final handoff
instead of waiting. Deferred/blocked checks are not passes and do not authorize
public publication or silently waive the parent/release gates. Continue independent
implementation work when such a gate blocks execution; retain an honest final
verification handoff before deciding retirement/public release.

## Execution

Step 1 merged in [PR #1483](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1483)
as `ef6f3d6548`. Step 2 started automatically in the existing `tan-antelope`
worktree on branch `desktop-distribution-qualification`. Qualification does not
publish product releases or provision signing/hosting resources. Initial source/SDK
and signing-metadata evidence is recorded in [steps/step-02.md](steps/step-02.md).

Step 2 merged in [PR #1487](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1487)
as `833b989517`, with all six native build/inventory/relocated-helper E2E rows passing.
Step 3.a started automatically in the same worktree on
`desktop-distribution-bundle-identity`. The existing reviewed identity boundary is
unchanged; no new lifecycle owner, mutable state, database or wire contract was added.
Implementation, local native evidence and the approved architecture review are
recorded in [steps/step-03.md](steps/step-03.md). PR #1492 merged as
`575dd34dc322f88289efb68731482efe8885fa4b` after accepted head `1528c16f8` passed
24 checks. Final native run 34987193233 passed all six staging/inventory/relocated-
helper E2E rows at merge checkout `83e2e58b39732f706964f313ad13fa7d3f0f7f50`, with
empty canonical source diffs. Windows' stat-only Git false positive is corrected.
Step 3.b started in the same worktree on `desktop-distribution-repair-guidance`;
its focused implementation, approved architecture review and evidence live in
[steps/step-03b.md](steps/step-03b.md).
The existing service/state/presentation path retains user-facing repair guidance
before any installers. No public gate is waived by the split.

Step 3.b merged in [PR #1495](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1495)
as `e853838ac29b5d829f13622702c5d47a74eaa829`, accepting PR head `758bc554`.
Workflow 34994634843 passed its analyzer/test and three desktop build jobs at
Actions merge checkout `c40323edd60873d0a7d6f498ab05c4c8fd2b798f`. All review
threads were resolved; the final Cubic review approved with no findings.
Step 4.a merged in [PR #1499](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1499),
accepting `9f286805514a26cf5e641ab96ee16e79c3bcc7f5`, as squash
`cd4c1412359ef8962cb019d97dc7fed73835e1c8`. All 19 checks settled/passed at acceptance;
Cubic approved without findings and the owner-controlled secret migration remains
an explicit public-release prerequisite. Final unsigned six-target qualification
run 35036003267 measured merge checkout `e4aa30f017cf876a1f61f2a6881f1282f013dba1`.
Step 4.b continues in the same worktree on `desktop-distribution-attention-startup`.
Existing trusted CI credentials produce private Developer-ID-signed, notarized
and stapled packages on both native Macs. The reviewed manifest correction keeps
JSON in Resources and the complete helper in Helpers. Latest run 35019880379 at
`d5a03026dbfe7a95af0a262225c9f3ff640c74d1` qualifies 1.8.4/build 17: empty source
patches, matching downloaded hashes, seven-binary ZIP/DMG inventories, Gatekeeper,
helper E2E and signed synthetic Keychain/registration/file probes all pass.
Source/run/artifact attribution and approved manifest reviews are in
[steps/step-04.md](steps/step-04.md). No public package or local key export occurred.

Step 4.b fixes the separately demonstrated native-attention startup wait without
expanding package-signing ownership. At immutable implementation `25dc586`, all
32 attention cases and both strict client analyzers pass; scoped implementation
architecture review approved. Native package run `35038153010` measured that exact
source (**1.8.4/build 23**): both signed installed windows now visibly render the
login screen, and startup logs reach analytics/rendering. Both package/notary/helper
and synthetic platform legs pass; downloaded hashes and screenshots were inspected.
PR #1503 review exposed reachable pending-readiness logout and captured-retry gaps.
Follow-up `5b6bdb5` keeps readiness outside tracked native writes and replays startup
failure once: 36 attention + 17 logout cases and both strict analyzers pass; second
scoped architecture review approved. Native proof above remains pinned to `25dc586`.
Details and retrieval are in [step 4.b](steps/step-04b.md). The series has 14 PRs;
published history is preserved. No local desktop/bridge was disturbed. Real account,
notification authorization/delivery, interactive TCC, OS-login and ship gates stay open.

## Qualification and ship gates

| Gate | State | Evidence still required |
|---|---|---|
| Native build matrix | All six staging rows passed in final 3.a run 34987193233 | Signed/interactive release gates remain unverified. |
| macOS update path | API/typecheck passed; runtime ordering pending | Sparkle 2.10.0 has both native slices; supported quit-install API compiles. Prove AppKit termination after helper stop before adopting automatic behavior. |
| Windows update path | Simplified with user approval | Manual download + Inno Setup replacement; no WinSparkle/Velopack integration. Verify running-app refusal, safe Quit, signing and native application payloads. Installer-only ARM64 emulation is accepted. |
| Signing and static hosting | Private macOS signed/notarized payloads and synthetic platform probes verified on both CPUs | Rendered GUI/account restoration, interactive TCC/OS-login, updater/Windows/Linux keys, GCS access and owner-approved protected-environment migration of shared repository signing secrets before public publication. |
| macOS public gate | Pending | Both CPUs, parent prerequisite, actual signed N→N+1 upgrade, quit semantics, downloads/feed, complete platform coverage from PLAN.md. |
| Windows public gate | Pending; ARM64 interactive host unavailable | Both CPUs, per-user install/remove, actual signed manual N→N+1 upgrade, safe Quit, signing/SmartScreen observation and winget external path. Native CI build success alone does not close this gate. |
| Linux public gate | Pending | Both CPUs in DEB/RPM, nominated native distro rows, signed repository install/update/remove and desktop-environment coverage. |
| Retirement | Pending | Step 11 docs plus complete recorded matrix; partial, blocked or missing targets keep plan active. |

## Architecture plan review

Performed 2026-09-15 by the `medium-intelligence-fast` subagent using
`architecture-plan-review` (run `b982ac1f-8b95-4585-8912-20f6510f73d2`).

The initial draft was **rejected** for update policy in the cubit, ambiguous update
trigger ownership, unnamed DI phases, and unnamed bundle-manifest boundaries.
Applied the actionable corrections directly:

- `DesktopUpdateService` owns preparation/state/handoff policy over the update
  repository. All update triggers flow through it. No second stop or restore owner.
- `BridgeControlCubit` retains serialized terminal sequencing and invokes the service
  only after `BridgeProcessService` successfully stops the helper.
- Shell updater adapter registers in phase 1; desktop API/repository/service in phase 4;
  the existing `BlocProvider` construction remains the cubit owner.
- Named `DesktopBundleIdentity`, its desktop-core model path, desktop build-time
  producer, manifest location, compiled identity, and pre-spawn resolver consumer.

No user decision changed and no additional mutable coordination was added. Per the
repository review rule, fixes were applied without re-review; do not describe the
corrected draft as reviewer-approved.

Step-2 qualification names the macOS adapter/SwiftPM dependency and replaces dummy
non-macOS updater adapters with a sealed platform capability selected in phase 1.
The user-approved Windows manual path has no updater lifecycle. These evidence-led
plan edits have not been presented as a new architecture-review approval.

PR review follow-up: explicitly named `main`'s guarded first-frame service startup,
subscription ordering, terminal cleanup, Injectable disposal, and cubit presentation
subscription cleanup. Kept the existing pure-Dart Layer-4 quit owner: all terminal
intents enter one tested method, while update policy remains in the service. A new
orchestrator solely for hypothetical future exit callers is not part of this plan.

## Planning validation

- Local Markdown links in all six changed/new documents: passed.
- All 14 tracker ordinals match PLAN.md: passed after the 4.a/4.b split. Published
  titles #1483/#1487/#1492/#1495/#1499 use total 14; commit history was not rewritten.
- Initial `git diff --check`: passed; final whitespace and diff size are checked again
  after review corrections, before committing/pushing.
- Initial measured diff: 555 additions + 17 deletions = 572 authored Markdown lines;
  no generated churn; final measurement belongs in the PR verification evidence.
- Architecture review completed and findings applied as recorded above.
- No Dart/Flutter suites were required for step 1's documentation-only PR.
