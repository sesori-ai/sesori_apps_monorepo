# Session Creation And Options

## Capability

Starting a new session: discovering the options a plugin offers for a project
(agents, providers/models, slash commands), choosing plugin, agent, model,
variant, and worktree mode, and creating the session with its first input.

## Required Behavior

- Options are discovered per plugin and cached under the plugin's declared
  coherence scope; retention and replacement are bridge-owned.
- Claude's plugin-scoped discovery runs in its host-created state directory,
  never a selected project or the bridge process's launch directory. This keeps
  its global option probe on a valid, stable path when projects move or disappear.
- Read intents stay distinct: a normal load may serve a valid cache or discover,
  a cache-only read never discovers and reports cache-unavailable, and an
  explicit refresh forces fresh discovery.
- Concurrent requests coalesce; an incomplete observation never replaces a
  complete cached one, and a moved project invalidates its entries.
- Failure with a valid cache still serves it; failure without one is an explicit
  error, never an empty option set. Automatic refresh never starts a stopped
  backend and no-ops for a superseded generation.
- Creation resolves and validates the project handle before checking plugin
  routability, so an unknown project causes no plugin, metadata, git, or session
  persistence effect. Plugin startup, git/worktree preparation, backend creation,
  durable binding, first-input acceptance, and slash-command acceptance remain
  synchronous. Metadata starts only after those gates and does not delay the
  canonical, immediately queryable session response.
- Dedicated mode creates a branch and worktree from the resolved base branch
  using a bridge-generated lowercase `color-animal` name. It checks both branch
  and filesystem-path occupancy across three distinct pairs, then makes bounded
  attempts with a secure hexadecimal suffix. It falls back to the project
  directory when the repository is absent, commitless, or creation fails, and
  records worktree, branch, base branch, and base commit; in-place mode records
  the HEAD commit as baseline.
- Prompt and slash-command starts are exclusive; only user-authored text is
  user-visible, and attachments appear only where declared. The session keys on
  the stable project identifier and carries title, defaults, and worktree facts.
- A backend creation title may appear in the initial response; otherwise the
  title stays missing until generated metadata succeeds. Generated title is a
  conditional bridge-owned update delivered through the existing
  `session.updated` event. User rename or deletion wins, and plugin rename
  failure does not remove the locally committed generated title.
- Graceful shutdown fences new create routes, aborts and drains accepted metadata
  work, drains session operations and local mutations, then closes normalized
  event delivery and its remaining tails.
- OMP discovers modes, commands, providers/models, and model-specific thinking
  levels in a project-scoped scratch session. Model values remain exact even
  when the model ID contains slashes, and the configured pre-sweep model remains
  the default. A rejected or partially applied selection fails before prompting.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, representative plugin: a session is created with a first prompt and has attribution and a working directory. |
| L2 Routine | Headless bridge, representative plugin: options return agents, models, commands; explicit refresh forces discovery; cache-only reports unavailable without discovering; dedicated mode produces a local lowercase `color-animal` branch, worktree, and baseline; a gated metadata request does not gate a queryable create response. |
| L3 Release | Client end to end (phone), every supporting production plugin: each declared option scope is honored and usable; chosen agent, model, and variant apply; slash-command start dispatches without rendering bridge context; generated title arrives through `session.updated`; pickers, plugin chooser, loading, and no-harness states render. |
| L4 Extended | Live plugin, every supporting production plugin: occupied branch/path pairs are skipped and pair exhaustion uses a suffix; non-git, empty-repository, worktree-failure, metadata-failure, and plugin-title-rename-failure cases retain a usable session; user rename/deletion wins over late title; failure with a retained cache still serves options while failure without one errors; concurrent requests coalesce; automatic refresh does not start a stopped plugin; a moved project invalidates its options. |
| L5 Full | Client end to end, every supporting production plugin: cache expiry and an undecodable entry recover without wrong options; creation is refused for a non-routable plugin and an unknown project; attachment creation works only where declared; unattributed payloads resolve to the historical identity. |

## Exploration Guidance

Vary plugin choice, warm cache versus fresh discovery, dedicated versus in-place
mode, prompt versus command start, default versus explicit options, and fresh,
collision-prone, or non-git projects. Also vary fast, slow, failed, and
shutdown-aborted metadata, plus user rename/deletion while title generation is
in flight.

## Failure Signals

- Options are empty or stale where a discovery failure should be an explicit
  error, or a partial observation overwrites a complete cache.
- A cache-only read starts a backend, or automatic refresh wakes a stopped one.
- Recorded worktree, branch, base branch, or base commit disagrees with git.
- A dedicated workspace name comes from generated metadata, is not lowercase
  `color-animal` form, or collides with an existing branch or path.
- Bridge-owned context renders as the user's own message or command arguments.
- Creation succeeds for a non-routable plugin or unknown project.
- Metadata completion delays the create response, creates an unqueryable session,
  overwrites a user title, resurrects a deletion, or loses the local title when
  backend rename fails.

## Known Limitations

- Client end-to-end coverage is phone-only; the desktop shell cannot create.
- Prompt attachments are capability-gated, so absence is expected, not failure.
- Only plugins registered in the build under test count.

## Sources

- Bridge: `bridge/app/lib/src/api/sesori_server_api.dart`,
  `bridge/app/lib/src/repositories/session_metadata_repository.dart`,
  `bridge/app/lib/src/bridge/services/` (session creation, mutation, events,
  options, worktree), the create-session and options handlers, and their tests
- OMP: `bridge/sesori_plugin_omp/lib/src/services/` and package tests
- Contract:
  `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart`
- Client: `client/module_core/lib/src/services/new_session_options_service.dart`
- Plans (discovery only): `.plan/completed/multi-plugin-release-prep`,
  `setup-aware-plugin-lifecycle`
