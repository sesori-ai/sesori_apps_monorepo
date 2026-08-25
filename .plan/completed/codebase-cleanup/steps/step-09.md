# Step 9/45 — Consolidate bridge/app plugin and repository test fakes

## Re-verification against `main`

`routing_test_helpers.dart` had grown to 1,687 lines and still had 62
importers. The plugin-fake estimate was slightly high: current `main` had 17
`NativeProjectsPluginApi` implementations including the existing shared fake,
so 16 local implementations rather than 19; it had 7 local
`BridgeDerivedProjectsPluginApi` implementations rather than 8.

The existing `FakeBridgePlugin`, `FakeSessionMetadataRepository`, and
`FakePullRequestRepository` move to `test/helpers/fakes/`, and a
`FakeDerivedBridgePlugin` now owns the repeated derive-style session listing,
known-directory capture, and directory priming. `routing_test_helpers.dart`
re-exports the moved fakes so its 62 existing importers do not need mechanical
import churn.

Three compatible native implementations and five of the seven derived
implementations now subclass the shared fakes and override only their scenario
behaviour. The two remaining derived implementations exercise specialized
permission/session-option paths. The remaining native implementations are
similarly specialized, strict, or implement an additional test interface;
subclassing them would require overriding shared successful defaults merely to
restore their existing fail-loud behaviour.

`FakePrSyncService` and `FakeSessionRepository` remain in the routing support
file. Their implementations compose several routing-only collaborators and are
used only by routing tests; moving roughly 1,000 lines without replacing a
second copy would violate this series' extraction rule and add relocation noise
without creating shared test support.

## Review corrections

Review found that several first-pass migrations inherited successful defaults
for methods that their former `implements` fakes deliberately left unsupported.
That could let a production regression pass silently. Strict fakes remain local
where subclassing adds no value, and migrated subclasses explicitly throw for
unsupported calls where their old behaviour required it. A follow-up review
confirmed the strictness finding is resolved and reported no remaining
correctness or test-confidence findings.

## Verification

`bridge/app`: `dart format --output=none --set-exit-if-changed test` clean,
`dart analyze --fatal-infos` clean, `dart test` 2,477 passed.

Size, excluding this evidence file, via
`git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD -- bridge/app`
against merge-base `8f857ed22`: **`+567 / -1,226` = 1,793 changed lines**.
This is 293 lines over the 1,500-line soft cap, but is move/deletion-heavy: 465
added lines relocate existing shared fakes, 35 add the derived fake, and the PR
finishes at **659 fewer test lines** overall.

Architecture implementation review not run: this change is test-only and
touches no production class, dependency ownership, or contract.
