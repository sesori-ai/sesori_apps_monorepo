# Step 11 — Distribution regression reconciliation

Ordinal 13/14. Planned PR title:
`🌿 [desktop-distribution] Reconcile private distribution regression coverage [step 13/14]`.
This step remains in progress. Its independently executable private-package portion
follows merged step 9; final public-link, onboarding and release-runbook reconciliation
still depends on step 10 and genuine shipped releases. That remaining documentation
is explicitly assigned to step 10's existing ordinal 12/14 PR, alongside its shipped
onboarding links, rather than a second ordinal 13 PR. Stable IDs and the 14-PR total
do not change.

## Reconciled private behavior

Current source and private evidence support these narrow claims:

- macOS x64 and arm64 staging produces signed/notarized/stapled DMGs and ZIPs
  containing the Developer ID signed, notarized/stapled app. The ZIP itself is neither
  signed nor stapled. Internal packages and website downloads are now public; stable
  production remains pending. Nested code, complete helper payload, Gatekeeper,
  extracted inventories and helper execution have source-specific qualification.
  Signed On/Off replacement to stable build 981 passed before the shared-store cutover;
  it is not new-format preservation proof. User guidance requires normal Quit before
  manual replacement; the downloads action does not enforce it. No updater service
  or automatic relaunch exists.
- Windows x64 and arm64 staging produces private unsigned per-user Inno Setup
  packages. Installer fixtures verify complete native payloads, current-user mutex
  refusal, bounded uninstall and shared-state preservation without launching Sesori.
  The x64 Inno launcher may run under ARM64 emulation; shipped GUI/helper libraries may
  not. Manual update UI exists, but signing, real N→N+1 and public assets do not.
- Linux x64 and arm64 staging produces private unsigned DEB and RPM packages. The
  packages own `/opt/sesori-desktop` plus the desktop launcher, desktop entry and icon,
  and never own the standalone bridge launcher or user data. Native Ubuntu 24.04,
  Debian 13 and Fedora 44 fixtures verify install, same-version reinstall and removal.
  Linux remains package-manager-owned; no app updater, service or package lifecycle
  script was added.

Authoritative package/run evidence remains in [step 4.a](step-04.md),
[step 4.b](step-04b.md), [step 7](step-07.md), and [step 9](step-09.md). Regression
contracts stay compact and do not duplicate every historical run. Earlier failed CI
attempts remain history, not unsupported-feature tombstones.

## Source reconciliation

Checked documentation against current owners:

- `.github/scripts/package_desktop_macos.py` signs nested code, notarizes/staples ZIP
  and DMG payloads, assesses Gatekeeper and records its limited proof boundary.
- `client/desktop/tool/windows_installer.iss` remains per-user, uses the SID-scoped
  running mutex, disables forced close/restart, and deletes only Sesori's login value
  during uninstall; `.github/scripts/package_desktop_windows.py` labels output unsigned.
- `.github/scripts/package_desktop_linux.py` and
  `.github/scripts/qualify_desktop_linux_package.sh` preserve staged payloads, derive
  dependencies, bound package ownership, reject lifecycle scripts and protect
  pre-existing shared-data sentinels.
- `client/desktop/lib/core/desktop_update_configuration.dart` maps packaged macOS and
  Windows builds to `https://sesori.com/desktop/`, Linux to package-manager guidance,
  and source builds to development guidance. `desktop_update_section.dart` only opens
  the external page and never quits, installs or relaunches.

Reconciled documents:

- `docs/regression/desktop-distribution.md`
- `docs/regression/desktop-macos-packaging.md` (verified current; no change needed)
- `docs/regression/desktop-bridge-supervision.md` (verified current; no change needed)
- `docs/desktop/downloads.md`
- this plan, tracker and step evidence

`docs/regression/account-and-onboarding.md` remains unchanged: step 10's six-target
shipped-download onboarding is still incomplete. The now-public macOS internal preview
is not a stable recommendation or Windows/Linux availability; its opt-in website
entry points and proof boundary are recorded in [step 6](step-06.md).

## Still blocked

Private package qualification is not release closeout. The owner-approved macOS
signing migration is complete, including shared callers, native post-deletion proof
and removal of all five repository copies. Remaining gates include:

- ordinary stable macOS submission through `store-production`; internal publication
  and deployed website links are already verified, not pending prerequisites;
- Windows signed/public assets and winget approval; Linux signed APT/RPM repositories;
- unwaived Windows/Linux real-account restoration, browser return, minimum OS,
  interactive GUI, Secret Service, tray, login-launch and standard-user coverage;
- Windows signed N→N+1 manual replacement and Linux repository-owned N→N+1 updates,
  including safe Quit, failed-stop refusal, shared-state retention and trust/failure paths.

Gate C and the enumerated remaining macOS QA were explicitly retired on 2026-09-26.
Do not reinstate those prerequisites. Accepted gaps, old-format replacement proof and
unproved shared-store behavior remain distinct; parent reconciliation retains its own
scope and numbering. No link, asset, credential, account or publication is invented. Step 10 and final step
11 closeout are not complete. Step 12 remains blocked; plan stays active until full L5
matrix passes or an explicit user-approved reduction is recorded.
