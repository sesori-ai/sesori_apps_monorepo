# Desktop Distribution — Tracker

Status values: `pending`, `in-progress`, `done`, `blocked`. Evidence belongs with
its completed step; this table tracks implementation, not transient PR reviews.

## Delivery

| Step | PR ordinal | Scope | Status |
|---|---|---|---|
| 1 | 1 | Align platform distribution and update plan | done |
| 2 | 2 | Qualify six-target packaging prerequisites | done |
| 3.a | 3 | Bind desktop builds to bundled bridge identity | in-progress |
| 3.b | 4 | Surface packaged helper repair guidance | pending |
| 4 | 5 | Package and notarize native macOS builds | pending |
| 5 | 6 | Apply macOS updates through safe application quit | pending |
| 6 | 7 | Publish isolated desktop channels and macOS downloads | pending |
| 7 | 8 | Package signed per-user Windows installers | pending |
| 8 | 9 | Deliver manual Windows updates and winget discovery | pending |
| 9 | 10 | Publish signed native DEB and RPM repositories | pending |
| 10 | 11 | Offer shipped desktop downloads during onboarding | pending |
| 11 | 12 | Reconcile distribution regression coverage | pending |
| 12 | 13 | Verify six-target releases and retire distribution plan | pending |

Exact PR titles, dependencies and the 13-PR total live in [PLAN.md](PLAN.md).
Stable step IDs 1, 2, 3.a, 3.b, 4…12 map to PR ordinals 1…13. Platform ship gates
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
or bypass them. No signing, infrastructure provisioning, or product publication has
yet been performed.

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
recorded in [steps/step-03.md](steps/step-03.md). PR #1492 at `7ff3293` passed all
24 checks, including six native staging rows in run 34976451046 with empty canonical
source diffs. Windows' stat-only Git false positive is reproduced and corrected.
Review identified missing user-visible refusal state; immediate successor 3.b owns
that small service/state/presentation change before any installers, rather than
expanding the near-cap foundations PR. No public gate is waived by the split.

## Qualification and ship gates

| Gate | State | Evidence still required |
|---|---|---|
| Native build matrix | All six staging rows passed in run 34976451046 | Signed/interactive release gates remain unverified. |
| macOS update path | API/typecheck passed; runtime ordering pending | Sparkle 2.10.0 has both native slices; supported quit-install API compiles. Prove AppKit termination after helper stop before adopting automatic behavior. |
| Windows update path | Simplified with user approval | Manual download + Inno Setup replacement; no WinSparkle/Velopack integration. Verify running-app refusal, safe Quit, signing and native application payloads. Installer-only ARM64 emulation is accepted. |
| Signing and static hosting | Not provisioned/verified | Developer ID/notarization and update keys, Windows signer, Linux keys, GCS endpoint and least-privilege publication access. |
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
- All 13 tracker ordinals match PLAN.md: passed. Published titles #1483/#1487/#1492
  were synchronized to total 13; commit history was not rewritten.
- Initial `git diff --check`: passed; final whitespace and diff size are checked again
  after review corrections, before committing/pushing.
- Initial measured diff: 555 additions + 17 deletions = 572 authored Markdown lines;
  no generated churn; final measurement belongs in the PR verification evidence.
- Architecture review completed and findings applied as recorded above.
- No Dart/Flutter suites were required for step 1's documentation-only PR.
