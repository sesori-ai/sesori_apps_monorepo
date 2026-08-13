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
- Hermes Agent is a stock ACP v1 server: its option discovery uses the base
  single-agent synthesis (no model picker — the backend's configured model is
  authoritative), and it advertises image prompt capability so inline attachments
  are accepted.
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
  persistence effect. After validation, plugin startup and metadata generation
  run concurrently so a cold backend does not add its full startup time to naming.
- Dedicated mode creates a branch and worktree from the resolved base branch,
  rejects unsafe names, falls back to the project directory when the repository
  is absent, commitless, or creation fails, and records worktree, branch, base
  branch, and base commit; in-place mode records the HEAD commit as baseline.
- Prompt and slash-command starts are exclusive; only user-authored text is
  user-visible, and attachments appear only where declared. The session keys on
  the stable project identifier and carries title, defaults, and worktree facts.
- OMP discovers modes, commands, providers/models, and model-specific thinking
  levels in a project-scoped scratch session. Model values remain exact even
  when the model ID contains slashes, and the configured pre-sweep model remains
  the default. A rejected or partially applied selection fails before prompting.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, representative plugin: a session is created with a first prompt and has attribution and a working directory. |
| L2 Routine | Headless bridge, representative plugin: options return agents, models, commands; explicit refresh forces discovery; cache-only reports unavailable without discovering; dedicated mode produces branch, worktree, and baseline. |
| L3 Release | Client end to end (phone), every supporting production plugin: each declared option scope is honored and usable; chosen agent, model, and variant apply; slash-command start dispatches without rendering bridge context; pickers, plugin chooser, loading, and no-harness states render. |
| L4 Extended | Live plugin, every supporting production plugin: non-git, empty-repository, and worktree-failure fall back with a usable session; failure with a retained cache still serves options while failure without one errors; concurrent requests coalesce; automatic refresh does not start a stopped plugin; a moved project invalidates its options. |
| L5 Full | Client end to end, every supporting production plugin: cache expiry and an undecodable entry recover without wrong options; creation is refused for a non-routable plugin and an unknown project; attachment creation works only where declared; unattributed payloads resolve to the historical identity. |

## Exploration Guidance

Vary plugin choice, warm cache versus fresh discovery, dedicated versus in-place
mode, prompt versus command start, default versus explicit options, and fresh,
collision-prone, or non-git projects.

## Failure Signals

- Options are empty or stale where a discovery failure should be an explicit
  error, or a partial observation overwrites a complete cache.
- A cache-only read starts a backend, or automatic refresh wakes a stopped one.
- Recorded worktree, branch, base branch, or base commit disagrees with git.
- Bridge-owned context renders as the user's own message or command arguments.
- Creation succeeds for a non-routable plugin or unknown project.

## Known Limitations

- Client end-to-end coverage is phone-only; the desktop shell cannot create.
- Prompt attachments are capability-gated, so absence is expected, not failure.
- Only plugins registered in the build under test count.

## Sources

- Bridge: `bridge/app/lib/src/bridge/services/` (session creation, options,
  worktree), the create-session and options handlers, and their tests
- OMP: `bridge/sesori_plugin_omp/lib/src/services/` and package tests
- Contract:
  `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart`
- Client: `client/module_core/lib/src/services/new_session_options_service.dart`
- Plans (discovery only): `.plan/completed/multi-plugin-release-prep`,
  `setup-aware-plugin-lifecycle`
