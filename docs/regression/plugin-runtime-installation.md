# Plugin Runtime Installation

## Capability

Installing a harness's pinned, bridge-managed runtime on request, from the app or the
management API, when it reports its runtime as missing or too old.

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

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. Installation is a deliberate network-bound action, not a heartbeat. |
| L2 Routine | Capability declaration is honest for every registered harness on the release-target bridge host: those with a pinned asset and no override advertise install, the rest do not. Headless bridge; every supporting production harness. |
| L3 Release | One complete install on the release-target bridge host from missing runtime through verification and extraction to enabled, re-inspected, and selectable, with progress shown on the release-target client platform. Client end to end; every harness advertising install. |
| L4 Extended | Checksum mismatch or interrupted download failing safely, shutdown mid-install, duplicate join, competing-command rejection, authentication-required outcome, too-old runtime, and an alternate bridge host. Live plugin for bridge outcome, client end to end for card state. |
| L5 Full | Install on every supported platform and architecture where the harness publishes an asset, a superseded managed version swept after success, and pinned digests matching the upstream release assets. Packaged or external, since real upstream artifacts are part of the claim. |

## Exploration Guidance

Vary the starting state: no runtime, a too-old managed runtime, a too-old runtime on the
path, and a previously disabled harness. Vary the trigger between the app and the
management API, whether another harness is busy, and the interruption point during
download, verification, or placement. Use a disposable data directory.

## Failure Signals

- Install offered where it cannot apply, or hidden where it genuinely can.
- Anything written outside the managed state area, a system-wide install, or an
  unverified or partly extracted binary adopted.
- The request blocking on the download, progress stalling or moving backwards, a busy
  state that never clears, or a duplicate request starting a second install.
- A completed install leaving the harness disabled, not re-inspected, or unselectable
  while reporting success, or raw paths and command output reaching the client.

## Known Limitations

- Only harnesses declaring the capability with a pinned per-platform asset can install; a
  registered harness without one is correctly not installable.
- Backend authentication is out of scope; an install may end needing a machine-local
  login, and it never supersedes a configured binary path.
- Pinned digests are release-engineering state, checked upstream externally; refresh of
  an installed managed runtime is not covered here.

## Sources

- `bridge/sesori_plugin_interface/.../bridge_plugin_descriptor.dart`,
  `bridge/sesori_plugin_runtime/lib/src/provisioning/`, OpenCode, Codex, Cursor, Pi, and OMP manifests
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`,
  `bridge/app/lib/src/runtime/plugin_registry.dart`
- `client/module_core/.../plugin_management_service.dart`,
  `client/app/lib/features/settings/harnesses_settings_screen.dart`
- Tests: `bridge/app/test/services/plugin_lifecycle_service_test.dart`, per-plugin
  descriptor tests, client management and harness suites
