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

## Implementation and evidence checkpoints

Current tooling stages the complete bundle below `/opt/sesori-desktop`, owns that
payload plus only the `sesori-desktop` launcher, desktop entry and 512x512 RGBA icon,
derives DEB dependencies through strict `dpkg-shlibdeps`, and leaves RPM ELF
requirements to native Fedora `rpmbuild`. It audits every package named by generated
`FLUTTER_PLUGIN_LIST` for explicit dynamic loading. Package fixtures reject lifecycle
scripts, verify bounded package ownership and root-owned staged hashes/paths, perform
an honestly named same-version reinstall, remove package-owned paths, and preserve
shared-data sentinels without launching either payload. This paragraph describes the
current implementation; it is not a claim that review-fix inputs have passed native CI.

Fedora's official `https://fedoraproject.org/releases.json` listed 42, 43 and 44 as
releases while 45 was Beta when checked on 2026-09-16. The official registry supplied
multi-architecture index digest
`sha256:61beafd34111e1cb85fb49377ceadeee0a53622dbc20670ed8ca303f0e17ed9c`.
The workflow also pins the Ubuntu 24.04 index at
`sha256:69cecf4bbf72d2d44a9eef1b71fb98c7fb973d78af11399deccef19beb008ad9`
and Debian 13 at
`sha256:f324c7ff54321e8d9c588493a20244965938ce0aa50bbd1022d38010e9ffc4b1`.
Each pull is checked against its digest and native CPU. `apt`/`dnf` repositories remain
rolling; base-image pins do not make later package dependency resolution bit-reproducible.

PR #1522 merged this private qualification, accepting
`07bdd730e6451d221ebb86821a38c4252e4e0abc` as squash
`9f9081f71995397edf39690efc212aa0920c6175` on 2026-09-16. Accepted source tree:
`3e869292f7f11eeb6356cfd56a938c3c20976239`. The accepted PR source, not the squash
commit, is the artifact-producing revision.

Final native run [35122448200](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35122448200)
passed native x64 and ARM64 jobs at that accepted source. Both jobs built DEB and RPM
packages and passed Ubuntu 24.04, Debian 13 and Fedora 44 install, same-version
reinstall and removal fixtures. The independently checked package SHA-256 values are:

| CPU | Format | SHA-256 |
|---|---|---|
| x64 | DEB | `6367ea24acf2eb2660493f0ee97a1dc23c46bd0688e67625c023f044a23105fa` |
| x64 | RPM | `c76b188d6c3df6536ed25beabe861e348a036517e43144e95739af320454afe2` |
| arm64 | DEB | `12bfcd3d35921f90422ea43dc77cbc8ecede8e069f39faef85618fe209d6ab2f` |
| arm64 | RPM | `1d2eff7f973d65d16c3136867c3fca97fb03d513e073d510b1ebee56ce713cd3` |

From this worktree root, artifacts were retrieved with `gh run download 35122448200
--repo sesori-ai/sesori_apps_monorepo --pattern 'desktop-linux-*' --dir
build/desktop-linux-packaging-evidence/native-07bdd73`. All four packages contain the
same expected 73 package payload files and 13 native ELF files for their CPU. Both
source patches are empty. Six native fixture results verify strict generated DEB
dependencies, Fedora-generated RPM ELF requirements, bounded package paths, absence
of DEB maintainer scripts/RPM scriptlets, pre-install shared-data sentinels, exact
root-owned installed payloads, same-version reinstall, removal of package-owned paths
and sentinel preservation. The retained independent summary is
`build/desktop-linux-packaging-evidence/native-07bdd73/verified-summary.json`.

Earlier failing attempts are historical CI evidence, not current unsupported-feature
markers and not regression assertions. This final run still does not establish
signing, publication, real N→N+1 update, GUI/session startup, account restoration,
Secret Service/keyring, tray, login launch, interactive desktop behavior or minimum-OS
support. No package or local GUI/helper was installed or launched on this Mac.
