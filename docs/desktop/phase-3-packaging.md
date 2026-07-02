# Phase 3 — Packaging / Signing / Self-Update (= v1)

> Goal: produce signed, notarized, self-updating, downloadable installers on all
> three OSes, each bundling the same-commit bridge binary. End state: **v1
> shipped.**

**Release-safety (critical):** desktop build/sign legs are **separate,
non-blocking** CI jobs. The existing all-or-nothing release `finalize` must NOT
gate on desktop — a desktop failure can never abort a CLI/mobile release
(invariant #3). Folding desktop into the gate is a later, deliberate decision.

**Per-OS shipping is allowed (macOS-first).** The OS legs are deliberately
separate PR chains — macOS 3.1→3.2→3.6→3.7→3.10→3.11a→**MT-4a**, Windows
3.3→3.4→3.8→3.11b→**MT-4b**, Linux 3.5→3.9→**MT-4c** — and the **§9 index
lists them in exactly that chain order** so the top-to-bottom resume rule
completes macOS, including its ship gate, while the Windows cert (§8 lead-time
risk) clears. The shared ship-gate work (3.10 release-pipeline integration,
3.11a in-app reset) sits **inside the macOS chain, before MT-4a**, because the
first shipped platform needs it; 3.10 is **leg-additive** (it integrates the
legs that exist when it lands — macOS — and the Windows/Linux chains extend
the same workflow/feeds in 3.8/3.9). v1 may ship on macOS alone — "fully
signed on all three OSes" (Decision #13) binds each *shipped* platform, it does
not force all three to ship simultaneously. Never ship an unsigned platform to
route around it. If the cert blocks 3.4, mark it ◐ in §9 with a §8 note and
skip the **whole dependent Windows chain** (3.8, 3.11b, MT-4b) to the Linux
chain — never start a row whose dependency is blocked.

**Per-PR template:** Goal · Scope · Risk · Review-size · **Regression guide** ·
Acceptance · DoD (incl. PLAN.md §9 row + pointer advanced) · Aristotle verdicts ·
Findings log · Plan-deltas.

> **Regression guide** = the blast radius of the PR. For Phase 3 the recurring
> blast radius is the **existing CLI/mobile release pipeline** (shared workflows,
> version tooling) and the **co-installed standalone CLI's on-disk state** —
> each PR lists its specifics.

---

## PR 3.0a — macOS entitlements (no-sandbox + hardened runtime + spawn-child)
- **Goal:** Non-sandboxed Developer ID entitlements + hardened runtime + network
  client; ensure a notarized GUI may spawn the bundled bridge child.
- **Risk:** Med. **Size:** S-M.
- **Regression guide:** entitlements silently break runtime capabilities. After
  signing locally check: (1) Keychain-backed `SecureStorage` still reads/writes
  (signing identity changes can orphan keychain items — relogin at worst, no
  crash); (2) the spawned bridge can itself spawn `git`/`opencode`/`ps` under
  hardened runtime; (3) dev (unsigned `flutter run`) workflow unaffected.
- **Acceptance:** a locally-signed build launches and spawns the bridge under
  hardened runtime.

## PR 3.0b — CI secrets provisioning (config + docs)
- **Goal:** Wire GitHub secrets: Dev ID cert + notarization API key, Windows cert
  placeholder, Sparkle EdDSA keys, GPG. Docs only; no secrets in repo.
  Parallelizable with Phase 2 — do this (and the cert purchase, §8) early, not
  when 3.2 blocks on it.
- **Risk:** Low. **Size:** S.
- **Regression guide:** none to code. Check no secret value or private key path
  lands in the repo/docs (names only), and existing workflows still parse
  (`actionlint`/CI green on an untouched-path PR).
- **Acceptance:** workflow references resolve; documented setup.

## PR 3.1 — `_reusable-desktop-build.yml` macOS leg (unsigned)
- **Goal:** New reusable workflow (mirrors `_reusable-bridge-build.yml`): `needs:`
  the bridge-build job, download the signed bridge artifact, `lipo` → universal,
  build universal Flutter app, bundle the bridge, produce an unsigned `.app`/`.dmg`.
- **Risk:** High. **Size:** M.
- **Regression guide:** shares the bridge-build artifacts with the CLI release.
  Check: (1) the CLI release path consumes its bridge artifacts unchanged
  (naming/retention untouched, or additive only); (2) a forced desktop-leg
  failure does not mark the CLI/mobile pipeline red or block `finalize`
  (invariant #3 — actually force one to prove it); (3) runner-minute cost of the
  new macOS leg reviewed (it runs per release, not per PR).
- **Acceptance:** unsigned `.dmg` artifact produced in CI.

## PR 3.2 — macOS codesign + notarize + staple
- **Goal:** Codesign (Dev ID), submit to notarytool, staple. **Every nested
  Mach-O must be signed** — including the bundled pure-Dart bridge binary and
  any Flutter plugin dylibs — or notarization rejects the bundle.
- **Risk:** High. **Size:** M.
- **Regression guide:** CI-only, but it consumes shared secrets and the shared
  release trigger. Check: (1) notarization of the desktop app does not rate-limit
  or contend with any existing notarization usage; (2) a notarization failure
  stays non-blocking for CLI/mobile (invariant #3); (3) the signed bridge inside
  the bundle still self-identifies as a bundled install (PR 2.8 guard) — signing
  must not alter the layout checks.
- **Acceptance:** notarized `.dmg` installs + runs + spawns the bridge on a clean
  mac (Gatekeeper pass, no right-click-open workaround).

## PR 3.3 — Windows leg: build + bundle + installer (unsigned)
- **Goal:** Build Flutter Windows (x64 + arm64), bundle the matching bridge,
  Inno/NSIS installer.
- **Risk:** High. **Size:** M.
- **Regression guide:** as PR 3.1 (shared bridge artifacts, non-blocking leg).
  Additionally check: (1) the installer bundles the **matching-arch** bridge
  (x64 installer must not carry an arm64 helper); (2) install/uninstall/reinstall
  round-trip leaves no stray login-item or PATH residue; (3) per-user vs
  all-users install decision recorded (affects autostart + updater paths).
- **Acceptance:** unsigned installer installs + runs on a clean Windows.

## PR 3.4 — Windows code signing *(needs cert — lead-time)*
- **Goal:** Sign the installer + binaries with the code-signing cert.
- **Risk:** Med. **Size:** S-M.
- **Regression guide:** signing wraps the 3.3 artifacts. Check: (1) timestamping
  is on (signatures must outlive cert expiry); (2) the signed installer still
  installs silently for the updater path (WinSparkle, PR 3.8); (3) all shipped
  EXEs/DLLs are signed, not just the installer (SmartScreen judges both).
- **Acceptance:** signed installer runs without SmartScreen "unknown publisher".

## PR 3.5 — Linux AppImage + bundle + GPG signing
- **Goal:** Build Flutter Linux (x64 + arm64), bundle the bridge, produce a
  **GPG-signed** AppImage with zsync metadata. Decision #13 locks "fully signed
  on all three OSes," so Linux signing is **mandatory**, not optional (an
  unsigned AppImage + unauthenticated zsync update path would contradict the
  locked release-security decision).
- **Risk:** Med-High. **Size:** M.
- **Regression guide:** AppImages fail on missing host libs, not at build time.
  Check on clean VMs (GNOME **and** KDE): (1) tray libs (`libayatana-appindicator`)
  are bundled or gracefully absent → A24 windowed fallback engages, app still
  usable; (2) secure storage without a secret service fails loudly, not
  corruptly; (3) the bundled bridge spawns and can run `git`/`opencode`; (4)
  desktop-leg failure stays non-blocking (invariant #3).
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
- **Regression guide:** reuses the PR-2.6 expected-stop boundary — the risk is
  desynchronizing it from PR 2.7's state machine. Check: (1) an update-stopped
  helper is never classified as a crash (no backoff respawn during apply, even
  if the GUI restarts mid-flow); (2) an aborted/failed stage leaves the helper
  restartable and last-on intact; (3) a phone-triggered restart (exit 86)
  arriving mid-update does not resurrect the helper during apply; (4) update
  check/apply while logged out doesn't spawn anything.
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
- **Regression guide:** the update channel is write-once per shipped version — a
  bad appcast/key strands every installed copy. Check: (1) the EdDSA private key
  is backed up outside CI and the appcast signs correctly (verify with a real
  vN→vN+1 on a clean mac BEFORE tagging v1); (2) appcast generation is keyed to
  the unified version (Decision #12) and skips non-desktop releases; (3) an
  unreachable appcast degrades silently (no startup delay/error); (4)
  check-for-update in the 2.10 window drives this path.
- **Acceptance:** vN→vN+1 update succeeds on macOS with the bridge on and off.

## PR 3.8 — Windows self-update (WinSparkle)
- **Goal:** WinSparkle + appcast, using the PR 3.6 helper-stop/apply policy.
- **Risk:** High. **Size:** M.
- **Regression guide:** as PR 3.7 (channel integrity), plus Windows specifics.
  Check: (1) the helper exe is genuinely stopped before the installer runs
  (locked-file apply is the known Windows failure); (2) the silent-install flags
  used by WinSparkle match the 3.3/3.4 installer; (3) autostart/login-item
  survives the update without duplication.
- **Acceptance:** vN→vN+1 update succeeds on Windows with the bridge on and off;
  replacing a running executable does not fail.

## PR 3.9 — Linux self-update (zsync/AppImageUpdate)
- **Goal:** zsync feed + AppImageUpdate integration, using the PR 3.6
  helper-stop/apply policy.
- **Risk:** Med-High. **Size:** M.
- **Regression guide:** as PR 3.7 (channel integrity), plus: (1) the updated
  AppImage keeps the executable bit and the same path expectations (autostart
  entries reference the file path); (2) GPG verification failure refuses the
  update loudly rather than applying unsigned; (3) update from a read-only
  location (e.g. AppImage on a mounted dir) fails gracefully.
- **Acceptance:** vN→vN+1 update succeeds on Linux with the bridge on and off.

## PR 3.10 — Release-pipeline integration (non-blocking, leg-additive) + versioning
- **Goal:** Hook the desktop build into `release-all-platforms.yml` +
  `submit-release.yml` as **non-blocking** legs; extend `make bump-version` to
  bump the desktop package; add a **Desktop** section to `CHANGELOG.md`; update
  `tool/generate_release_notes.dart` so desktop-owned paths classify as Desktop
  instead of App; publish update feeds to releases keyed to the shared version.
  **Leg-additive:** this PR lands at the end of the macOS chain (before MT-4a)
  and integrates the legs that exist at that point — the macOS build/sign +
  Sparkle appcast. The Windows and Linux chains extend the same workflow and
  feed publishing when they land (WinSparkle appcast leg in PR 3.8, zsync feed
  leg in PR 3.9) — do not block the macOS ship gate on platforms that haven't
  been built yet.
- **Trigger paths — job-level gating is MANDATORY, not a workflow-level
  `paths:` edit.** PR 0.1 excluded `client/desktop/**` from the (mobile-product)
  release triggers, and a desktop-only, shared-client, or shared-protocol fix
  must start the desktop release / feed publish — but GitHub Actions has **no
  job-level `paths:` trigger**, and in the existing
  `release-all-platforms.yml` the iOS/Android/bridge/finalize jobs run
  unconditionally once the workflow starts. Naively adding `client/desktop/**`
  (+ `bridge/**`, `client/module_desktop_core/**`, `client/module_app_ui/**`,
  `client/module_core/**`, `client/module_auth/**`, `client/module_prego/**`,
  workspace client pubspec/lock/config files, `shared/sesori_shared/**`) to the
  workflow-level `on.push.paths` would make a desktop-only merge run the
  CLI/mobile release pipeline and possibly roll an internal prerelease —
  contradicting this PR's own "vice versa" acceptance. So: either add a
  **changed-paths detection job whose outputs gate every job group with `if:`**
  (mobile/bridge jobs on mobile/bridge paths, desktop jobs on desktop-consumed
  paths, `finalize` gated accordingly), or split a **separate desktop release
  workflow** that reuses the bridge-build artifacts — chosen at this PR's plan
  review. The desktop jobs stay **non-blocking** for the CLI/mobile legs
  (invariant #3) either way.
- **Risk:** Med. **Size:** M.
- **Regression guide:** this PR touches the **live CLI/mobile release pipeline**
  — the highest-blast-radius change in the phase. Check: (1) a full release
  dry-run produces CLI + mobile artifacts **byte-identical in process** to
  today's (same jobs, same gates, same TestFlight/Play submissions); (2)
  `make bump-version` + `tool/sync_versions.dart` still pass their existing
  tests (`bridge/app/test/tool/sync_versions_test.dart`) with the desktop
  package added; (3) a mobile-only change does NOT trigger desktop legs and vice
  versa (probe both); (4) release-notes classification verified against a sample
  release containing App + Desktop + Shared changes; (5) forced desktop-leg
  failure → `finalize` still green.
- **Acceptance:** an internal release dry-run produces signed, self-update-ready
  desktop artifacts; a **desktop-only shell, desktop-core, or shared-UI** change
  triggers the desktop release/appcast publish; a forced desktop-leg failure does
  **not** block the CLI/mobile release; release notes classify
  `client/desktop/**`, `client/module_desktop_core/**`, and desktop-consumed UI
  under Desktop, shared client dependencies under all affected product sections,
  and `shared/sesori_shared/**` under Shared/Protocol or all affected consumer
  sections rather than App-only or Desktop-only.

## PR 3.11a — In-app "Disconnect & reset" (macOS/Linux mechanism; desktop-owned state only)
- **Goal:** The reusable cleanup flow + the trigger for the two OSes that have
  **no uninstall hook** (macOS drag-to-trash, Linux AppImage). An in-app
  **"Disconnect & reset…"** action (window/settings) runs the flow then quits.
  The flow removes **GUI-owned** state only (login item/XDG autostart entry, GUI
  secure storage, desktop-namespaced helper state, helper logs). It must **NOT**
  delete `token.json` or the managed bridge runtime: those live under the
  **shared** Sesori data root (`tokenPath()`, `ManagedRuntimePathService`) used by
  the standalone CLI, and removing them would log out / break the terminal bridge
  the master plan preserves (ADR A10). If shared helper state must be cleaned,
  namespace/migrate it to a desktop-owned location first. macOS ≥13
  auto-disables login items of deleted apps, but GUI state and the server
  registration survive trash-only removal — document that path as leaving an
  orphan the account UI can delete. Lands **before MT-4a** (the macOS ship gate
  verifies it).
- **Best-effort server unregister first:** for users who reset/uninstall
  **without** going through logout, do a best-effort
  `BridgeRepository.deleteBridge` (the module_core seam from PR 2.13) using the
  still-available token + GUI-persisted `bridgeId` **before** clearing GUI-owned
  credentials/state — otherwise a stale offline bridge is orphaned on the
  account and deleting the local copy first makes later cleanup impossible. This
  step is **best-effort and exempt from the capture-and-rethrow policy below**:
  its failure is logged and swallowed (the server record can also be removed
  from the account UI), so a network/unregister error never aborts the flow or
  gets rethrown.
- **Scope note:** wrap each cleanup step in its own `on Object catch` so one
  failure (permissions/missing file) doesn't block the rest; capture the first
  meaningful error and rethrow after all steps run — **except** the best-effort
  server-unregister step above, which is logged-and-swallowed and never
  contributes to the rethrown error.
- **Risk:** Low-Med. **Size:** S-M.
- **Regression guide:** the one thing this must never do is touch shared CLI
  state. Check: (1) after a reset, a co-installed standalone CLI still starts,
  is still logged in (`token.json` intact), and its managed runtime still
  exists; (2) the helper is stopped before state removal (no running process
  whose files vanish); (3) running "Disconnect & reset" while already logged
  out / offline still completes local cleanup.
- **Acceptance:** the in-app reset removes the login item/autostart + GUI state
  on macOS and Linux; a co-installed standalone CLI remains logged in and
  runnable; a forced mid-step failure still runs remaining steps; the
  trash-only macOS path is documented (orphan removable from the account UI).

## PR 3.11b — Windows uninstaller cleanup flow
- **Goal:** Wire the PR-3.11a cleanup flow into the Windows **uninstaller**
  (the only real uninstall hook; created by PR 3.3's installer): stop the app +
  helper if running (or instruct the user), then run the same best-effort
  unregister → login-item/state cleanup. Lands in the Windows chain before
  MT-4b.
- **Risk:** Low. **Size:** S.
- **Regression guide:** as PR 3.11a (shared CLI state untouched), plus: the
  uninstaller must handle the app-running case, and an uninstall→reinstall
  round-trip yields a working app with no duplicated login items.
- **Acceptance:** Windows uninstall removes the login item + GUI state while a
  co-installed standalone CLI remains logged in and runnable; works when
  invoked while the app is running.

---

## MT-4a / MT-4b / MT-4c — Manual checkpoints: per-OS ship gates (user-run)

> **One gate per shipped platform**, placed at the end of that platform's §9
> chain: **MT-4a = macOS** (after 3.11a — this alone gates a macOS-first v1),
> **MT-4b = Windows** (after 3.11b), **MT-4c = Linux** (after 3.9). Each gate
> runs the shared checklist below **for that OS** on **clean machines/VMs** (no
> dev toolchain, no prior Sesori state) — that is the whole point. Item
> applicability is marked per gate; item 8 runs fully at MT-4a and re-verifies
> only the new leg at MT-4b/c.

| # | Check | How | Pass looks like | Gates |
|---|---|---|---|---|
| 1 | Cold install | download the artifact like a user would (browser) | macOS: Gatekeeper-clean open; Windows: no SmartScreen warning; Linux: AppImage runs on GNOME + KDE | all |
| 2 | First-run flow | login → bridge on | provisioning progress → healthy; phone connects; helper survives token expiry | all |
| 3 | Reboot behaviour | enable autostart; reboot | hidden tray boot (or A24 windowed fallback); last-on bridge respawns | all |
| 4 | Self-update | install vN, publish vN+1 internally, update with bridge ON and again with bridge OFF | helper stopped cleanly (no respawn thrash), app relaunches at vN+1, last-on restored, control channel + phone work after | all |
| 5 | Failed update | corrupt/block the update feed artifact | app stays at vN and runnable; failure reported; retry works later | all |
| 6 | Update signature | tamper with the appcast/zsync entry (bad signature) in a test feed | update is refused loudly; nothing applied | all |
| 7 | Version coherence | after update, check GUI about + helper version + phone-visible bridge version | all report the same unified version (Decision #12) | all |
| 8 | Release pipeline | run the internal release dry-run end-to-end | CLI + mobile legs unaffected; desktop legs non-blocking; the platform's update feed published to the release | full at MT-4a; new-leg-only at MT-4b/c |
| 9 | Uninstall / reset | Windows: uninstaller (3.11b); macOS/Linux: in-app "Disconnect & reset" (3.11a) | login item/autostart gone; GUI state gone; bridge gone from account list; co-installed CLI still logged in + runnable (A10) | all |
| 10 | Trash-only removal | drag the app to Trash without reset | login item auto-disabled (macOS ≥13); orphaned bridge removable from account UI (documented) | MT-4a only |

- **Aristotle:** n/a (no code). **Findings:** — (log per gate) **Deltas:** —
