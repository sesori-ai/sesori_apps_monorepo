# Plugin Runtime Installation

## Capability

Installing a harness's pinned, bridge-managed runtime — on request from the app or the
management API when it reports its runtime as missing or too old, and automatically on
bridge start when Sesori already manages an older version.

## Required Behavior

- Install is offered only where the bridge advertises the capability for that harness in
  its configuration and platform; a binary override or a platform with no pinned asset
  removes the offer. The app offers it only for a missing or too-old runtime, never for
  ready, authentication-required, or unknown states.
- Artifact installation writes the pinned version into the harness's own managed state
  area; placement preserves a published bare executable, an archived executable, or its
  required package directory, never installs system-wide, touches files elsewhere, or starts the backend.
  OMP selects its official Linux glibc or musl executable from bounded Alpine-marker and
  `ldd` evidence; macOS and Windows use direct target mapping, and Windows arm64 remains unsupported.
  Pi installs its complete official package tree on all six published targets and keeps the
  `pi`/`pi.exe` entry beside its assets, native modules, and package metadata.
  Codex installs its canonical package tree on all six targets, preserving
  `bin/codex` (or `bin/codex.exe`), the adjacent `codex-code-mode-host`, and the
  package's runtime resources as one checksum-verified unit.
  DeepSeek likewise installs its complete adapter package on macOS, Linux, and
  Windows for arm64 and x64. Its launcher remains beside the bundled Node runtime
  and package tree, so installation never depends on system Node or npm.
  GitHub Copilot installs the official bare `copilot`/`copilot.exe` from exactly
  six arm64/x64 macOS, Linux, and Windows archives for the pinned release.
  Artifacts are checksum-verified, and no partial binary or package is adopted.
- The command is accepted immediately because an install can outlast a request budget;
  progress reports phases with a percentage, and the terminal outcome also lands in the
  management snapshot.
- Success then implies enable: the harness is persisted enabled, setup is re-inspected,
  and the post-install enable phase starts it when ready. A still-blocked setup is
  reported honestly, and failure text sent to the client is sanitized while paths and
  command output stay in the log.
- A duplicate request joins the running install, another command for the same harness
  conflicts, and a shutdown mid-install ends it as interrupted so a retry redoes it.
- A bridge start upgrades every eligible harness that still has a Sesori-managed version
  directory other than the pinned target, and only those: a machine with no managed
  runtime keeps the explicit Install action and never downloads one unasked. The trigger
  runs after single-live-bridge ownership is settled and returns without waiting, so
  startup is never delayed by a download. Each upgrade occupies the harness's command
  slot exactly like a manual install, so an overlapping request joins it and another
  command conflicts. An explicit Install that joins a running upgrade carries the user's
  intent with it: the joined install enables and starts the harness on success, even
  though the upgrade alone would not have.
- A managed version at or above the harness's minimum stays selectable and startable
  while the target downloads; below the minimum it is never selected. Unlike a manual
  install, a startup upgrade re-inspects but never starts a harness, so a blocked harness
  becomes ready and selectable without a bridge restart and a running one keeps its
  current generation until it stops.
- Cleanup follows what is still usable. A below-minimum version directory is removed
  before the download begins, because it can never be selected either way. A superseded
  but still supported one survives until the pinned version is installed and verified,
  and is kept when the harness has a live generation; a later install reclaims it.
- A failed upgrade changes nothing: an older supported runtime stays selected and ready,
  and a harness whose only managed runtime was below the minimum stays runtime-missing
  with its install hint. Failure detail stays in the bridge log.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. Installation is a deliberate network-bound action, not a heartbeat. |
| L2 Routine | Capability declaration is honest for every registered harness on the release-target bridge host: those with a pinned asset and no override advertise install and automatic upgrade, the rest do neither. A start with no managed version directory triggers no upgrade. Automated manifest coverage includes Codex's and Copilot's exact six platform/architecture mappings and digests, plus preservation of nested package entries and sibling resources. Headless bridge; every supporting production harness. |
| L3 Release | One complete install on the release-target bridge host from missing runtime through verification and extraction to enabled, re-inspected, and selectable, with progress shown on the release-target client platform. Plus a start with a raised target over an older supported managed version: the harness stays selectable throughout, startup does not block, and the new version is used by the next generation; and over a below-minimum version: the harness is blocked briefly, then becomes selectable without a bridge restart or an Install press. Client end to end; every harness advertising install. |
| L4 Extended | Checksum mismatch or interrupted download failing safely, shutdown mid-install, duplicate join, competing-command rejection, authentication-required outcome, too-old runtime, and an alternate bridge host. An Install pressed while a startup upgrade downloads, which joins it and still leaves the harness enabled and started. A forced upgrade failure over each of an older supported and a below-minimum version, leaving the documented fallback state. A session running on the older supported runtime during an upgrade continuing uninterrupted, with its version directory surviving until the generation stops and the next start resolving the pinned version. Live plugin for bridge outcome, client end to end for card state. |
| L5 Full | Install on every supported platform and architecture where the harness publishes an asset, a superseded managed version swept after success, and pinned digests matching the upstream release assets. Copilot's complete matrix is its six official arm64/x64 macOS, Linux, and Windows archives. Packaged or external, since real upstream artifacts are part of the claim. |

## Exploration Guidance

Vary the starting state: no runtime, a superseded but still supported managed runtime, a
below-minimum managed runtime, the pinned version already installed, a too-old runtime on
the path, and a previously disabled harness. Vary the trigger between the app, the
management API, and a bridge start; whether the harness is running, idle, or blocked when
an upgrade completes; whether another harness is busy; and the interruption point during
download, verification, or placement. Use a disposable data directory.

## Failure Signals

- Install offered where it cannot apply, or hidden where it genuinely can.
- Anything written outside the managed state area, a system-wide install, or an
  unverified or partly extracted binary adopted.
- The request blocking on the download, progress stalling or moving backwards, a busy
  state that never clears, or a duplicate request starting a second install.
- A completed install leaving the harness disabled, not re-inspected, or unselectable
  while reporting success, a Codex install missing `codex-code-mode-host` or package
  resources, or raw paths and command output reaching the client.
- Bridge startup blocking on an upgrade download, an upgrade running for a harness with no
  managed runtime directory or an explicit binary override, or a startup upgrade starting
  a harness the user had not enabled.
- An Install pressed while an upgrade is downloading reporting success but leaving the
  harness stopped.
- A failed install taking the bridge process down instead of failing that one harness.
  An unwritable managed runtime directory, a read-only volume, or a disk that fills
  mid-download must end as a reported failure with every other harness untouched.
- A superseded but still supported runtime removed before its replacement is verified, or
  removed while a generation is running from it; a below-minimum directory still present
  once a download has begun.
- A harness dropping out of the selectable set while its upgrade downloads, or a
  below-minimum harness staying blocked after a successful upgrade until the bridge is
  restarted.
- A failed upgrade downgrading a harness that was ready on an older supported runtime, or
  its failure detail reaching the client instead of the log.

## Known Limitations

- Only harnesses declaring the capability with a pinned per-platform asset can install; a
  registered harness without one is correctly not installable.
- Backend authentication is out of scope; an install may end needing a machine-local
  login, and it never supersedes a configured binary path. Copilot authentication remains
  an out-of-band `copilot login`, supported token environment, or BYOK configuration.
- Pinned digests are release-engineering state, checked upstream externally.
- The upgrade replaces only a runtime Sesori already manages; a harness that has never
  been installed through Sesori still needs the explicit Install action. A user who runs
  a PATH install and also has a stale managed directory downloads one target they do not
  run, once per target bump.
- There is no hot swap: a generation started on the older supported runtime keeps it until
  it stops. A harness that is running when its upgrade completes keeps that version
  directory until a later install reclaims it.
- A below-minimum upgrade whose download fails does not retry on the next start, because
  its obsolete directory was already removed; the harness stays runtime-missing until the
  user presses Install.
- The trigger is bridge start only. There is no periodic or relay-driven update check, and
  a headless startup upgrade shows no console progress — the log records start, outcome,
  and failure detail.

## Sources

- `bridge/sesori_plugin_interface/.../bridge_plugin_descriptor.dart`,
  `bridge/sesori_plugin_runtime/lib/src/provisioning/`, OpenCode, Codex, Cursor, Pi, and OMP manifests
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`,
  `bridge/app/lib/src/runtime/plugin_registry.dart`,
  `bridge/app/lib/src/runtime/plugin_runtime.dart`,
  `bridge/app/lib/src/runtime/bridge_runtime_runner.dart`,
  `bridge/sesori_plugin_deepseek/lib/src/runtime/deepseek_runtime_manifest.dart`,
  `bridge/sesori_plugin_copilot/lib/src/runtime/copilot_runtime_manifest.dart`
- `client/module_core/.../plugin_management_service.dart`,
  `client/app/lib/features/settings/harnesses_settings_screen.dart`
- Tests: `bridge/app/test/services/plugin_lifecycle_service_test.dart`, per-plugin
  descriptor tests, client management and harness suites
