# Attribution Activation Events — Tracker

**Delivery:** One PR

**Planned PR title:** `⚙️ Add Singular activation attribution events`

**Status:** PR [#1236](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1236) is open and monitored.

## Checklist

- [x] Copy the owner-authored plan into this worktree.
- [x] Record the owner decision that activation attribution remains independent of the product-analytics preference.
- [x] Review the architecture-bearing implementation approach (rejected; both valid findings applied directly to the plan).
- [x] Add the closed attribution events and the single attribution coordinator.
- [x] Persist and coalesce the two once-per-installation Singular milestones.
- [x] Allow Singular partner data sharing while retaining the advertising-identifier limit.
- [x] Update the privacy disclosure and analytics regression contract.
- [x] Run focused module-core/mobile tests and analysis.
- [x] Complete architecture implementation review (pass 2 approved after the pass-1 fix).
- [x] Commit, push, open PR #1236, and start autonomous monitoring toward human review.

## Decisions and evidence

- **2026-09-01 — privacy gate:** The owner chose to keep `bridge_paired` and `first_session_run` independent of the Basic Usage Analytics preference. The implementation and disclosures must not imply that preference controls Singular.
- **2026-09-01 — activation definition:** Reuse the existing successful `sessionMessageSent` and `sessionCreatedWithMessage` outcome seams; queued/offline, failed, permission/question, and empty-session actions remain excluded.
- **2026-09-01 — pairing definition:** A successful E2E `ConnectionConnected` transition is the concrete proof that this installation paired with a bridge.
- **2026-09-01 — architecture plan review:** Rejected because the first draft split equivalent triggers across structural levels and omitted an explicit startup owner for the connection listener. The plan now makes one Layer-3 `AttributionService` the repository-dispatch choke point and starts its owned connection subscription explicitly from mobile bootstrap. Per repository policy, the valid findings were applied directly without a second review.
- **2026-09-01 — architecture implementation review pass 1:** Rejected with one P0: starting the connection listener before the asynchronous crawl-gate decision could let a returning signed-in connection activate Singular from pending configuration. The fix starts the listener only after gate application, relies on replayed connection status, and retains one pre-start full-activation milestone so a fast successful send is delayed rather than lost or used to bypass the gate.
- **2026-09-01 — architecture implementation review pass 2:** Approved with no remaining architecture findings.

## Verification record

- `dart run build_runner build --delete-conflicting-outputs` passed in `client/module_core` and `client/app` (the pinned build_runner reports the obsolete flag as ignored).
- `dart test test/services/attribution_service_test.dart test/services/installation_analytics_service_test.dart test/services/product_analytics_service_test.dart` passed in `client/module_core` (60 tests).
- `flutter test test/core/platform/singular_attribution_client_test.dart test/core/platform/singular_attribution_startup_test.dart test/main_startup_notification_wiring_test.dart` passed in `client/app` (15 tests); the crawl-gate ordering fix was then rechecked with the four startup-wiring tests.
- `dart analyze` passed with no issues in both `client/module_core` and `client/app` after the final fix.
- `git diff --check` passed before delivery.
