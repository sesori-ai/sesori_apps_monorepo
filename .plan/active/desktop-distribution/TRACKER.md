# Desktop Distribution — Tracker

Status values: `pending`, `in-progress`, `done`, `blocked`. Evidence belongs with
its completed step; this table tracks implementation, not transient PR reviews.

## Delivery

| Step | Scope | Status |
|---|---|---|
| 1 | Align platform distribution and update plan | done |
| 2 | Qualify six-target packaging prerequisites | pending |
| 3 | Bind desktop builds to bundled bridge identity | pending |
| 4 | Package and notarize native macOS builds | pending |
| 5 | Apply macOS updates through safe application quit | pending |
| 6 | Publish isolated desktop channels and macOS downloads | pending |
| 7 | Package signed per-user Windows installers | pending |
| 8 | Deliver quit-installed Windows updates and winget discovery | pending |
| 9 | Publish signed native DEB and RPM repositories | pending |
| 10 | Offer shipped desktop downloads during onboarding | pending |
| 11 | Reconcile distribution regression coverage | pending |
| 12 | Verify six-target releases and retire distribution plan | pending |

Exact PR titles, dependencies, expected behavior, and the 12-step total live in
[PLAN.md](PLAN.md). Platform ship gates are evidence checkpoints within steps
6, 8, and 9, not additional PR ordinals.

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

The parent [desktop-app tracker](../desktop-app/TRACKER.md) still records Gate C
and steps 21–22 as pending. This plan starts early at the user's request; those
statuses remain unchanged. Parent closeout is a first-public-release prerequisite
unless the user explicitly accepts a changed prerequisite.

## Qualification and ship gates

| Gate | State | Evidence still required |
|---|---|---|
| Native build matrix | Not run | Flutter, native plugins, helper, installer/updater on all six native targets; Linux ARM64 host-toolchain route explicitly verified. |
| Windows update engine | Not run | Supported authenticated background preparation and retained installer, with installation deferred until helper teardown and normal Quit; default WinSparkle shutdown callback is insufficient. |
| Signing and static hosting | Not provisioned/verified | Developer ID/notarization and update keys, Windows signer, Linux keys, GCS endpoint and least-privilege publication access. |
| macOS public gate | Pending | Both CPUs, parent prerequisite, actual signed N→N+1 upgrade, quit semantics, downloads/feed, complete platform coverage from PLAN.md. |
| Windows public gate | Pending | Both CPUs, per-user install/remove, actual verified N→N+1 upgrade, quit semantics, signing/SmartScreen observation and winget external path. |
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

PR review follow-up: explicitly named `main`'s guarded first-frame service startup,
subscription ordering, terminal cleanup, Injectable disposal, and cubit presentation
subscription cleanup. Kept the existing pure-Dart Layer-4 quit owner: all terminal
intents enter one tested method, while update policy remains in the service. A new
orchestrator solely for hypothetical future exit callers is not part of this plan.

## Planning validation

- Local Markdown links in all six changed/new documents: passed.
- Exact series titles and tracker ordinals: 1–12, all using total 12; passed.
- Initial `git diff --check`: passed; final whitespace and diff size are checked again
  after review corrections, before committing/pushing.
- Initial measured diff: 555 additions + 17 deletions = 572 authored Markdown lines;
  no generated churn; final measurement belongs in the PR verification evidence.
- Architecture review completed and findings applied as recorded above.
- No Dart/Flutter suites are required for this documentation-only PR.
