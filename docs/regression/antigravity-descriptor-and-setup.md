# Antigravity Descriptor and Setup Composition

## Status and supported behavior

Internal, unregistered Step 8.c composition only. Activation remains Step 9 and managed installation remains Step 10.
There is no user-visible harness, database/wire migration, analytics event, real OAuth attempt or Google history access.

- Setup inspection is inert. It checks only the official sibling runtime filenames and isolated token-file presence; it
  does not create files, read token contents, spawn/probe a process, prepare a browser command or authenticate.
- Runtime precedence is authoritative explicit pair, then PATH, then the future managed-layout location. Empty POSIX
  PATH entries continue to mean the current directory. Static inspection does not claim a validated runtime version.
- Missing/rejected/unsupported/boundary outcomes map to honest setup statuses and current-client authentication hints.
  A recovered PATH storage failure retains its cause, stack and PATH context in local logs before managed fallback;
  ordinary absence or pair rejection remains non-error resolution. Install is not advertised and the plugin is absent
  from the bridge registry and CLI inventory.
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

Setup inspection writing state, reading token contents, launching a process, weakening explicit-path authority,
inheriting ambient credentials, opening a browser, silently authenticating, retaining stale configuration after reset,
terminating best-effort provisioning on timeout, or adding Antigravity to active inventory are regressions. Preparation
or probe timeouts preserve local diagnostics and settle as `ProvisionFailed`; explicit startup abort still propagates.

- **L1/L2:** `antigravity_profile_service_test.dart` covers read-only token-presence inspection and isolated preparation.
  `antigravity_session_options_service_test.dart` covers exact opaque fresh/existing defaults, acknowledged selection
  stamping, contradictory replies and atomic catalog/configuration reset. Shared ACP tracker coverage retains blank-as-
  absent behavior without normalizing valid opaque values.
- **L3/L4:** `antigravity_plugin_descriptor_test.dart` covers inert explicit/PATH/managed inspection, shared root store,
  sanitized profile/probe/live inputs, probe-timeout degradation, source browser-noop invocation, abort, exit
  reset/reconnect and shutdown. `antigravity_runtime_service_test.dart` covers recovered PATH storage diagnostics and
  inert managed fallback. `antigravity_plugin_test.dart` covers exact whitespace-bearing live/replay stamping and
  cold-reset resume before strict dispatch.
- **L5 Full:** real personal OAuth, native supported-target pairs, cross-target launch/permissions, bridge import and
  tombstone behavior remain later gates. Synthetic composition evidence does not replace them.
