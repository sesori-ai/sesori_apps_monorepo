# Phase 3 — Packaging / Signing / Self-Update (= v1)

> Goal: produce signed, notarized, self-updating, downloadable installers on all
> three OSes, each bundling the same-commit bridge binary. End state: **v1
> shipped.**

**Release-safety (critical):** desktop build/sign legs are **separate,
non-blocking** CI jobs. The existing all-or-nothing release `finalize` must NOT
gate on desktop — a desktop failure can never abort a CLI/mobile release
(invariant #3). Folding desktop into the gate is a later, deliberate decision.

**Per-PR template:** Goal · Scope · Risk · Review-size · Acceptance · DoD ·
Aristotle verdicts · Findings log · Plan-deltas.

---

## PR 3.0a — macOS entitlements (no-sandbox + hardened runtime + spawn-child)
- **Goal:** Non-sandboxed Developer ID entitlements + hardened runtime + network
  client; ensure a notarized GUI may spawn the bundled bridge child.
- **Risk:** Med. **Size:** S-M.
- **Acceptance:** a locally-signed build launches and spawns the bridge under
  hardened runtime.

## PR 3.0b — CI secrets provisioning (config + docs)
- **Goal:** Wire GitHub secrets: Dev ID cert + notarization API key, Windows cert
  placeholder, Sparkle EdDSA keys, GPG. Docs only; no secrets in repo.
- **Risk:** Low. **Size:** S.
- **Acceptance:** workflow references resolve; documented setup.

## PR 3.1 — `_reusable-desktop-build.yml` macOS leg (unsigned)
- **Goal:** New reusable workflow (mirrors `_reusable-bridge-build.yml`): `needs:`
  the bridge-build job, download the signed bridge artifact, `lipo` → universal,
  build universal Flutter app, bundle the bridge, produce an unsigned `.app`/`.dmg`.
- **Risk:** High. **Size:** M.
- **Acceptance:** unsigned `.dmg` artifact produced in CI.

## PR 3.2 — macOS codesign + notarize + staple
- **Goal:** Codesign (Dev ID), submit to notarytool, staple.
- **Risk:** High. **Size:** M.
- **Acceptance:** notarized `.dmg` installs + runs + spawns the bridge on a clean
  mac.

## PR 3.3 — Windows leg: build + bundle + installer (unsigned)
- **Goal:** Build Flutter Windows (x64 + arm64), bundle the matching bridge,
  Inno/NSIS installer.
- **Risk:** High. **Size:** M.
- **Acceptance:** unsigned installer installs + runs on a clean Windows.

## PR 3.4 — Windows code signing *(needs cert — lead-time)*
- **Goal:** Sign the installer + binaries with the code-signing cert.
- **Risk:** Med. **Size:** S-M.
- **Acceptance:** signed installer runs without SmartScreen "unknown publisher".

## PR 3.5 — Linux AppImage + bundle + GPG signing
- **Goal:** Build Flutter Linux (x64 + arm64), bundle the bridge, produce a
  **GPG-signed** AppImage with zsync metadata. Decision #13 locks "fully signed
  on all three OSes," so Linux signing is **mandatory**, not optional (an
  unsigned AppImage + unauthenticated zsync update path would contradict the
  locked release-security decision).
- **Risk:** Med-High. **Size:** M.
- **Acceptance:** AppImage runs on a clean distro; bridge spawns; the AppImage +
  zsync update path is GPG-signed and verified.

## PR 3.6 — Update-apply policy (stop helper first) + failed-update/rollback + UX
- **Goal:** Add `DesktopUpdateService` in `module_desktop_core/lib/src/services/`
  as the Layer-3 owner of update-apply policy. It calls the
  `BridgeProcessRepository` expected-stop operation (which marks the helper stop
  as expected and suppresses respawn), stages/applies through `AppUpdateRepository`
  over a dumb Layer-1 `AppUpdateApi` (which wraps the Layer-0 `AppUpdater` adapter),
  relaunches, then **restores last-on** through lower-layer desktop-instance
  repository semantics. Also surface update-available/failed in the window and
  handle failed staging/apply gracefully (no bricking). The service must avoid
  same-layer service dependencies on `BridgeProcessService` or
  `DesktopInstanceService`.

  The bundled bridge is a running child of the app install; on Windows a running
  executable can't be replaced, and on any OS applying a bundle update while the
  supervisor respawns the old child risks a failed or mixed-version update.
- **Risk:** Med. **Size:** M.
- **Acceptance:** with a fake `AppUpdater` and the bridge **on**, the update
  policy stops the helper without respawn thrash, calls stage/apply, relaunches,
  and restores last-on; an injected failed update leaves the app runnable +
  reports it; `AppUpdater` remains a dumb adapter behind `AppUpdateApi` with no
  helper stop/restore policy; `DesktopUpdateService` depends only on lower-layer
  collaborators.

## PR 3.7 — macOS self-update (Sparkle)
- **Goal:** `auto_updater`/Sparkle + EdDSA keys + appcast generation from GitHub
  releases, using the PR 3.6 helper-stop/apply policy.
- **Risk:** High. **Size:** M.
- **Acceptance:** vN→vN+1 update succeeds on macOS with the bridge on and off.

## PR 3.8 — Windows self-update (WinSparkle)
- **Goal:** WinSparkle + appcast, using the PR 3.6 helper-stop/apply policy.
- **Risk:** High. **Size:** M.
- **Acceptance:** vN→vN+1 update succeeds on Windows with the bridge on and off;
  replacing a running executable does not fail.

## PR 3.9 — Linux self-update (zsync/AppImageUpdate)
- **Goal:** zsync feed + AppImageUpdate integration, using the PR 3.6
  helper-stop/apply policy.
- **Risk:** Med-High. **Size:** M.
- **Acceptance:** vN→vN+1 update succeeds on Linux with the bridge on and off.

## PR 3.10 — Release-pipeline integration (non-blocking) + versioning
- **Goal:** Hook the desktop build into `release-all-platforms.yml` +
  `submit-release.yml` as **non-blocking** legs; extend `make bump-version` to
  bump the desktop package; add a **Desktop** section to `CHANGELOG.md`; update
  `tool/generate_release_notes.dart` so desktop-owned paths classify as Desktop
  instead of App; publish appcast/zsync to releases keyed to the shared version.
- **Trigger paths:** PR 0.1 excluded `client/desktop/**` from the (mobile-product)
  release triggers, so this PR must **add `client/desktop/**`,
  `bridge/**`, `client/module_desktop_core/**`, `client/module_app_ui/**`, shared
  desktop-consumed paths (`client/module_core/**`, `client/module_auth/**`,
  `client/module_prego/**`, workspace client pubspec/lock/config files,
  `shared/sesori_shared/**`), and any other desktop-consumed UI package paths to
  the desktop release jobs' triggers** — otherwise a desktop-only,
  shared-client, or shared-protocol fix never starts the internal release /
  appcast-zsync publish and the self-update channel silently misses releases.
  The desktop jobs stay **non-blocking** for the CLI/mobile legs (invariant #3).
- **Risk:** Med. **Size:** M.
- **Acceptance:** an internal release dry-run produces signed, self-update-ready
  desktop artifacts; a **desktop-only shell, desktop-core, or shared-UI** change
  triggers the desktop release/appcast publish; a forced desktop-leg failure does
  **not** block the CLI/mobile release; release notes classify
  `client/desktop/**`, `client/module_desktop_core/**`, and desktop-consumed UI
  under Desktop, shared client dependencies under all affected product sections,
  and `shared/sesori_shared/**` under Shared/Protocol or all affected consumer
  sections rather than App-only or Desktop-only.

## PR 3.11 — Uninstall + login-item cleanup (desktop-owned state only)
- **Goal:** Per-OS uninstall removes the **login item** and **GUI-owned** state
  (GUI secure storage, any explicitly desktop-namespaced helper state). It must
  **NOT** delete `token.json` or the managed bridge runtime: those live under the
  **shared** Sesori data root (`tokenPath()`, `ManagedRuntimePathService`) used by
  the standalone CLI, and removing them would log out / break the terminal bridge
  the master plan preserves (ADR A10). If shared helper state must be cleaned,
  namespace/migrate it to a desktop-owned location first.
- **Best-effort server unregister first:** for users who uninstall **without**
  going through logout, do a best-effort `BridgeRepository.deleteBridge` (the
  module_core seam from PR 2.13) using the still-available token + GUI-persisted
  `bridgeId` **before** clearing GUI-owned credentials/state — otherwise a stale
  offline bridge is orphaned on the account and deleting the local copy first
  makes later cleanup impossible. This step is **best-effort and exempt from the
  capture-and-rethrow policy below**: its failure is logged and swallowed (the
  server record can also be removed from the account UI), so a network/unregister
  error never aborts the uninstall or gets rethrown.
- **Scope note:** wrap each cleanup step in its own `on Object catch` so one
  failure (permissions/missing file) doesn't block the rest; capture the first
  meaningful error and rethrow after all steps run — **except** the best-effort
  server-unregister step above, which is logged-and-swallowed and never
  contributes to the rethrown error.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** uninstall removes the login item + GUI state; a co-installed
  standalone CLI remains logged in and runnable; a forced mid-step failure still
  runs remaining steps.
