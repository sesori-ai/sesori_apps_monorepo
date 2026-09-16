# Step 5 — Manual macOS Updates Through Safe Application Quit

Status: **implemented — focused verification and architecture review passed**.
PR ordinal **7/14**; follows merged #1503 (accepted
`49694775e5d364a1316b767b66642531bf002e3a`, squash
`d1813409e3c0a8e053c3a28068d574e24fb70730`).

## Decision and evidence

D6 prioritizes a small integration and explicitly permits manual updates. Current
`IoDesktopApplicationTerminator.terminate` calls `dart:io.exit`, while the existing
`BridgeControlCubit.quit` stops the helper before disposing native surfaces and
terminating. Preserve that single tested authority.

The Sparkle 2.10.0 public API probe establishes compilation only. Its
[`SPUUpdaterDelegate` contract](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SPUUpdaterDelegate.h)
says the install-on-quit handler installs and relaunches, and postponing relaunch is
not invoked for every termination path. Automatic adoption would therefore require
native termination integration, callback routing, an update-state subscription,
prepared-install policy and explicit-restart coordination across native/Dart owners.
Those are not proven unsafe or impossible; they exceed what a manual update action
needs. Do not build that machinery solely to retain optional automation.

Use the already approved manual path for macOS, as for Windows. Sparkle is not
embedded, no updater signing key/feed is required, and ordinary Quit remains
unchanged. This is a product simplification, not a passing automated-update probe.
Native N→N+1 manual replacement and shared-state preservation remain release gates.
No local app, running bridge or installed package may be disturbed.

## Implementation plan

1. Add an immutable desktop-core foundation model for the update destination:
   manual download (required URI), package-manager guidance, or development build.
   The shell resolver uses the closed stable/internal channel enum and existing
   bundle identity to select the official channel/OS/CPU anchor. No parsing of backend data and no wire or
   persisted contract. Missing compiled bundle identity means a development build,
   not a guessed download architecture.
2. Use a desktop-owned repository Markdown download index with stable/internal
   macOS and Windows CPU sections. Every unshipped section explicitly says no
   public download is available. No placeholder artifact URLs or latest-release
   inference. Step 6 replaces only qualified Mac sections with verified links;
   Windows stays gated until its later distribution steps. Linux directs users to
   package-manager documentation once repositories ship, never to a self-updater.
3. Add a thin shell `DesktopUpdateSection` to the existing Settings composition.
   Render a `View downloads` action through the existing external-link seam,
   explain that users must Quit (not close to tray), verify the approved publisher,
   replace the app and reopen manually. The page is a download index, not an
   assertion that an update or release exists. Development and package-manager
   variants expose honest guidance without a dead action.
4. Supply the immutable target from shell build configuration: reuse compiled
   `DesktopBundleIdentity`; a desktop release channel compile define defaults to
   stable. Teach staging a closed `--channel` option so future internal/stable
   publishers do not guess from shared semantic versions. This metadata need not
   change the GUI/helper identity or runtime wire schema.
5. Update regression docs and synchronize plan defaults/steps to the selected
   manual path. Do not add unused AppUpdater/API/repository/service/DI layers,
   native framework dependencies, timers, mutable update state, install/restart
   hooks or terminal-action variants. No new analytics event: opening a static
   download index does not justify distribution-specific tracking.

## Concrete boundaries and data flow

- B-Client only. Add
  `client/module_desktop_core/lib/src/foundation/models/desktop_update_destination.dart`:
  plain immutable `sealed class const DesktopUpdateDestination`, with
  `DesktopManualDownload(required Uri uri)`, `DesktopPackageManagerUpdate()` and
  `DesktopDevelopmentUpdate()`. Add `DesktopReleaseChannel { stable, internal }`
  and its `defineName = "SESORI_DESKTOP_RELEASE_CHANNEL"`. These are nonserialized
  values, not new Freezed/JSON storage or transport models. Export from
  `client/module_desktop_core/lib/sesori_desktop_core.dart`.
- Destination types carry values only. Package/link selection belongs to the shell:
  null identity selects development, Linux selects package-manager guidance, and
  macOS/Windows select a manual-download URI. No runtime architecture guess.
- Add `client/desktop/lib/core/desktop_update_configuration.dart` with
  `resolveDesktopUpdateDestination({required String? encodedIdentity,
  required String encodedChannel})`. This shell/build boundary decodes present
  identity and parses the channel enum; malformed present values throw rather than
  select any link. No error recovery or silent stable fallback. Missing compile
  identity becomes null using `bool.hasEnvironment`, not an empty-string sentinel.
  `_DesktopBridgeSettingsPage` in `desktop_settings_modal.dart` supplies compile-time
  values here before composing UI.
- Canonical index: `docs/desktop/downloads.md`, public URI
  `https://github.com/sesori-ai/sesori_apps_monorepo/blob/main/docs/desktop/downloads.md`.
  The shell configuration function owns that constant and constructs fragments
  `<channel>-<os>-<architecture>` using closed enum names, for example
  `stable-macos-arm64` or `internal-windows-x64`. Each of the eight matching Markdown
  headings explicitly states no public download is available until that row ships.
  No artifacts are linked yet, private artifacts are never linked, and neither
  `latest` nor shared version strings select a channel. Include a Linux section
  explaining that signed repositories are not published yet. A `View downloads`
  action opens this truthful index; it does not claim an available update.
- In `client/desktop/tool/stage_desktop_bundle.dart`, a named
  `parseDesktopReleaseChannel({required String value})` helper parses the closed enum;
  ArgParser `--channel` accepts `stable|internal` and defaults to `stable`.
  `desktopBundleDefines({required DesktopBundleIdentity identity,
  required DesktopReleaseChannel channel})` emits the existing identity line and
  named channel line into the existing `dart-defines.env`. Invalid values fail
  before building. Do not change `desktop-bundle.json`, identity schema or helper
  validation. No global mutable configuration.
- `client/desktop/lib/features/settings/desktop_update_section.dart` is const,
  accepts `required DesktopUpdateDestination destination`, and only renders
  `SettingsSection`/`PregoGroupedRows`. Manual rows call the existing
  `openDesktopExternalLink` through `core/external_link.dart` with external-app mode;
  development/Linux rows have no action. The manual subtitle explains Quit before
  replacement, manual reopen and published-release availability; index instructions
  name publisher verification. No GetIt, Cubit, service or Quit invocation here.
- `client/desktop/lib/features/settings/desktop_settings_modal.dart` composes the
  update section in its existing Bridge tab Column with Prego spacing. Attention
  remains in Notifications. The removed standalone Settings screen stays removed;
  no `module_app_ui` API changes are needed.
- Flow: staging options → dotenv defines → shell typed decoding and package/link selection → immutable widget input → existing external-link seam.
  `BridgeControlCubit.quit` and `IoDesktopApplicationTerminator` are unchanged.
- Tests: `client/desktop/test/core/desktop_update_configuration_test.dart`
  covers all eight manual destinations and Linux/development; shell configuration
  and widget tests in `client/desktop/test/features/settings/desktop_settings_screens_test.dart`
  cover valid/invalid defines, truthful guidance, and the injected existing
  `UrlLauncher` callback. Extend `client/desktop/test/tool/stage_desktop_bundle_test.dart`
  for stable/default, internal, invalid channel and exact define output. Add
  `docs/regression/desktop-distribution.md`, update its index and packaging guidance.

First plan review `6ea30f7a-e55d-469f-a239-1a2cbde5be49` rejected the pre-review gate
for unnamed boundaries/data flow, not the approved manual choice. The concrete
specification above addresses all six omissions; clarified review `be586eeb-b779-448e-9f1e-83e9ec275752` approved the plan.

## Budget and verification

Target under 900 authored lines (including removal of superseded Sparkle plan detail), zero generated; zero new mutable fields. Tests:
closed channel and native CPU destination selection, development/Linux guidance,
Settings action and callback, staging option/define propagation. Run relevant
Flutter tests and strict analyzers for the touched modules. Existing safe Quit
behavior is unchanged; run its focused tests if composition touches its contract.
Architecture plan review precedes production edits, followed by a scoped
implementation review. No signing, publishing, private-key generation or billable
infrastructure change in this step.

Manual signed N→N+1 install/relaunch and shared-data preservation remain a native
CI/host qualification task, not evidence supplied by a link widget. Real accounts,
minimum OS, interactive permissions and public-release prerequisites stay pending.

## Implementation evidence

Measured commit `69789cd200ab59f56c6676ed75d4b4eff4ed2741`, tree
`e1ab30313629be4a054edc1dff8747dbf1c7735b`. Each command below ran from the named
cwd beneath `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope`,
using the pinned Flutter-owned SDK. No local GUI/helper was launched or stopped.

| Cwd | Command | Result |
|---|---|---|
| `client/module_desktop_core` | `dart test test/foundation/desktop_update_destination_test.dart --reporter json` | Exit 0; 13 non-hidden cases passed |
| `client/desktop` | `flutter test test/features/settings/desktop_settings_screens_test.dart test/tool/stage_desktop_bundle_test.dart --reporter json` | Exit 0; 18 non-hidden cases passed |
| `client/module_desktop_core` | `dart analyze --fatal-infos` | Exit 0; No issues found! |
| `client/desktop` | `dart analyze --fatal-infos` | Exit 0; No issues found! |

All eight channel/OS/CPU fragments match index headings, each explicitly unshipped.
Local receipt: `build/desktop-manual-updates-evidence/verification-69789cd.json`;
individual logs are beside it. These tests establish destination selection, staging
metadata and UI dispatch, not native replacement or public download availability.

Architecture implementation review `dafc020c-8950-4761-b46f-806bef34448b` approved
all 17 paths at exact `69789cd` versus parent `d1813409e3c0a8e053c3a28068d574e24fb70730`,
B-Client only, no findings. Output: `reviews/desktop-distribution-step-05-implementation.md`.
Fixed scope from `git diff --numstat d1813409e3c0a8e053c3a28068d574e24fb70730 69789cd200ab59f56c6676ed75d4b4eff4ed2741`:
573 additions + 172 deletions = **745 authored lines**, zero generated, including
this step file at that revision and removal of obsolete Sparkle design details.
Later evidence text is not retroactively included in that count.


## Incoming Settings-modal integration

Normal merge `56e35454fe7ea1451ef0453d67f76937210bd49d` incorporates main
`77c781faa648bcbe971aca1813abe1a2ba96ccc6`. The removed Settings screen was not
restored; the update section now lives in the modal Bridge tab. Incoming attention,
account and harness tabs remain unchanged. Initial test integration failed because
its old wrapper no longer existed, then exposed a duplicate launcher registration
and the need to settle scrolls before tapping below the new section. Those fixture
issues were corrected without changing production behavior or weakening assertions.

Measured uncommitted test corrections were retained unchanged in
`c35fb1ddffbf57401ab09849edcd2eca15dace15`, tree
`b40589fd0b9c35becd8c45f96d3c88db07828010`. From `client/desktop`,
`flutter test test/features/settings/desktop_settings_screens_test.dart --reporter expanded`
passed 18 cases, and `dart analyze --fatal-infos` reported No issues found (both exit 0).
Logs: `build/desktop-manual-updates-evidence/merged-settings-tests-green.log` and
`merged-desktop-analyze-green.log`. This is separate from the original 18-case combined
Settings/staging result above; unchanged destination/staging tests were not rerun.
The original architecture review remains scoped to its recorded revision.


## Shell ownership review correction

PR feedback correctly identified package/link strategy as shell-owned. Commit
`7a4b9cb1a67f6f9cbd8adbd6605a21564a8dc7bd`, tree
`188853817ffcf3e38ae74b7d8eeae05f1d839852`, moves policy and its tests into the
shell, retaining only immutable destination variants/channel metadata in desktop core.
Normal merge `8459c33eb` preserves incoming local-permission Settings behavior.

From `client/desktop`, `flutter test test/core/desktop_update_configuration_test.dart
test/features/settings/desktop_settings_screens_test.dart test/tool/stage_desktop_bundle_test.dart
--reporter expanded` passed 44 cases on the uncommitted correction retained in
`7a4b9cb` except for a subsequent import-order-only fix. Core `dart analyze --fatal-infos`
passed on that checkpoint; desktop strict analysis passed at exact `7a4b9cb` after
the import sort. Logs in `build/desktop-manual-updates-evidence/`:
`shell-policy-tests.log`, `core-values-analyze.log`, `shell-policy-analyze-final.log`.
Earlier review results remain historical. Second scoped implementation review
`5d1129d4-0dc8-4f61-982b-7581ea9fc8a5` approved exact `7a4b9cb` against merge base
`69d6803daba48c9bf3a8a9e48e00c2d862f7aca0`, B-Client only, no findings.
Output: `reviews/desktop-distribution-step-05-implementation-followup.md`.
