# Step 9 — Private Linux package qualification

Ordinal 11/14. Step 8's Windows publication/winget requires signed public assets
and remains blocked; it is not replaced by fabricated links or manifests. Continue
independently executable Linux preparation while preserving macOS → Windows → Linux
shipping order. No signing keys, public repositories, GCS or accounts are authorized.

## Implementation plan

- Add `.github/scripts/package_desktop_linux.py`, reusing native inventory and
  committed staging from existing tooling. Consume the current bundle's version,
  build number, source SHA, Linux OS and CPU; do not hardcode historical versions.
- Preserve the complete staged GUI/helper/assets/licenses below
  `/opt/sesori-desktop/`. Own `/usr/bin/sesori-desktop`, one desktop entry and a
  correctly sized application icon. Never replace the standalone bridge executable
  or own user homes, autostart, credentials, databases, runtimes or projects.
- Build native DEB using `dpkg-deb`; derive linked-library requirements with
  `dpkg-shlibdeps`, preserving bundled-library lookup. Check actual plugin source
  for `dlopen` runtime dependencies before adding explicit requirements.
- Build native RPM using `rpmbuild` in a pinned supported Fedora container on the
  matching native host; let RPM generate ELF dependencies. Do not claim Ubuntu
  rpmbuild alone validates Fedora dependencies. Freeze image release/digest after
  checking official availability; no emulation fallback.
- Extend the existing private qualification workflow with a manual Linux mode.
  Reuse native Ubuntu x64/arm64 SDK/bundle builds. Validate DEB installation/removal
  through actual package managers on isolated Ubuntu24.04/Debian13 containers and
  RPM through Fedora on the same native CPU. Do not run GUI or helper services.
  Preserve root-owned package paths and realistic shared-data sentinels; compare
  installed payload paths/hashes with staging. Retain packages and diagnostic
  evidence as private artifacts with the existing 14-day retention.
- `.github/scripts/test_package_desktop_linux.py` exercises synthetic identity,
  CPU, payload/layout, package metadata, dependency invocation and ownership rules.
  Run targeted Python tests and actionlint. Add precise supported behavior to
  `docs/regression/desktop-distribution.md` and record measured native source/run.

## Boundaries and proportionality

No new application classes, DI, services, state, transport/storage contracts,
shutdown owner or updater. Package managers own replacement and tracked-file removal;
no maintainer scripts launch processes or walk user homes. Existing autostart path
behavior stays unchanged; minor stale user autostart residue is accepted.
Architecture reviews are not required for this non-architectural tooling slice.

Estimate 740–1,020 authored lines including fixtures/workflow/docs; keep below the
1,500 soft cap and split cleanly if measured implementation grows beyond it. No
new mutable application state. Avoid general release catalogs, repository generators,
key rotation or broad package-manager abstractions. Real dependency failures justify
specific corrections, not guessed distribution support.

## Evidence and release gates

Native x64 and ARM64 remain required. Container install/dependency/file-ownership
checks prove package mechanics only, not desktop-session usability. Real GUI, tray,
Secret Service available/unavailable, login, account restoration, minimum-OS and
signed/public retrieval gates remain open. A same-version reinstall must not be
reported as an actual N→N+1 application upgrade. Missing environments are blockers,
not successful or silently dropped rows.

Keep the PR non-draft for reviews. Hold readiness with an explicit pending evidence
status while independent native runs execute, and register a completion watcher
that wakes the parent. Never stop at an unobserved manual Actions run. Do not touch
local GUI/bridge processes or execute package installation on this Mac.

## Local implementation checkpoint

Tooling now stages the complete bundle below `/opt/sesori-desktop`, owns only the
`sesori-desktop` launcher/desktop entry/existing 512x512 RGBA application icon, derives DEB dependencies
through `dpkg-shlibdeps`, and leaves RPM ELF requirements to native Fedora
`rpmbuild`. It scans actual locked Linux sources for `flutter_secure_storage_linux`,
`tray_manager`, and `window_manager`; none uses `dlopen` or `DynamicLibrary.open`, so
no explicit guessed dependency was added. Package fixtures reject DEB maintainer
scripts and RPM scriptlets, verify root-owned staged hashes/paths, perform an honestly
named same-version reinstall, remove package-owned paths, and preserve shared-data
sentinels without launching either payload.

Fedora's official `https://fedoraproject.org/releases.json` listed 42, 43 and 44 as
releases while 45 was Beta when checked on 2026-09-16. The official
`registry.fedoraproject.org/v2/fedora/manifests/44` response supplied multi-architecture
index digest `sha256:61beafd34111e1cb85fb49377ceadeee0a53622dbc20670ed8ca303f0e17ed9c`,
including amd64 child `sha256:9f7fd6627530115141f46c696178f45def9a0308035c868ace6c3868194e2eed`
and arm64 child `sha256:0059327e85a1ddd6cd727df5afd00cd3139680307b3346abea3f36c3bddc1dc3`.
The workflow pins that index and verifies the pulled digest and native container CPU.

Local synthetic Python tests and actionlint are required before commit. Native x64
and ARM64 package construction plus Ubuntu 24.04, Debian 13 and Fedora 44 container
installation/removal remain pending fresh CI; this checkpoint makes no signing,
publication, N→N+1, GUI, Secret Service, tray or account claim.
