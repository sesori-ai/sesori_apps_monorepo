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

## PR 3.5 — Linux AppImage + bundle (+ optional GPG)
- **Goal:** Build Flutter Linux (x64 + arm64), bundle the bridge, produce AppImage
  (+ optional GPG sign) with zsync metadata.
- **Risk:** Med-High. **Size:** M.
- **Acceptance:** AppImage runs on a clean distro; bridge spawns.

## PR 3.6 — macOS self-update (Sparkle)
- **Goal:** `auto_updater`/Sparkle + EdDSA keys + appcast generation from GitHub
  releases.
- **Risk:** High. **Size:** M.
- **Acceptance:** vN→vN+1 update succeeds on macOS.

## PR 3.7 — Windows self-update (WinSparkle)
- **Goal:** WinSparkle + appcast.
- **Risk:** High. **Size:** M.
- **Acceptance:** vN→vN+1 update succeeds on Windows.

## PR 3.8 — Linux self-update (zsync/AppImageUpdate)
- **Goal:** zsync feed + AppImageUpdate integration.
- **Risk:** Med-High. **Size:** M.
- **Acceptance:** vN→vN+1 update succeeds on Linux.

## PR 3.9 — Failed-update / rollback handling + update UX
- **Goal:** Surface update-available/failed in the window; handle a failed
  staging/apply gracefully (no bricking).
- **Risk:** Med. **Size:** M.
- **Acceptance:** an injected failed update leaves the app runnable + reports it.

## PR 3.10 — Release-pipeline integration (non-blocking) + versioning
- **Goal:** Hook the desktop build into `release-all-platforms.yml` +
  `submit-release.yml` as **non-blocking** legs; extend `make bump-version` to
  bump the desktop package; add a **Desktop** section to `CHANGELOG.md`; publish
  appcast/zsync to releases keyed to the shared version.
- **Risk:** Med. **Size:** M.
- **Acceptance:** an internal release dry-run produces signed, self-update-ready
  desktop artifacts; a forced desktop-leg failure does **not** block the
  CLI/mobile release.

## PR 3.11 — Uninstall + login-item/token cleanup
- **Goal:** Per-OS uninstall removes the login item and cleans
  `token.json`/bridge runtime dirs.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** uninstall leaves no login item or stale credentials.
