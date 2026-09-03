# Step 20 slice 3/3 — Desktop attention notifications

- **Status:** `done`
- **Complexity:** `🚧`
- **User value:** Desktop users receive privacy-safe permission/question alerts
  while Sesori is hidden or unfocused, and opening an alert focuses the correct
  account-bound session.
- **Dependencies:** Step 20 slices 1/3 and 2/3, especially the merged cockpit routes from PR #1269
- **Pinned implementation head:** `6a88e5819786790cd20fa7e7df72611479d8962b`

## Scope

- Reuse the shared local-notification capability while keeping desktop push-free.
- Add account-bound notification payloads and preserve mobile handling for payloads without an account binding.
- Expose typed desktop window focus/visibility state and a native macOS/Windows/Linux local-notification adapter.
- Derive permission/question attention directly from authenticated relay SSE,
  without changing `SseEventTracker` ownership.
- Persist one desktop attention preference and expose it through a desktop-owned settings toggle.
- Focus and route notification opens through a product-shell dispatcher after the desktop router mounts.
- Fence native writes and opens across logout/authentication loss, settling
  writes and clearing delivered notifications before credentials are removed.

## Implementation Summary

- Moved the typed `LocalNotificationPayload` into `module_core`, added nullable
  account binding to local open requests, added client disposal, and added
  awaited `cancelAll()` while retaining best-effort session cancellation.
- Kept mobile notification opens account-unbound (`accountId: null`) and
  regenerated Freezed/JSON plus DI outputs rather than editing generated files.
- Added `DesktopLocalNotificationClient`, including deterministic session
  identity, typed payload parsing, initialization retry, Linux callback
  ordering, and generated native plugin registration.
- Added `WindowHostState` (`focused`, `unfocused`, `hidden`) to the Layer-0
  capability and emitted it from `FlutterWindowHost` lifecycle callbacks.
- Added desktop-instance preference storage/repository delegation,
  `DesktopAttentionPreferenceCubit`, and the Settings toggle without exposing
  the mobile push-preference surface.
- Added `DesktopAttentionService` as the Layer-3 owner of direct SSE
  classification, title resolution, focus/preference/auth gates, pending
  requests, generation fencing, serialized per-session native writes, open
  routing, and authentication cleanup.
- Added `DesktopRouteDispatcher` plus the first-frame router-readiness fence as
  product-shell navigation adapters used by notification opens.
- Integrated attention cleanup into `DesktopLogoutOrchestrator`: cleanup starts
  synchronously with logout, settles native writes, attempts cancel-all, and
  completes before local authentication is cleared.
- Updated notification and desktop-supervision regression contracts.

## Architecture Review

- Reviewed exact range
  `51140cac2536ac747d7bc3141c33d585e5e8804b..6a88e5819786790cd20fa7e7df72611479d8962b`
  against the authoritative full artifact `/tmp/desktop-attention-slice3-architecture-review.patch` (4,399 lines,
  189,820 bytes).
- Result: **APPROVED** with no findings. The review confirmed shared/product-shell notification ownership, Layer 0–4
  dependency direction, startup/DI/disposal ownership, direct SSE ownership, account/logout fencing, route readiness,
  and the desktop no-push boundary.

## Verification

- Ran `asdf exec dart run build_runner build` in `client/module_core`,
  `client/module_desktop_core`, `client/desktop`, and `client/app`; generated
  outputs are current.
- Fatal-info analysis passes in `client/module_core`, `client/module_desktop_core`, `client/module_app_ui`,
  `client/desktop`, and `client/app`.
- Full suites pass:
  - `client/module_core`: 1,485 tests.
  - `client/module_desktop_core`: 255 tests.
  - `client/module_app_ui`: 282 tests.
  - `client/module_prego`: 270 tests.
  - `client/desktop`: 117 tests.
  - `client/app`: 663 tests.
- Focused notification, logout, preference, route-dispatch, window-state, DI, Settings, and mobile-adapter suites pass.
  The attention initialization-retry test intentionally logs
  `Failed to initialize desktop attention notifications: Bad state: native initialization unavailable` before proving
  that the next eligible request retries successfully.
- Dart LSP reports zero diagnostics across all 30 changed production Dart files.
- A clean `asdf exec flutter build macos` succeeds (66.3 MB reported by Flutter), and
  `codesign --verify --deep --strict` accepts the resulting `Sesori.app`.
- `git diff --check` passes.
- The pinned implementation range contains 2,847 additions plus 246 deletions, or 3,093 changed lines across 62 files:

```bash
git diff --numstat \
  51140cac2536ac747d7bc3141c33d585e5e8804b \
  6a88e5819786790cd20fa7e7df72611479d8962b \
  | awk '{ additions += $1; deletions += $2; files += 1 } \
      END { print files, additions, deletions, additions + deletions }'
# 62 2847 246 3093
```

The slice exceeds the 1,500-line soft cap because the account-safe service, shared contract migration, native adapter,
logout integration, and their directly proving tests form one lifecycle flow. The approved split explicitly kept these
together rather than shipping an unused contract or separating credential cleanup from the native-write owner.

## Residual Verification

- Real macOS notification delivery, replacement/cancellation, click-to-focus routing, account transitions, and the
  persisted toggle remain part of user-run MT Gate C.
- Real Windows/Linux native notifications and platform compilation remain unavailable locally; CI build coverage and
  later distribution-platform validation remain authoritative for those targets.
- MT Gate C also retains the plan's complete cockpit and release-target mobile regression journeys.

## Acceptance

- [x] Desktop derives only permission/question alerts from authenticated relay SSE and registers no push token.
- [x] Alert content is limited to the session title plus category-level copy; routing metadata is not rendered.
- [x] Alerts show only while hidden/unfocused and enabled; pending attention
  resumes when focus, preference, or auth gates reopen.
- [x] Per-session writes are serialized, resolved requests cannot reappear, and
  the last resolved request cancels the session alert.
- [x] Opens require the active account binding, focus the window, and replace
  the typed route stack after router readiness.
- [x] Logout and other account-ending transitions fence stale writes/opens and
  attempt cancel-all before credential removal.
- [x] The persisted desktop toggle clears delivered alerts when disabled and stays outside mobile push preferences.
- [x] Mobile payload/open behavior remains covered with nullable account binding and updated generated adapters/fakes.
- [x] Relevant analyzers, full suites, code generation, LSP diagnostics, clean
  macOS build, codesign verification, diff hygiene, and architecture review
  pass.
