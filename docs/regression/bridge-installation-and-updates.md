# Bridge Installation And Updates

## Capability

Getting the bridge onto a machine and keeping it current: the installers, the npm
bootstrap, the managed install, the release track, and self update with its startup
reconciliation, periodic check, in-place apply, and explicit update command.

## Required Behavior

- Installers and the npm bootstrap produce the same managed install, expose the
  `sesori-bridge` launcher, and report the version; installers take the newest
  non-prerelease release carrying the platform archive and its basename-keyed checksum
  manifest, and verify artifacts before installing them.
- The npm package is bootstrap-only: it installs or refreshes the managed runtime and
  points at the managed launcher. Direct execution from an npm payload is unsupported,
  its removal leaves the managed install, and full uninstall is manual.
- Auto-update applies only to a managed install and is skipped for supervised runs, npm
  payloads, CI, and the opt-out. Managed installs check at startup and poll periodically;
  a poll only reports availability and the update activates at next start. Its track is
  stable by default, internal also takes pre-releases, and a change applies after restart.
- Applying happens in place under a cross-process lock with a durable attempt record and
  log, and can roll back; startup reconciliation is local and network-free, reports the
  prior attempt, sweeps residue, and never fails startup.
- The update command moves to the newest release on the track and exits, with force
  reinstalling the current version and able to return an internal build to stable.
  Transient outages retry quietly; real failures give reinstall guidance.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. Distribution work is expensive and is not a per-run heartbeat. |
| L2 Routine | Update-skip policy and startup reconciliation on a non-managed run: a build-tree or opted-out bridge neither rewrites itself nor fails startup, and reconciliation is silent with no pending attempt. Headless bridge; no plugin. |
| L3 Release | The release artifact set and checksum manifest for the tag are complete and basename-keyed, and a managed install on the release-target bridge host reports the expected version and starts. Packaged or external. |
| L4 Extended | Interrupted or failed apply reconciled at next start, rollback, refused checksum mismatch, unavailable release service staying quiet, track switch, periodic check without applying, and an alternate bridge host. Packaged or external for the install; headless bridge for policy. |
| L5 Full | Both installers and the npm bootstrap on every supported platform and architecture, the npm fallback to the tagged release asset, an end-to-end upgrade from a prior release on both tracks, the update command including force, and the documented uninstall contract. Packaged or external. |

## Exploration Guidance

Vary the entry path: hosted installer, local script, npm bootstrap. Vary the starting
state: no install, older managed install, same-version install, internal build returning
to stable. Vary the interruption point: during download, between staging and apply, or
after apply. Use a throwaway machine when mutating an install root.

## Failure Signals

- An installer selecting a pre-release, a release missing or mis-keying its manifest, or
  an artifact installed without verification.
- Auto-update running for a supervised run, npm payload, CI, or opted-out process, or a
  managed install never checking at all.
- An apply without the lock, a swap leaving a mixed-version install, residue surviving
  reconciliation, or reconciliation doing network work or failing startup.
- The npm package presenting itself as the long-lived runtime, its removal deleting the
  managed install, or a transient outage reported as hard failure.

## Known Limitations

- Genuine distribution claims need real published artifacts; a local build proves policy
  and reconciliation only, and signing is verifiable only against CI-produced binaries.
- The bootstrap and the updater share no lock; an apply-window collision is accepted.
- Windows keeps a running binary's backup until the next launch, so chained applies
  differ by design.

## Sources

- `bridge/RELEASING.md`, `bridge/INSTALL.md`, `install.sh`, `install.ps1`, `app/npm/`
- `bridge/app/lib/src/updater/` policy, track, lock, repositories, services;
  `bridge/app/bin/bridge.dart` (`update`, `config track`)
- Tests: `bridge/app/test/updater/`, notably policy and release-contract suites
