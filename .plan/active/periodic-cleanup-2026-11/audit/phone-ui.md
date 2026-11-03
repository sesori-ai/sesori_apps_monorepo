# Phone UI (module_app_ui, app, design_catalog, module_prego) cleanup audit

## Summary
Overall the area is in good shape. module_app_ui and app `lib/` have zero production null assertions. Every GoRouter route is wired. Only a handful of widget classes are unreachable, and most of the debt is leftovers from features removed after the 2026-09-04 audit.

Top 3 opportunities:
1. Dead Prego components: `PregoRollingText`, `PregoAvatarInitials`, `PregoSkeletonList`/`ListTile` and `NonNullTextTheme` together hold about 615 lib lines and 15 of prego's 19 production `!`.
2. The phone app's no-op deep-link stack: about 230 lines plus the `app_links` dependency.
3. App/desktop platform adapters duplicated line for line: about 130 lib and about 250 test lines. The 2026-09-04 deferral reason is superseded by the 2026-10-08 `client/AGENTS.md` rule.

Also found:
- 17 unused ARB keys.
- About 4.7 MB of splash images bundled as Flutter assets that no Dart code loads.
- The phone app still carries about 9.8k lines of never-built macOS, Linux, Windows and web runners (decision needed).
- The "temporary" voice-engine picker shipped in public v1.11.0 (decision needed).

The known lead is resolved: the regression doc is right and the `session_tile.dart` comment is stale.

Estimated removable without decisions: about 1,300 hand-written lines plus about 150 generated l10n lines. With the decisions in UI-7 and UI-8, about 10k more lines of platform-runner files and about 500 lines of voice-picker code.

## Findings

### UI-1 Delete four dead Prego components (and the dead text theme)
- Category: leftover
- Evidence:
  - `client/module_prego/lib/components/prego_rolling_text.dart` (334 lines; `PregoRollingText` and `PregoRollingTextDirection`):
    - No reference anywhere in client, desktop, design_catalog or tests.
    - Its last caller, `PregoTotalBalance`, was deleted in 0fcc148dd3 (2026-08-22 codebase-cleanup step 35), but the component itself was left behind.
  - `client/module_prego/lib/components/icons/prego_avatar_initials.dart` (49 lines), exported at `module_prego.dart:15`:
    - Its only reference is its own test, `test/components/prego_avatar_initials_test.dart` (34 lines).
    - Its last use was removed in 3456978545 (2026-10-25, app-simplification step 10.a.ii).
  - `client/module_prego/lib/components/loaders/prego_skeleton.dart:261-343` (`PregoSkeletonListTile` and `PregoSkeletonList`, about 83 lines):
    - Used only in `test/components/prego_skeleton_test.dart`: the "PregoSkeletonList" group at lines 44-85, plus the `PregoShimmer` group, which uses it as its child at lines 88-208.
    - Its last production use was removed in faa2b7754b / 85b683f8f6 (2026-10-26).
    - `PregoShimmer`, `PregoSkeletonBar` and `PregoNavSubtitleSkeleton` are live.
  - `client/module_prego/lib/utils/non_null_text_theme.dart:6-150` (`NonNullTextTheme`, about 145 lines):
    - Never constructed.
    - Only `GuaranteedTextTheme` (lines 152-168) is used, by `theme/font/prego_text_theme.dart:151`.
    - The class carries 15 of prego's 19 production `!` behind a file-wide `// ignore_for_file: ..., no_slop_linter/avoid_bang_operator`.
  - `prego_anchor_menu.dart:755` `debugGlassEntryHeight` is `@visibleForTesting` and only tests use it (low value; drop only if the test can measure the entry another way).
- Proposal:
  - Delete `prego_rolling_text.dart`.
  - Delete `prego_avatar_initials.dart`, its test and its barrel export.
  - Delete `PregoSkeletonListTile` and `PregoSkeletonList` and their test group, and give the `PregoShimmer` tests a small inline child built from `PregoSkeletonBar` instead.
  - Delete `NonNullTextTheme` and the file-wide ignore. Keep `GuaranteedTextTheme`, ideally moving it into `prego_text_theme.dart` and deleting the file.
- Size:
  - About 615 lib lines removed.
  - About 75 test lines removed, plus about 15 test lines changed for the shimmer child.
  - 6 files touched.
  - Removes 15 null assertions and one lint suppression.
- Risk: low.
  - Nothing outside the package references these.
  - The only thing that could break is the shimmer tests, if their harness relies on `PregoSkeletonList`'s semantics wrapper.
  - No wire, DB or user-visible impact.
- Confidence: verified. I ran rg across `client/**` including design_catalog and desktop, and checked the git history for each removal.
- Decision needed: none

### UI-2 Remove the phone app's no-op deep-link stack
- Category: leftover
- Evidence:
  - `client/app/lib/core/routing/deep_link_service.dart` (63 lines) subscribes to `app_links` and only logs and ignores every URI ("Future non-OAuth deep links can be handled here").
  - OAuth moved off deep links in 663db6fd7b (2026-05-19, OAuth overhaul #161). Since then nothing routes from it.
  - The remaining pieces of the stack:
    - `app/lib/core/routing/deep_link_source.dart` (9 lines, `AppLinksDeepLinkSource`).
    - `module_core/lib/src/platform/deep_link_source.dart` (3 lines, interface).
    - `MockDeepLinkSource` at `module_core/lib/src/testing/test_helpers.dart:259`.
    - `app/test/core/routing/deep_link_service_test.dart` (128 lines).
    - The `initializeDeepLinks: () =&gt; getIt&lt;DeepLinkService&gt;().init()` wiring at `app/lib/main.dart:111`, plus the `bootstrapSesoriApp` parameter (`main.dart:136,149`) and its use in `app/test/main_startup_notification_wiring_test.dart`.
    - The `app_links` dependency in `app/pubspec.yaml`.
  - The constructor `DeepLinkService(final DeepLinkSource _deepLinkSource)` is also positional, which violates the named-parameter rule.
- Proposal:
  - Delete the service, both sources, the mock, the test, the bootstrap parameter and `app_links`.
  - Keep the native universal-link and scheme config (`applinks:sesori.com`, the `/link` intent filter, the `com.sesori.app` scheme). The OS still opens the app from such links without the plugin.
- Size: about 230 lines removed (about 85 lib, about 140 test); about 8 files, including 2 in module_core and one dependency.
- Risk: low.
  - A tapped sesori.com/link URL still opens the app; it already does nothing more.
  - Regenerating `injection.config.dart` is needed.
  - No wire or DB impact.
- Confidence: verified. Every caller was traced, and no `flutter_deeplinking_enabled` metadata exists, so GoRouter never received these links.
- Decision needed: none. The module_core half (interface and mock) overlaps the module_core auditor's scope, so coordinate.

### UI-3 Move the identical app/desktop platform adapters into module_app_ui (deferred item re-checked)
- Category: simplification
- Evidence:
  - These pairs are identical apart from class names and DI annotations:

    | app/lib/core/platform | desktop counterpart |
    |---|---|
    | `flutter_image_clipboard.dart` (15) + `pasteboard_client.dart` (12) | `desktop_image_clipboard.dart` + `desktop_pasteboard_client.dart` |
    | `flutter_image_sharer.dart` (29) + `share_plus_client.dart` (10) | `desktop_image_sharer.dart` + `desktop_share_client.dart` |
    | `desktop_file_image_saver.dart` (17) + `file_save_client.dart` (19) | same-named desktop files |
    | `path_provider_temporary_directory_provider.dart` (12) | identical file |
    | `flutter_master_key_store.dart` (12) | `desktop_master_key_store.dart` |

  - The tests are duplicated too:
    - `flutter_image_clipboard_test` / `desktop_image_clipboard_test` (40 each; 4-line diff).
    - `flutter_image_sharer_test` / `desktop_image_sharer_test` (38 each; 8-line diff).
    - `desktop_file_image_saver_test` (52 each; 0-line diff).
    - `persistence_capabilities_test` (115 / 114).
  - The 2026-09-04 audit deferred this because a module_app_ui relocation "would add file_selector, pasteboard, path_provider, share_plus deps and require a deliberate architecture decision".
  - That decision has since been made. `client/AGENTS.md` (596b188b31, #1921, 2026-10-08) now says an adapter both shells use unchanged may live once in `module_app_ui/lib/src/platform/`, exported as a composition entry point. `createFlutterVoiceCapture` is the precedent.
  - The added module_app_ui dependencies are already in both shells' pubspecs, so the app binaries do not grow.
  - The no-op-analytics part of the deferral is resolved on its own: desktop now has a real `DesktopAnalyticsClient`.
  - `go_router_route_dispatcher.dart` (app) and `desktop_route_dispatcher.dart` (76 lines each) are near-twins, but they differ in how they obtain the router and in the app's two navigator-key pops. Leave them.
- Proposal:
  - Add `module_app_ui/lib/src/platform/{image_clipboard,image_sharer,file_image_saver,temporary_directory,master_key_store}.dart` with plain classes.
  - Have each shell register them in its own DI module.
  - Delete one copy of each class and test.
- Size: about 130 lib and about 250 test lines removed; about 20 files touched across app, desktop and module_app_ui.
- Risk: low to medium.
  - DI wiring in two shells could break, which tests catch.
  - The master-key store is security-relevant, so keep its options byte-identical.
  - No wire or DB impact.
- Confidence: verified (file diffs and pubspecs checked).
- Decision needed: none under the current `client/AGENTS.md` rule. Note that this re-proposes a deferred item because its stated reason no longer holds.

### UI-4 Delete 17 unused l10n keys
- Category: leftover
- Evidence: in `client/module_app_ui/lib/src/l10n/app_en.arb`, these keys have no `.&lt;key&gt;` use in any `client/**/lib`:
  - Orphaned by the harness-settings redesign (69e276cc44, #1355, and fb6447b59c):
    - `harnessManagementDescription`, `harnessManagementInstall`, `harnessManagementInstallDescription`, `harnessManagementClearOverride`, `harnessManagementForceRestartTitle`
    - `harnessesRegisteredSection`, `harnessesDefaultBadge`, `harnessesSetupStatus`, `harnessesRuntimeVersion`, `harnessesRuntimeStatus`, `harnessesWorkStatus`
    - `harnessesCustomIdleTimeout`, `harnessesUsesDefaultIdleTimeout`, `harnessesNoIdleTimeoutDescription`
  - `sessionDetailHideActions`, orphaned in d921e48b04 (#1477).
  - `noProjects` and `addProjectPrompt`, used only as fake text in `module_app_ui/test/features/project_list/add_project_dialog_test.dart:113,115`.
- Proposal:
  - Remove the 17 entries and their `@` metadata.
  - Swap the two test usages for literal strings.
  - Run `flutter gen-l10n`.
- Size: about 60 ARB lines and about 150 generated lines removed; 1 ARB file, 1 test file and the regenerated `app_localizations*.dart`.
- Risk: low. A missed use fails compilation.
- Confidence: verified (searched every key across client lib and test).
- Decision needed: none

### UI-5 Stop bundling the splash images as Flutter assets; delete the unused ones
- Category: leftover
- Evidence:
  - `client/app/pubspec.yaml:127-128` lists `assets/images/bkg_png/` and `assets/images/bkg_webp/` under `flutter: assets:`, but no Dart code in app loads them.
  - `SesoriBackgroundWidget` uses module_app_ui's own `bkg_webp` with `package: "sesori_app_ui"`.
  - Of the six files, only `bkg_png/dark_mode_portrait_splash.png` and `bkg_png/light_mode_portrait_splash.png` are referenced, by the `flutter_native_splash` config (pubspec lines 195-196 and 224-225). That generator reads them from disk and does not need them bundled.
  - These are unreferenced anywhere:
    - `bkg_png/splash.png` (783 KB)
    - `bkg_png/dark_mode_landscape_splash.png` (720 KB)
    - `bkg_png/light_mode_landscape_splash.png` (869 KB)
    - `bkg_webp/splash.png` (862 KB, a PNG left behind when d4a995afaa moved the webp backgrounds into module_app_ui)
- Proposal:
  - Drop both asset entries.
  - Delete the 4 unreferenced files.
  - Keep the two portrait PNGs on disk for `flutter_native_splash`.
- Size: 2 pubspec lines; 4 binary files (about 3.2 MB) deleted from the repo; about 4.7 MB less in the phone bundle.
- Risk: low. If something loaded these by a dynamic string, a background would go missing; none was found.
- Confidence: likely. Static references are verified. Still unverified: that a `dart run flutter_native_splash:create` run after the change produces identical iOS LaunchImage and web output.
- Decision needed: none

### UI-6 Fix the stale session-row contract in `session_tile.dart` (lead resolved)
- Category: leftover
- Evidence:
  - The lead is resolved in favour of `docs/regression/session-archiving-and-deletion.md:27-33`.
  - `session_tile.dart:39-41` says a full swipe commits the archive "which is confirmed by a sheet, so the quick path never finalizes anything on its own". That is false.
  - The swipe pill and the full swipe both go through `SessionListActionDispatcher.handleSessionArchive` → `_archive` (`session_list_action_dispatcher.dart:140-165`). It confirms only a running session (`_confirmArchiveRunning`), then archives at once behind the 5-second Undo window, exactly as the doc says.
  - The comment predates bc85769c57 ([desktop-ui-polish] Archive with Undo, step 12/17), which changed the behaviour without updating it.
  - Same file:
    - `session_tile.dart:10-17`: a long doc comment about a "long-press actions builder" sits on `typedef SessionOpenedCallback`. That typedef is unused anywhere (added in c75f48d5c8), and the doc belongs to the actions-builder parameter further down.
    - `session_tile.dart:67-69`: `required final VoidCallback? onTap` says "Desktop leaves this null until the transcript slice lands". But the only production caller (`all_sessions_list.dart:898`) always passes a closure, because `onSessionTap` is required in all four shells' call sites.
    - The null branches at lines 140 and 147 (`button: onTap != null`, basic mouse cursor) are therefore test-only. They are used by `session_tile_states_test.dart:45` (`canOpen` variant) and `app/test/playbook/thread_state_motion_playbook.dart:214`.
- Proposal:
  - Rewrite lines 39-41 to say archive happens at once behind Undo and only a running session is confirmed.
  - Delete the dead typedef and its misplaced doc.
  - Make `onTap` non-nullable, drop the two null branches, give the playbook a no-op closure, and drop the `canOpen: false` test variant.
- Size: about 20 lines removed or changed; 4 files.
- Risk: low. No user-visible change.
- Confidence: verified.
- Decision needed: none

### UI-7 The phone app still carries desktop and web targets that nothing builds
- Category: leftover
- Evidence:
  - `client/app/{macos,linux,windows,web}` hold 62 files and about 9.8k lines of runner and project files.
  - CI builds only iOS (TestFlight), Android (internal), and the separate `client/desktop` shell. The desktop product is `client/desktop`.
  - Code kept alive only for those targets:
    - `app/lib/core/di/register_module.dart:45-49`: a web/macOS/Linux/Windows branch to `DesktopFileImageSaver`, which in turn keeps `file_selector` and the app copy of the file-save adapter in UI-3.
    - `main.dart:313-332`: the `kIsWeb` and desktop branches of `_supportsFirebase` and `_supportsSingular`.
    - `flutter_oauth_device_descriptor_provider.dart:34-50,69-71`.
    - `app_lifecycle_observer.dart:41-51` (`_isDesktop`).
    - `firebase_push_messaging_source.dart:51,58` (`Platform.isMacOS`).
    - `circular_reveal_page.dart:86-87`.
    - `session_detail_screen.dart:123`.
    - The web, macOS and Windows entries in `firebase_options.dart`.
    - The `web` flutter_native_splash config.
    - Possibly `universal_platform`.
  - The `NoOpAnalyticsClient` doc (`no_op_analytics_client.dart:5-6`) lists web, Linux and Windows as its reason to exist. It would still serve Android profile builds.
- Proposal: delete the four platform directories and the desktop/web branches, and keep the phone app iOS/Android-only.
- Size: about 9.8k runner lines and about 80 Dart lines removed; about 70 files.
- Risk: medium. Anyone running `flutter run -d macos` or `-d chrome` on the phone app for quick UI work loses that. The design catalog is the web surface for components. No wire, DB or user impact.
- Confidence: verified (CI workflows checked; the directories are never built).
- Decision needed: should the phone app stay buildable on macOS, Linux, Windows and web for local development, or become iOS/Android-only?

### UI-8 "Temporary" voice-engine picker shipped publicly
- Category: leftover
- Evidence:
  - `module_app_ui/lib/src/features/settings/voice_engine_settings_view.dart:10-11` says: "Temporary, for comparing the engines. Not gated to internal builds, so decide before the next public release."
  - It is present in the public tag v1.11.0, added in 9bc12fe09a and slimmed in d5a438c3a6 (2026-10-31).
  - The surface:
    - The view (96 lines) and the app screen (18).
    - The `settingsVoiceEngine` route.
    - `VoiceEngineCubit`, the `VoiceEngine` preference and its storage.
    - 6 ARB keys and their tests.
    - About 500 lines in total.
  - Only Device and Remote remain as engines. On-device dictation already falls back to the server, and Remote Config `voice_on_device_enabled` is the kill switch.
- Proposal:
  - Option A: remove the picker, the route, the cubit and the stored preference, and keep the automatic device-then-server fallback.
  - Option B: gate it to internal builds.
  - Option C: make it a permanent setting and delete the "temporary" comment.
- Size: about 500 lines (A), about 20 (B), about 5 (C).
- Risk: low to medium. With A, users who picked Remote lose that choice, though the fallback still covers them. The stored preference becomes a dead key, which is harmless. No wire impact.
- Confidence: verified (tag contents and history).
- Decision needed: remove, gate, or make permanent? The comment set a "before the next public release" deadline, and that release (v1.11.0) has already shipped.

### UI-9 Production APIs only tests use, and production paths named `...ForTesting`
- Category: leftover
- Evidence:
  - Misleading names: the live push-notification path calls helpers named `notificationOpenFromMessageForTesting` and `pushNotificationMessageFromRemoteMessageForTesting`. These are at `app/lib/core/platform/firebase_push_messaging_source.dart:98,136,167,179,184`, and the same pattern appears in `flutter_local_notification_client.dart:98-102`.
  - Test-only production members:
    - `app/lib/core/routing/app_router.dart:276` `buildAppRoutesForTesting`.
    - `module_app_ui/lib/src/platform/go_router_route_source.dart:116` `matchRouteForTesting`.
    - `session_diffs_view.dart:66-67` `recomputeCount`.
    - `app/lib/core/widgets/connection_graphic.dart:25` `connectionOn`.
    - `module_prego/lib/theme/prego_design_system.dart:50` `widths` (10 test refs).
    - `prego_ellipsis_text.dart:142` `shownText`.
  - Unused outright:
    - `module_app_ui/lib/src/extensions/build_context_x.dart:12` `isLightMode` (unused since added in b51f12cef1).
    - `module_app_ui/lib/src/widgets/sesori_logo.dart:28` `frameHeight`.
- Proposal:
  - Rename the two notification helpers to their production meaning (for example `notificationOpenFromMessage`).
  - Delete `isLightMode` and `frameHeight`.
  - Leave the small `@visibleForTesting` seams unless a test can use public behaviour instead. Most are 1-3 lines and are not worth churn on their own.
- Size: about 15 lines removed; about 10 lines renamed across 4 files.
- Risk: low.
- Confidence: verified (rg for each symbol across client).
- Decision needed: none

### UI-10 Unused dependencies and build config
- Category: leftover
- Evidence:
  - `client/app` declares `freezed_annotation` (`pubspec.yaml:38`) and `freezed` (`:91`), and `app/build.yaml:13-17` configures the freezed builder. But app has no `@freezed` class and no `.freezed.dart` file in lib or test.
  - `client/app` has `flutter_svg` (`pubspec.yaml:76`) as a regular dependency, but only `app/test/helpers/test_helpers.dart:5` imports it.
  - `client/module_app_ui` has the dev dependency `cupertino_ui` (`pubspec.yaml:41`) with no import in lib or test.
- Proposal:
  - Drop `freezed`, `freezed_annotation` and the `freezed:` block from app.
  - Move `flutter_svg` to app dev_dependencies.
  - Drop `cupertino_ui` from module_app_ui dev_dependencies.
- Size: about 9 lines; 3 files.
- Risk: low. `pub get` and analyze confirm it.
- Confidence: verified (imports grepped; other deps.tsv rows such as `injectable_generator`, `build_runner` and `flutter_native_splash` are real build tools).
- Decision needed: none

### UI-11 Remaining production null assertions in module_prego
- Category: rule-violation
- Evidence:
  - After UI-1, prego `lib/` keeps 4:
    - `theme/prego_theme.dart:96` `return design!;` after an assert in the `PregoDesignExtension.prego` getter.
    - `theme/font/prego_text_theme.dart:237` `TextStyle.lerp(a, b, t)!`.
    - `utils/lerp_utils.dart:9,17` (with ignores; called by the generated `prego_colors.g.dart`).
  - module_app_ui and app `lib/` have 0.
  - Tests have 131 (module_app_ui; 60 in `session_detail_message_list_test.dart`), 65 (app) and 39 (prego).
- Proposal:
  - For `prego_theme.dart:96`, use an explicit null check that throws a `StateError`.
  - For `prego_text_theme.dart:237`, use `?? b`.
  - Leave `lerp_utils`, since generated code depends on its signature.
  - Test bangs are not worth a sweep. Fix them when a file is touched.
- Size: about 6 lines; 2 files.
- Risk: low.
- Confidence: verified.
- Decision needed: none

### UI-12 Stale comments
- Category: leftover
- Evidence:
  - `app/lib/core/platform/firebase/no_op_analytics_client.dart:6` says "Mirrors `client/desktop`'s no-op of the same name". Desktop has no such class; it has `DesktopAnalyticsClient`, which is a real stream sink.
  - `module_prego/lib/components/prego_tappable.dart:684` has an old `TODO(V2)` about pop-out dimming.
- Proposal: drop the mirror sentence. Delete the TODO, or turn it into an issue if it is still wanted.
- Size: about 3 lines.
- Risk: none.
- Confidence: verified.
- Decision needed: none

## Checked and kept
- unref.tsv overrides such as `isScrolling`, `buildViewport`, `createElement` and other RenderObject/ScrollActivity/Element overrides are framework-called, so they are false positives.
- unref.tsv `datePattern` (`build_context_x.dart:112`), `commandInfo` (`prompt_input.dart:1570`) and `regexPath` (`go_router_route_source.dart:130`) are local or pattern variables, not members, so they are false positives.
- `FileReferenceCodeSyntax` is live via `sessionMarkdownInlineSyntaxes` (`text_part_widget.dart:38`, `user_message_card.dart:151`).
- `design_catalog/lib/src/catalog_manifest.dart` `buildCatalogManifest` is used by `tool/generate_manifest.dart` and CI `--check` to produce `web/catalog_manifest.json`.
- All 17 `AppRouteDef` routes are wired in the app router (no dead routes). `settingsVoiceEngine` depends on UI-8.
- Every other Prego widget has 2 or more callers outside the package. No app_ui widget duplicating a Prego component was found.
- The `feedback_rating_*.svg` assets are loaded dynamically (`feedback_rating_motion.dart:228`). Prego `antigravity.svg` is a dynamic harness logo. Desktop tray assets are out of scope.
- The `prompt_input.dart:28,34,39` dart_style 3.1.12 empty-enum-constructor workaround was re-added 2026-10-30 and is still needed.
- The `session_abort_scope_dialog.dart:101` COMPATIBILITY marker (v1.9.1) is kept: public bridges v1.8.4–v1.9.x send that refusal, so it is a public wire.
- The `app/lib/core/di/injection.dart:37` COMPATIBILITY marker (legacy native storage import) is kept; its retiring condition is about the public upgrade floor, which is the compat and module_core auditors' call.
- The `main.dart:380` `MaterialUiCompatibilityBridge`/`CupertinoUiCompatibilityBridge` is still needed while legacy SDK theme and localization types are in use.
- The OAuth device-descriptor providers (app vs desktop) are kept because they differ meaningfully. The no-op feedback-prompt and founder-call config sources are kept because they differ (`enabled: null` under the firebase-disabled env vs `enabled: false`).
- The app vs desktop route dispatchers are kept: they are near-twins but differ in router injection and navigator-key pops (see UI-3).
- `prego_shadows.dart:100,111` `xxl`/`xxxl` are unused tokens in a complete token scale, so they are kept.
- The native universal-link and scheme config is kept even after UI-2 (the OS still opens the app).
- No structural split is proposed for large files (`prompt_input.dart` 3045, `session_detail_message_list.dart` 1701, `session_detail_body.dart` 1470, `new_session_view.dart` 1430, `add_project_dialog.dart` 1008, among others). I did not verify a concrete risk reduction, and they are feel-critical code where churn is costly.
- Send handoff, the 35 pt bubble snap, the 44 px chip-reflow jump, refresh drift and legacy Load models were not reopened, per the brief.
