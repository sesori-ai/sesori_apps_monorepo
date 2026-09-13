# Antigravity Runtime Activation

## Status and supported behavior

Registered local and managed-runtime support. Antigravity appears through the existing generic plugin inventory under
its plugin-owned opaque ID. This activation adds no database/wire migration or analytics event and its verification
performs no real OAuth or Google history access. For user/operator instructions and the consolidated supported-runtime
contract, see [Google Antigravity in Sesori](../ANTIGRAVITY.md).

- Shared client harness presentation shows Antigravity's official full-colour mark in both themes and the display
  name `Antigravity`. Asset provenance lives in `client/module_prego/BRAND_ASSETS.md`; brand-logo widget tests cover
  bundled image loading, sizing and decorative semantics. Harness behavior still uses the opaque plugin ID.
- Setup inspection is bounded and inert. It checks the official sibling filenames, runs only the selected server's
  `--version` command with a ten-second budget in the sanitized false-inheritance environment, and reads isolated
  token-file presence without reading token contents. It does not create files, initialize ACP, prepare a browser
  command or authenticate.
- Runtime precedence is authoritative explicit pair, then PATH, then the installed managed-layout location. Empty POSIX
  PATH entries continue to mean the current directory; Windows pair scans and executable-presence checks both inspect
  the working directory before PATH and trim/unquote PATH entries when PATH is supplied. A missing PATH value never
  consults ambient working-directory state. Managed selection requires both a missing PATH server candidate and separate
  physical-absence evidence mapped through storage and repository layers. A harness-only directory does not shadow a
  later server pair, but harness-only, incomplete, broken, unreadable or invalid final PATH evidence remains
  authoritative. The current exact pair is package `1.1.1` / server `agy_acp_server_1.1.1`, ACP 1.
  Only that byte-exact label reports ready; equal-precedence labels remain unknown. Documented pre-semver official
  labels order below that pin, while newer official semantic versions remain incompatible/unknown. Outdated or
  PATH-authoritative and non-repairable managed unknown setup use an install-blocked marker; the dedicated
  managed-repair marker retains Install after a repairable managed probe failure.
  Explicit pairs never fall through to managed.
- Missing/rejected/unsupported/boundary outcomes map to honest setup statuses and current-client authentication hints.
  macOS x64 reports unsupported-platform guidance without constructing a managed filename, preparing a profile or
  launching a process, including when an explicit binary option is supplied.
  A PATH storage failure retains its cause, stack and PATH context in local logs and blocks managed fallback. Version
  API failures likewise retain their original cause and stack in the repository-domain outcome without crossing the
  wire. Only verified server absence may select the managed pair; pair rejection and a missing sibling remain
  non-error but authoritative. Install is advertised only without an explicit
  override on macOS arm64, Linux x64/arm64 and Windows x64/arm64; macOS x64 remains unsupported. Eligible missing or
  invalid PATH/managed setup guidance discloses the proprietary Google download and provides terms/documentation URLs.
  The overview download icon opens detail; detail keeps that guidance visible before the explicit Install button. The
  app registry exposes `Antigravity` and namespaces the descriptor's bare `bin` option as `--antigravity-bin`; OpenCode
  remains the preferred default.
- Linux installation checks `unzip -Z -h` for Info-ZIP/ZipInfo support before creating the download client or staging
  files. A missing/incompatible extractor or preflight failure reports package-installation guidance locally and to the
  client without downloading the archive. The command is bounded; abort is observed before and after it. Setup inspection
  remains inert. macOS and Windows retain their existing extraction paths.
- Provisioning and start prepare the same isolated profile before exact runtime probing. Every profile helper, probe and
  live ACP process receives the sanitized environment with parent inheritance disabled. No ambient Google/Gemini
  credential or browser override reaches those processes.
- Authentication and live preparation receive scopes from the same plugin-root `HostJsonStore`, retaining its atomic
  lock owner. Browser suppression invokes the backend-neutral `--internal-browser-noop` entrypoint; there is no CLI,
  hidden-login or host-browser fallback. Callback HTTP construction is explicitly injected; production deliberately
  uses `HttpClient.new`, while tests cannot fall through to a real loopback client.
- The descriptor reuses the existing ACP bridge lifecycle. Agent exit resets the connection and pending state, lazy
  reconnect re-arms the existing exit watch, and shutdown awaits process cleanup. No second manager or lock is added.
- The existing ACP configuration tracker is shared by options and the event mapper. Fresh sessions establish process
  defaults plus their session override; load/resume establish only a session override. Successful acknowledged model
  changes stamp that session. Valid opaque model IDs remain byte-for-byte exact, including surrounding whitespace.
  Connection reset clears both catalog and configuration state before residency restores the selected session, and
  live/replay messages use the same restored model/provider metadata.
- Known catalogs reject stale explicit models before queue admission. An absent catalog after reset permits admission;
  real resume/load restores the catalog and strict validation still happens before model/mode/prompt dispatch.

## Failure signals and coverage

Setup inspection writing state, reading token contents, launching anything except bounded `--version`, initializing ACP,
weakening PATH or explicit-pair authority, inheriting ambient credentials, opening a browser, silently authenticating,
retaining stale configuration after reset,
terminating best-effort provisioning on timeout, or omitting Antigravity from inventory are regressions. Advertising
managed install with an explicit override or on macOS x64, first installation without an explicit action,
or replacing generic client behavior with Antigravity-specific logic is also a regression. Existing Sesori-managed runtimes may
upgrade at bridge start. Preparation or probe timeouts
preserve local diagnostics and settle as `ProvisionFailed`; explicit startup abort still propagates.

- **L1/L2:** app `plugin_registry_test.dart` and `run_command_catalog_import_test.dart` cover the exact registered ID,
  display name, plugin-owned identity, current-target management capabilities, OpenCode default, inert
  declaration and namespaced CLI option. `antigravity_plugin_descriptor_test.dart` owns target/override gating.
  Active-runtime descriptor/authentication tests use a synthetic current-release initialize fixture; the historical
  `1.0.0` capture remains a decoder observation, not evidence that the old runtime identity is currently accepted.
  Client `harnesses_settings_screen_test.dart` covers overview-to-detail navigation without an install request and
  visible missing/invalid-runtime guidance before explicit installation. `antigravity_runtime_manifest_test.dart` covers the official five-target
  assets, checksums, package-directory layout, conservative two-minute archive-command budget, version directory and
  macOS x64 omission. `antigravity_profile_service_test.dart` covers read-only token-presence inspection and isolated
  preparation. `antigravity_session_options_service_test.dart` covers exact opaque fresh/existing defaults, acknowledged
  selection stamping, contradictory replies and atomic catalog/configuration reset. Shared ACP tracker coverage retains
  blank-as-absent behavior without normalizing valid opaque values.
- **L3/L4:** `antigravity_plugin_descriptor_test.dart` covers inert explicit/PATH/managed inspection, shared root store,
  sanitized setup/profile/probe/live inputs, PATH-pair authority, typed legacy/semantic version ordering, the short
  setup-probe budget, exact-label readiness, and version metadata through profile failure,
  managed capability/override/failure behavior, Linux extractor preflight failure, abort and download ordering, source
  browser-noop invocation, abort, exit reset/reconnect and shutdown. The API, version-repository, setup-service, managed
  authority and runtime-service suites cover inert version parsing, domain mapping, physical absence, PATH diagnostics,
  and managed fallback. `antigravity_plugin_test.dart` covers exact
  whitespace-bearing live/replay stamping and cold-reset resume before strict dispatch.
- **L5 Full:** the package `1.1.1` managed macOS arm64 pipeline has run against independently hashed official bytes in
  disposable state, preserving both siblings and completing isolated initialize-only validation/cleanup before result.
  Native Linux/Windows managed installs, real personal OAuth, cross-target launch/permissions, bridge import and
  tombstone behavior remain unverified. Automated registration/composition evidence does not replace them.
