# Antigravity Local Runtime Activation

## Status and supported behavior

Registered local-runtime support. Antigravity appears through the existing generic plugin inventory under its
plugin-owned opaque ID, while managed installation remains a later gate. This activation adds no database/wire
migration or analytics event and its synthetic verification performs no real OAuth or Google history access.

- Setup inspection is inert. It checks only the official sibling runtime filenames and isolated token-file presence; it
  does not create files, read token contents, spawn/probe a process, prepare a browser command or authenticate.
- Runtime precedence is authoritative explicit pair, then PATH, then the future managed-layout location. Empty POSIX
  PATH entries continue to mean the current directory. Static inspection does not claim a validated runtime version.
- Missing/rejected/unsupported/boundary outcomes map to honest setup statuses and current-client authentication hints.
  Install is not advertised. The app registry exposes `Antigravity` and namespaces the descriptor's bare `bin` option
  as `--antigravity-bin`; OpenCode remains the preferred default.
- Provisioning and start prepare the same isolated profile before exact runtime probing. Every profile helper, probe and
  live ACP process receives the sanitized environment with parent inheritance disabled. No ambient Google/Gemini
  credential or browser override reaches those processes.
- Authentication and live preparation receive scopes from the same plugin-root `HostJsonStore`, retaining its atomic
  lock owner. Browser suppression invokes the backend-neutral `--internal-browser-noop` entrypoint; there is no CLI,
  hidden-login or host-browser fallback.
- The descriptor reuses the existing ACP bridge lifecycle. Agent exit resets the connection and pending state, lazy
  reconnect re-arms the existing exit watch, and shutdown awaits process cleanup. No second manager or lock is added.
- The existing ACP configuration tracker is shared by options and the event mapper. Fresh sessions establish process
  defaults plus their session override; load/resume establish only a session override. Successful acknowledged model
  changes stamp that session. Connection reset clears both catalog and configuration state before residency restores
  the selected session, and live/replay messages use the same restored model/provider metadata.
- Known catalogs reject stale explicit models before queue admission. An absent catalog after reset permits admission;
  real resume/load restores the catalog and strict validation still happens before model/mode/prompt dispatch.

## Failure signals and coverage

Setup inspection writing state, reading token contents, launching a process, weakening explicit-path authority,
inheriting ambient credentials, opening a browser, silently authenticating, retaining stale configuration after reset,
or omitting Antigravity from inventory are regressions. Advertising managed install before its pinned implementation,
adding a shared `Harness` case, or replacing the generic client presentation is also a regression.

- **L1/L2:** app `plugin_registry_test.dart` and `run_command_catalog_import_test.dart` cover the exact registered ID,
  display name, plugin-owned identity, local-only management capabilities, OpenCode default, inert declaration and
  namespaced CLI option. `antigravity_profile_service_test.dart` covers read-only token-presence inspection and isolated
  preparation. `antigravity_session_options_service_test.dart` covers fresh/existing defaults, acknowledged selection
  stamping, contradictory replies and atomic catalog/configuration reset.
- **L3/L4:** `antigravity_plugin_descriptor_test.dart` covers inert explicit/PATH/managed inspection, shared root store,
  sanitized profile/probe/live inputs, source browser-noop invocation, abort, exit reset/reconnect and shutdown.
  `antigravity_plugin_test.dart` covers composed live/replay stamping and cold-reset resume before strict dispatch.
- **L5 Full:** real personal OAuth, native supported-target pairs, cross-target launch/permissions, bridge import and
  tombstone behavior remain pending gates. Synthetic registration/composition evidence does not replace them.
