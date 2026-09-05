# Managed Runtime Auto-Upgrade

## Status

- **Plan slug:** `managed-runtime-auto-upgrade`
- **Status:** Proposed
- **Architecture review:** rejected 2026-09-05 on one finding (a bare
  `bool Function()` threaded from `PluginRuntime` through
  `BridgePluginDescriptor.installRuntime` into the runtime package). Applied
  directly: the live in-use fact now crosses the contract as the typed
  read-side `RuntimeInUseSignal`, mirroring `StartAbortSignal`. Four
  non-blocking suggestions were also applied: the managed-descriptor count is
  seven, the upgrade decision has one owner (the descriptor), the install
  completion mode is an enum, and both install entry points share one
  admission helper. Everything else was found compliant as written.
- **Plan date:** 2026-09-05
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `4e1da1828f`
- **Delivery:** five numbered PRs; Step 1 raises this plan before production
  work

This document and `TRACKER.md` are the authority for implementation. The code
and released product behavior remain authoritative where this document becomes
stale.

## Goal

When a bridge release raises a harness's pinned managed runtime target, users
who already have a Sesori-managed runtime get the new version automatically on
bridge startup, in the background, without a restart and without pressing
Install:

1. a managed runtime **at or above the minimum** but older than the target
   stays selectable and startable while the target downloads; superseded
   directories are removed only after the replacement is installed and
   verified, and never while a running generation uses them;
2. a managed runtime **strictly below the minimum** is never selected, its
   directory is removed before the download starts, and the harness stays
   unavailable until the target is ready;
3. the harness becomes available as soon as the install verifies, through the
   existing setup re-inspection path.

This is shared behavior for every harness with a managed runtime. It never
touches PATH installs, explicit `--<plugin>-bin` binaries, credentials,
provider configuration, session history, or a running session's executable.

## Current Behavior (verified)

- `ManagedRuntimeProvisionService.provision`
  (`bridge/sesori_plugin_runtime/lib/src/provisioning/managed_runtime_provision_service.dart:38-45`)
  resolves already-installed runtimes only and asks
  `ManagedRuntimeSelectionService.select` for
  `ManagedRuntimeVersionPolicy.exact`. Selection probes exactly one managed
  path, `RuntimeManifest.managedBinaryPath` (the pinned version directory), so
  an older managed version in a sibling directory is invisible. Every
  descriptor's `inspectSetup` uses the same `exact` policy, except Cursor which
  uses `minimum` against the same single pinned path.
- Consequently, bumping `bundledVersion` makes setup report the harness as
  runtime-missing until the user presses Install, even when the existing
  managed runtime satisfies `minPathVersion`. The descriptors for OpenCode,
  Codex, and Cursor already detect this with
  `ManagedRuntimeInventory.hasSupersededVersion` purely to word the hint.
- Downloads happen only through the explicit Install command:
  `PluginLifecycleService.command` occupies `_activePluginCommands[pluginId]`,
  `_executeInstall` streams `PluginRuntime.installRuntime` →
  `descriptor.installRuntime` → `ManagedRuntimeInstallService.install`, and on
  `ProvisionReady` calls `_enable` (persist enabled, re-inspect, start when
  ready). A duplicate Install joins the active command; any other command for
  the same plugin conflicts.
- `ManagedRuntimeInstallService.install` always sweeps every managed version
  directory other than the pinned one before its terminal event
  (`managed_runtime_install_service.dart:103,158`), which is only safe today
  because a setup-blocked plugin cannot start during an install.
  `RuntimeInstallService` writes the download and staging files under the
  runtime's managed directory and the payload into the pinned version
  directory, so an older version directory is never touched by placement.
- Bridge startup (`bridge/app/lib/src/runtime/bridge_runtime_runner.dart`)
  inspects setup for eligible plugins, calls
  `PluginLifecycleService.initialize`, then `generationFactory
  .enforceBridgeOwnership()` (single-live-bridge enforcement: other bridges
  are replaced or this one exits), then eager starts. Plugin state lives under
  `<installRoot>/plugins/<id>/` or the legacy shared
  `<cacheDirectory>/runtime`, one tree per machine install, so ownership
  across bridge processes is exactly what single-live-bridge enforcement
  already resolves.
- `PluginRuntime.beginShutdown` aborts in-flight installs through their
  `StartAbortController`; `_executeInstall` maps that to an "interrupted"
  terminal progress event. Dispose does not wait for installs.

## Design Decisions

- **Minimum gates managed runtimes too.** A managed version `>= minPathVersion`
  is supported; `< minPathVersion` is obsolete. Equal to minimum is supported.
  `ManagedRuntimeVersionPolicy` is deleted: with an ordered candidate list the
  exact/minimum distinction has no remaining consumer.
- **Upgrade only what Sesori already manages.** The startup trigger is "a
  Sesori-managed version directory other than the pinned target exists, no
  explicit binary is configured, and managed install is supported on this
  platform". A machine with no managed runtime keeps today's explicit Install;
  a bridge never downloads seven runtimes on first start. A user who runs a PATH
  install and also has a stale managed directory gets one background download
  per target bump and the stale directory swept; accepted as low-damage
  bandwidth rather than adding a second probe pass at startup.
- **The auto-upgrade is the existing install command.** It occupies
  `_activePluginCommands[pluginId]` with an `install` request so an overlapping
  explicit Install joins it and lifecycle commands conflict exactly as they do
  for a manual install. No parallel updater, queue, or registry.
- **Auto-upgrade re-inspects but never starts.** A manual Install implies
  enable and start; a startup upgrade only re-inspects so a below-minimum
  harness flips from runtime-missing to ready and becomes routable without
  spawning a process nobody asked for.
- **No hot swap.** A generation started on the older supported runtime keeps
  it until it stops; the next generation resolves the pinned version. Cleanup
  honours that through one typed live signal (`RuntimeInUseSignal`) read at
  sweep time, not through path bookkeeping, process scans, or a stop hook.
- **Obsolete directories go first, superseded ones last.** Below-minimum
  directories are unselectable, so they are deleted before the download
  starts. Supported superseded directories are swept only after the pinned
  runtime is installed, probed, and the plugin has no live generation; when it
  does, the sweep is skipped and the next startup trigger (which re-runs the
  install path and short-circuits on the healthy pinned install) reclaims it.
- **Existing safety stays.** Checksum verification, sentinel-last placement,
  atomic rename, post-place probe, and abort observation in
  `RuntimeInstallService` and `ManagedRuntimeInstallService` are unchanged.

## Design

### 1. Selection: supported managed versions (`sesori_plugin_runtime`)

- `ManagedRuntimeInventory` gains
  `List<RuntimeVersion> installedVersions({required String stateDirectory})`:
  version directory names under `<stateDirectory>/<runtimeId>/` that parse with
  `manifest.parseInstalledVersion`, sorted descending. `hasSupersededVersion`
  becomes a one-line derivation. Unparseable names are ignored; read errors log
  and yield an empty list, as today.
- `RuntimeManifest.parseInstalledVersion` is new, defaulting to `parseVersion`.
  `parseVersion` parses a token of `--version` output, and OMP's requires an
  `omp/` prefix so an unrelated semver token in that output is not mistaken for
  the runtime version. Directory names carry the bare version, so OMP overrides
  the new method. Without the split, OMP silently never finds a superseded
  managed version — a latent bug this plan would otherwise make load-bearing.
- `RuntimeManifest.managedBinaryPath` takes a `version` instead of assuming the
  pinned one, so ordered candidate probing reuses it rather than repeating the
  `<stateDirectory>/<runtimeId>/<version>/<binaryFileName>` layout.
- `ManagedRuntimeSelectionService` takes the inventory and drops
  `managedVersionPolicy`. Managed candidates are probed in order: the pinned
  version directory, then every other installed version `>= minPathVersion`
  descending. The first probe reporting `>= minPathVersion` wins as
  `ManagedRuntimeManagedSelected`. `managedRejection` on
  `ManagedRuntimeAutomaticNotSelected` keeps the pinned probe's rejection
  unless another candidate produced a non-missing rejection, mirroring the
  fallback-candidate rule already in the class.
- `ManagedRuntimeVersionPolicy` is removed; the seven descriptor call sites
  (`inspectSetup` in DeepSeek, Copilot, OMP, Cursor, OpenCode, Codex, Pi and
  the provision service) drop the argument and pass the inventory. Cursor's
  `minimum` and everyone else's `exact` become the single behaviour.
- `ManagedRuntimeProvisionService` renders the notice with the selected
  managed version instead of `bundledVersion` (today's message is wrong for
  the case this plan introduces). `RuntimeManifest`'s doc comment states that
  `minPathVersion` gates managed runtimes as well.

### 2. Install ordering and ownership-aware sweep (`sesori_plugin_runtime`)

- `ManagedRuntimeCleaner.sweep` takes
  `required bool Function({required String versionName}) keep` instead of a
  single `keepVersion`; the existing behaviour is `keep: (name) => name ==
  pinned`.
- `sesori_plugin_interface` gains `RuntimeInUseSignal`, a read-only
  abstraction beside `StartAbortSignal` with a single `bool get isInUse`. Its
  only implementation is private to `bridge/app/lib/src/runtime/plugin_runtime.dart`
  and reads the slot on each access
  (`slot.plugin != null || slot.startFuture != null`; a starting generation
  has already resolved its path). This is the interface's existing shape for
  bridge-owned live state crossing into plugin code.
- `ManagedRuntimeInstallService.install` gains
  `required RuntimeInUseSignal runtimeInUse` and:
  1. before asset resolution, sweeps directories whose parsed version is
     `< minPathVersion` (unparseable names are kept here);
  2. after a verified install, and on the already-installed short-circuit,
     sweeps everything except the pinned directory, skipping supported
     superseded directories when `runtimeInUse.isInUse` is true at that
     moment.
  The sweep still runs before the terminal event so an unsubscribing consumer
  cannot skip it. `RuntimeInstallService`'s "no lock required" comment is
  reworded: the plugin may now run from an older version directory during an
  install; placement never touches that directory.
- `BridgePluginDescriptor.installRuntime` gains
  `required RuntimeInUseSignal runtimeInUse`; all seven managed descriptors
  (DeepSeek, Copilot, OMP, Cursor, OpenCode, Codex, Pi) forward it exactly as
  they forward `startAborted`. `PluginRuntime.installRuntime` passes its
  private slot-backed implementation. Test fakes update in lockstep.
- `BridgePluginDescriptor` gains
  `bool needsManagedRuntimeUpgrade({required PluginConfig config, required
  String stateDirectory})`, default `false`, sync and disk-only. The
  descriptor is the single owner of the decision: each managed descriptor
  returns `managementCapabilities(config).contains(install) &&
  inventory.hasSupersededVersion(stateDirectory)`. The capability is the gate
  rather than each descriptor's private `_supportsManagedInstall`, because
  OpenCode additionally drops `install` in attach mode
  (`--opencode-no-auto-start`) — where Sesori does not own the runtime — and the
  private helper does not capture that. The lifecycle service does not re-check
  the capability.

### 3. Startup trigger (`bridge/app`)

- `PluginRuntime.needsManagedRuntimeUpgrade({required String pluginId})`
  forwards to the descriptor with the slot's config and state directory;
  `PluginLifecycleRepository` exposes it.
- The install admission sequence already inside `command()`
  (`plugin_lifecycle_service.dart:312-320`: register
  `_ActivePluginCommand(request: PluginLifecycleInstallRequest())`, then
  `unawaited(_executeInstall(...))`) moves into one private helper used by
  both entry points, parameterised by the completion mode below.
- `PluginLifecycleService.upgradeManagedRuntimes()` (sync, returns nothing):
  for every eligible plugin whose repository answer to
  `needsManagedRuntimeUpgrade` is true and that has no active command, log
  the upgrade at info level and admit an install with
  `InstallCompletion.reinspectOnly`.
- A private two-value enum `InstallCompletion { enableAndStart, reinspectOnly }`
  replaces a boolean. `_executeInstall` takes it; on `ProvisionReady` it calls
  `_enable` for `enableAndStart` (manual Install, unchanged) and
  `_inspectForCommand` for `reinspectOnly`. Progress, failure, interruption,
  slot release, and management-snapshot publication are unchanged; a failed
  upgrade leaves the previous setup (ready on the older supported runtime, or
  runtime-missing with the descriptor's hint) in place.
- `bridge_runtime_runner.dart` calls `upgradeManagedRuntimes()` immediately
  after `enforceBridgeOwnership()` and its abort check, before eager starts.
  Ordering guarantees no other live bridge owns the managed directory when the
  obsolete sweep runs, and startup returns without waiting on any download.
- Shutdown: `beginShutdown` already aborts install controllers; nothing new.

### 4. Client

No client change. Progress reaches the harness card through the existing
`plugin.install.progress` SSE event and the terminal outcome invalidates the
management snapshot as today. Verify at L3 that the card reads sensibly for a
harness that is already ready while its upgrade downloads.

## Failure Semantics

- Download, checksum, extraction, or probe failure: `ProvisionFailed`, logged
  locally with detail, sanitized on the wire.
  - Older supported runtime: it stays selected and ready. Its directory still
    exists, so the next bridge start triggers the upgrade again.
  - Below-minimum runtime: its obsolete directory was already removed before
    the download (the user requires obsolete cleanup not to wait on the
    replacement), so no managed directory other than the pinned target
    remains for the startup trigger to find. The harness stays
    runtime-missing with the descriptor's generic "Install from Sesori" hint,
    and the next bridge start does not retry automatically; the user presses
    Install, exactly today's manual path. Accepted rather than adding a retry
    marker independent of the directory.
- Shutdown mid-upgrade: existing abort path; partial files are redone next
  start because the sentinel is written last.
- Sweep failure on any directory: logged and skipped (best effort, unchanged).

## Compatibility

- No wire, database, or persisted-state change. `PluginSetupMetadata`,
  `PluginManagementMetadata`, and `plugin.install.progress` are reused as-is.
- Plugin interface and runtime package are in-repository contracts; every
  consumer updates in lockstep with no optional parameters or shims.
- Existing managed directories from released bridges are exactly the input
  this plan handles; no migration.

## Non-Goals

- No automatic first install for a harness that has never been installed
  through Sesori.
- No hot swap, generation restart, or session migration onto the new runtime.
- No periodic or relay-triggered update checks; the trigger is bridge startup.
- No new SSE event, client surface, or analytics.
- No change to PATH, fallback, or explicit-binary precedence.

## Complexity Budget

New mutable parts: none persistent, none in memory beyond what exists.

- The auto-upgrade reuses `_activePluginCommands` for identity, joining, and
  conflict.
- One typed read-side signal (`RuntimeInUseSignal`) read at sweep time
  replaces any stored active-path field, process scan, or stop hook.
- One two-value enum (`InstallCompletion`) distinguishes manual from startup
  installs inside the existing executor.

Deliberately not added: per-version ownership records, a deferred-sweep
queue, a stop-time sweep hook, a second startup probe pass to skip
PATH-preferring users, retry timers, an update-check schedule. If
implementation appears to need any of these, stop and ask.

## Cleanup Assessment

- `ManagedRuntimeVersionPolicy` and its `select` parameter are removed in
  Step 2, along with the selection test "applies exact or minimum policy". The
  provision-service test "does not accept a managed runtime with a different
  version" is replaced by a below-minimum rejection, which is what the single
  remaining rule asserts.
- The provision-notice message that names `bundledVersion` for an older
  managed runtime is corrected in Step 2.
- The "This bridge needs a newer X. Install it from Sesori" hints in OpenCode,
  Codex, and Cursor stay: they describe a below-minimum runtime until its
  obsolete directory is swept, after which the generic install hint applies.
- `docs/regression/plugin-runtime-installation.md` Known Limitations currently
  states managed runtime refresh is not covered; Step 4 replaces it.
- No obsolete transport shapes, flags, or database artifacts were found.

## Delivery Plan

Series slug `managed-runtime-auto-upgrade`; every PR titled
`<emoji> [managed-runtime-auto-upgrade] <description> [step <x>/5]`.

| Step | Exact PR title | Scope |
|---|---|---|
| 1/5 | `🌱 [managed-runtime-auto-upgrade] docs: plan automatic managed runtime upgrades [step 1/5]` | This plan and `TRACKER.md`. |
| 2/5 | `🚧 [managed-runtime-auto-upgrade] runtime: select supported managed versions and sweep by ownership [step 2/5]` | Design §1 and §2: inventory `installedVersions`, ordered managed candidates, policy enum removal, cleaner predicate, pre-download obsolete sweep, `RuntimeInUseSignal` through the descriptor interface and `PluginRuntime.installRuntime`, `needsManagedRuntimeUpgrade` default plus the seven descriptor overrides, notice fix, runtime/interface/descriptor tests, `plugin_runtime_test.dart` fake updates. |
| 3/5 | `⚙️ [managed-runtime-auto-upgrade] bridge: upgrade superseded managed runtimes on startup [step 3/5]` | Design §3: `PluginRuntime`/repository forwarding, shared install admission helper, `upgradeManagedRuntimes`, `InstallCompletion`, runner call, lifecycle-service and runtime tests. |
| 4/5 | `🌱 [managed-runtime-auto-upgrade] docs: reconcile runtime upgrade regression coverage [step 4/5]` | Reconcile the affected regression documents and the harness capability matrix; complete the cleanup audit against the implementation. |
| 5/5 | `🌿 [managed-runtime-auto-upgrade] verify: run runtime upgrade coverage and retire the plan [step 5/5]` | Run the recorded level and matrix, record results in `TRACKER.md`, move the plan to `.plan/completed/`. |

Step 2 is the largest (roughly 800 changed lines including seven descriptor
updates and tests) and stays well under the 1,500-line soft cap; it must be
one PR because the interface parameter forces lockstep descriptor changes.

## Per-Step Verification

- **Step 2:** `bridge/sesori_plugin_runtime` and `bridge/sesori_plugin_interface`
  tests plus strict analysis; each touched plugin package's descriptor tests
  and analysis; `bridge/app` `plugin_runtime_test.dart`. Prove: pinned
  preferred; highest supported older version selected when pinned is absent or
  unrunnable; version equal to minimum accepted; below-minimum and unparseable
  directories never selected; obsolete directories removed before the fake
  download client is invoked; supported superseded directories kept while
  `RuntimeInUseSignal.isInUse` is true and removed when false, on both the
  fresh and already-installed paths; sweep still precedes the terminal event;
  `needsManagedRuntimeUpgrade` true only with a superseded directory, no
  explicit binary, and a supported platform; each descriptor's `inspectSetup`
  reports ready with the older supported version and runtime-missing for
  below-minimum.
- **Step 3:** `bridge/app` lifecycle-service, runtime, and runner tests plus
  analysis, using completer-gated fake install streams. Prove: startup returns
  while an upgrade is pending; only eligible, install-capable, superseded
  plugins are upgraded; unrelated plugins stay routable; an older supported
  plugin remains in `readyPluginIds` during the download; a below-minimum
  plugin becomes ready after `ProvisionReady` without any `start` call; a
  failed upgrade preserves the prior setup; an explicit Install during the
  upgrade joins it and a disable conflicts; shutdown aborts it as interrupted;
  the slot-backed `RuntimeInUseSignal` reflects a live and a starting
  generation.

CI runs the full matrix; the PR monitor owns failures.

## Regression Documentation And Final Matrix

Affected feature documents (reconciled in Step 4):

- `docs/regression/plugin-runtime-installation.md` — primary: startup
  upgrade trigger, obsolete-first cleanup, ownership-aware sweep, availability
  without restart, failure fallback; remove the refresh-not-covered
  limitation.
- `docs/regression/plugin-setup-and-lifecycle.md` — resolution now selects a
  supported older managed runtime; DeepSeek wording that names an exact
  managed release is updated to the minimum/target pair.
- `docs/HARNESS_CAPABILITIES.md` — new row: managed runtime auto-upgrade is
  implemented for OpenCode, Codex, Copilot, Cursor, Pi, OMP, DeepSeek and not
  supported for Claude, Hermes, Grok (no Sesori-managed runtime).

### Highest required level

**L3 Release.** The delivered claim spans bridge startup, background install,
setup re-inspection, and the client-visible availability and progress of a
harness across production plugins.

### Required matrix

- **Bridge:** release-target host, headless: fresh start with (a) an older
  supported managed version, (b) a below-minimum managed version, (c) the
  pinned version already installed, (d) no managed directory. DeepSeek
  `0.1.2 → 0.1.3` is a real fixture once PR #1306 merges.
- **Plugins:** representative live coverage on DeepSeek; every supporting
  production plugin through the Step 2 automated descriptor coverage.
- **Client:** release-target phone platform: the harness stays selectable
  during the upgrade in case (a), becomes selectable without a bridge restart
  in case (b), and the card's progress reads sensibly.
- **Failure:** one forced download or checksum failure per case (a) and (b).
- **Ownership:** a session running on the older supported runtime during the
  upgrade is uninterrupted and its version directory survives until the
  generation stops; the next start resolves the pinned version.

## Risks And Accepted Limits

- A harness that is running when its upgrade completes keeps its superseded
  directory until the next bridge start; accepted disk residue.
- A PATH-preferring user with a stale managed directory downloads one target
  they do not run, once per target bump; accepted.
- Lifecycle commands conflict for the duration of a background download,
  exactly as for a manual Install; accepted, bounded by download time.
- Below-minimum directories for a platform without a pinned asset are left in
  place because nothing can replace them; the harness stays runtime-missing.
- A below-minimum upgrade whose download fails does not retry on the next
  start, because its obsolete directory is gone; the harness stays
  runtime-missing until the user presses Install. Deferring the obsolete
  sweep until after a successful install would restore the retry, but the
  user explicitly required obsolete cleanup not to wait on the replacement.
- Console output shows no install progress for a headless startup upgrade;
  the log records start, outcome, and failure detail.

## Expected Result

After a bridge update that raises a managed runtime target, a user who had
the previous managed version sees the harness stay usable while the new
version downloads, and the new version is used by the next plugin generation.
A user whose managed version fell below the minimum sees the harness blocked
briefly with a "needs a newer runtime" hint, then ready, without pressing
Install or restarting the bridge. PATH and explicit binaries, sessions, and
credentials are untouched. No database or wire change.
