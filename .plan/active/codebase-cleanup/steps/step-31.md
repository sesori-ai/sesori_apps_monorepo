# Step 31 — SessionDetailCubit derivation and analytics

`SessionDetailCubit` and two loaded-state analytics callers retained repeated
derivation and delivery state machines. This step consolidates those copies
without changing refresh coordination, analytics events, or product behavior.

## Re-verification against `main`

- The session-detail derivation copies remained, although several line numbers
  and duplicate counts in the plan had drifted.
- `SessionDetailSnapshot.agents` remained nullable even though all production
  sources produced non-null `AgentInfo` values.
- Project-inventory and session-diff analytics still owned equivalent
  independent empty/non-empty guards and activation retry subscriptions.
- Their event types and current-state lookup differed, so the shared
  collaborator accepts bounded classification mapping and retains only its own
  delivery state.
- Explicit snake-case refresh trigger values remain intentional log values;
  replacing them with enum `.name` would change existing diagnostics.
- Project-list reconnect timeout handling remains in Step 32 as planned.

## What changed

- Added shared snapshot and queue projections in `SessionDetailCubit`, plus one
  refresh-ended emitter and one optimistic reply submission path.
- Made snapshot agents non-null, consolidated assistant model and child-session
  derivation, and derived `retryErrorMessage` directly from `sessionStatus`.
- Corrected the pending-event buffer documentation to match failed-load
  clearing behavior.
- Added `LoadedStateAnalyticsReporter`, one instance per owning cubit, and moved
  the duplicated loaded-state delivery guards and activation retry lifecycle
  out of `ProjectListCubit` and `DiffCubit`.
- Kept event mapping in module core through named reporter factories so Flutter
  screens only construct and inject the per-cubit collaborator.
- Preserved the successful-load occurrence timestamp when an empty
  classification is retried after analytics activation.
- Added the caught error and stack trace to best-effort session-event failure,
  project-view declaration, relay send, and subscription-cleanup logs.

Change-budget totals exclude this evidence file and use the merge base with
`origin/main`:

```bash
BASE=$(git merge-base HEAD origin/main)
git diff --numstat "$BASE"...HEAD -- client/app/lib client/module_core/lib
git diff --numstat "$BASE"...HEAD -- client/app/test client/module_core/test
```

| Scope | Additions | Deletions |
| --- | ---: | ---: |
| Production/lib, including generated Freezed output | 357 | 393 |
| Tests | 350 | 31 |

## Behavior

No user-visible or database behavior changes. Session refresh ownership,
queued-prompt rendering, optimistic question and permission replies, analytics
event variants, once-per-cubit guards, and activation retry semantics remain
unchanged. No wire or persisted contract changed.

## Verification

```bash
cd client/module_core && dart run build_runner build --delete-conflicting-outputs  # 0 outputs
cd client/module_core && dart analyze --fatal-infos                                # clean
cd client/module_core && dart test test/cubits/session_detail test/cubits/project_list test/cubits/session_diffs test/services/loaded_state_analytics_reporter_test.dart test/services/product_analytics_service_test.dart test/services/installation_analytics_service_test.dart  # 312 passing
cd client/app && flutter analyze --fatal-infos                                     # clean
cd client/app && flutter test test/features/session_detail                         # 240 passing
cd client/module_desktop_core && dart analyze --fatal-infos                        # clean
cd client/desktop && flutter analyze --fatal-infos                                 # clean
git diff --check                                                                   # clean
```

The pinned formatter still hits its known enhanced-enum crash; all owning and
downstream analyzers are clean.

A focused correctness review found no issues. Architecture implementation
review approved session-detail state and lifecycle ownership but rejected the
reporter's planned `services/` location and initial shell event mapping. Event
mapping was moved into module-core named factories. The remaining location
finding conflicts with the user-approved Step 31 placement, which explicitly
puts this per-cubit collaborator beside existing per-instance services, so the
approved plan supersedes that finding under repository review policy.
