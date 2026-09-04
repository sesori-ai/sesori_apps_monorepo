# Consolidation of cleanup PR #1296

The user requested that useful findings and steps from
[#1296](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1296) be folded into
[#1295](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1295), and that
#1296 be closed. This is the retained disposition ledger; PLAN.md and TRACKER.md
are the single executable series. Source plan reviewed at
`c7f35a5c7936ac3cc1b9ed7399b7b81436c8253a`, based on the same `480d82f090` baseline.
The source PR remains the historical evidence, not a second active plan.

## Source-step mapping

| #1296 step | Disposition in periodic-cleanup | Reason / preserved value |
| --- | --- | --- |
| 1 Plan | Superseded by step 1 | One plan, one denominator, no duplicate implementation PRs. |
| 2 Runtime composition/cold start | Steps 12–13 | Keep install extraction; add provision factory and bounded cold-start wait. Preserve plugin validators, OMP dynamic Linux resolver, descriptor HTTP lifetime and unconditional abort rollback. No single-use installer guard. |
| 3 Unified view tracker | Deferred, not executable | The current session tracker publishes per-connection starts; project tracking publishes synchronous aggregate changes. A combined class would give both instances both stream contracts and extra emission work. Revisit if a measured maintenance issue justifies this, preserving dispatch timing and two-client unseen semantics. No empty-ID alignment change is bundled into cleanup. |
| 4 Paired listeners | Deferred policy proposal | Warm-up and glossary pairs have shared work, but merging them changes the current one-trigger-per-listener rule. User authorized consolidation of useful findings, not an explicit replacement of that architecture rule. Keep the idea and its small scope below; do not silently edit AGENTS/reviewer skills to enable it. Asymmetric options listeners remain separate. |
| 5 Local worktree/Codex loops | Step 14 | Useful common algorithms; preserve different suffix termination and retry semantics. No generic callback/retry/parser framework. |
| 6 Error logging | Step 15, overlaps folded into 7/13/14 | Keep error/stack/context, avoid redundant logs and raw content. Source count is a candidate inventory, not a claim every site drops a stack. |
| 7 Compatibility retirement | Deferred explicit product-policy decision | Raising the minimum supported public peer from the earlier baseline to v1.6.0 is not authorized by a generic cleanup request. Preserve wire defaults until a supported-peer decision and per-field release evidence exist. Marker age alone never proves safe removal. |
| 8 Shared Flutter adapters | Thumbnail/directory duplication handled by step 10; remaining adapter relocation deferred | Pure-Dart file/cache logic can be shared without changing shell platform rules. Sharing the additional Flutter plugin adapters in module_app_ui would change its allowed dependency/ownership boundary. Keep shell bindings and native provider adapters in the executable plan. |
| 9 Shared screen composition | Step 16 | Four fresh-cubit composition functions in core DI; preserve shell lifecycle and distinct analytics/view owners. No GetIt in cubits. |
| 10 Rename/variant/auth | Rename step 11; auth step 17; variants completed externally by #1294 | Keep per-entity rename state and adopt cubits/shared placement. Do not duplicate merged selection policy. Keep separate review scopes for rename and sensitive auth folds. |
| 11 Desktop attention | Deferred to a dedicated follow-up after desktop-app retirement | Useful complexity finding; existing logout drain is a real account-boundary flow. A generic promise of eventual convergence is insufficient. Required contract below prevents loss of the finding or automatic deletion of guards. |
| 12 Bridge tests | Step 18, narrowed to substantial fixtures | Prefer useful setup/body consolidation; preserve distinct fake behavior and assertions. Do not centralize every trivial declaration. |
| 13 Client tests | Step 19, same narrowing | Keep Flutter helpers in owning test trees and preserve #1294 tests. Avoid a global configurable mock framework. |
| 14 Dependencies/keys/symbols | Step 20 | Recheck all source/generated/tool/test imports and builder use. Keep direct dependencies when needed; regenerate outputs properly. |
| 15 Historical documents | Step 21, expanded by the user | Audit root/package/general docs as well as completed reports; preserve durable contracts and unresolved follow-up inventory. |
| 16 Regression docs | Steps 22–24, expanded by the user | Simplify every regression guide, remove pointless/duplicate/stale content, then reconcile README/index and final behavior without reducing the frozen matrix. |
| 17 Coverage/retirement | Step 25 | Original impact-scoped L4 matrix plus adopted-work rows. No implicit matrix reduction or optional completion of unexecuted required work. |

## Merged #1294: no additional variant cleanup

Verified merged at 2026-09-04 20:20:15 UTC, merge commit `da2e9eeb47`.
It adds `SessionSelectionCalculator`, removes duplicated selection helpers and
obsolete selector DI, and updates selection regression tests/documents. Inspect
its actual merge diff, not only the PR body, when rebasing implementation.

The cleanup must retain its handling of catalog availability, paired model and
variant updates, agent-declared models and intentional transcript/current-model
retention. Steps 2–3 change transcript reconciliation only; step 16 constructs
the current cubit/service dependencies. No replacement calculator, second
variant helper or new availability flag. Source review confirms #1294 did not
remove the streaming clear or wholesale snapshot transcript replacement; the
original diagnostic findings remain relevant, but their tests must be rerun on
the implementation base before claiming a post-merge reproduction.

## Deferred findings retained with a concrete reopening condition

**Shared Flutter adapters:** file-save, file-image-saver, clipboard/pasteboard,
image sharing/share-plus and no-op analytics copies are candidates. Their
wrappers are mostly short; module_app_ui relocation would add file_selector,
pasteboard, path_provider and share_plus dependencies and require a deliberate
architecture decision. If approved separately, preserve shell DI and
surface-specific adapters, move one copy, and prove actual device behavior.
Thumbnail storage's larger duplicate algorithm is already covered by step 10.

**Listener pairs:** viewed-session warm-up / setting-triggered warm-up and
current-project / viewed-project glossary each could share one concern owner
with CompositeSubscription and one drain. Reopen only with an explicit
one-concern-versus-one-trigger rule decision and a net reduction in lifecycle
state. Do not merge options-refresh listeners or analytics widgets whose
contracts differ. Estimated dedicated change: 300–500 lines plus validation.

**Desktop attention:** revisit after the active desktop-app manual-testing gate
and retirement, with a dedicated architecture-bearing scope (roughly 600–900
lines). The current pending-request map, per-session generation/write tracking
and in-flight set make one owner difficult to reason about. However:

- `suspendAndClearForLogout` must synchronously reject new alerts, await every
  accepted native write, and then await cancellation before credentials are
  removed. This must work with no subsequent event to repair state.
- Failed logout may resume the original account's pending work; completed logout
  clears pending notification-open and request state. A new account must not
  inherit old prompts, titles or notification-open routing.
- Disposal and auth cleanup need the same finite drain guarantee, with useful
  local error context on native cancellation failure.

A single serialized owner may replace per-session chains/registries, but count
its desired and applied state honestly and demonstrate these barriers first.
Do not promise an arbitrary eight-field ceiling or call all existing generation
checks theoretical. Deterministic held-show/cancel/logout tests and real native
notification/logout evidence are required before adopting that design.

**Compatibility floor:** retain #1296's list as a starting inventory, not a
removal approval: plugin attribution defaults/discovery fallback; Project
path/time/unseen/directory/worktree fields; OpenProjectRequest.gitAction;
SessionStatusResponse.unavailablePluginIds; Session.pullRequestHistory; nullable
project event payload. Confirm the actual oldest supported public peer sends
each field. Backend/on-disk/auth-server compatibility has different retiring
conditions and must not be swept by a Sesori release date.

These deferrals are outside the 25-step execution/retirement matrix. Closing
#1296 does not approve them or require reopening that competing series later.
