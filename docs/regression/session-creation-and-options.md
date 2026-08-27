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
- Claude's catalog drops the CLI's own `default` model entry and names the
  selection instead: Opus is the default model and `high` the default effort, so
  every picker entry states what will actually run.
- No picker offers an unnamed "Default" option. Plugins declare effort variants
  default-first, and a model that offers variants always has one selected: the
  agent's declared variant when valid, otherwise the first available. Selecting a
  variant is therefore a switch between named levels, never a reset to unset.
- After a new session and its first prompt or command are accepted, the bridge
  remembers the complete agent, model, and effort selection per plugin. The next
  New Session screen uses it as the prefill across projects for that plugin after
  validating every value against the current catalog; removed values fall back to
  current plugin defaults. A failed creation never replaces the remembered
  selection. Preference read/write failures stay observable locally but never hide
  usable options or turn an already-created session into a retryable failure.
- Hermes Agent seeds its configured model and provider from `hermes status`,
  then discovers the available model catalog in a separate empty ACP session
  before the user creates one. The discovery process must exit before Sesori
  deletes that exact persisted Hermes session; failed cleanup fails discovery
  rather than caching a catalog that left a known artifact. Reuse is
  process-scoped, explicit refresh creates a fresh probe, and a failed first
  probe retains the configured-model fallback. Picker IDs remain the exact
  Hermes values accepted by `session/set_model`, including named custom
  providers, and a selected model is applied before the turn. Hermes also
  advertises image prompt capability so inline attachments are accepted.
- DeepSeek exposes one primary agent plus provider-grouped models, exact
  reasoning variants, and commands from `deepseek/catalog`. Model identifiers
  remain opaque even when upstream provider/model names contain slashes or
  Unicode. Sound providers survive bounded peer failures as a partial result;
  total provider failure is explicit so bridge-owned cache retention applies.
  The plugin writes `deepseek.model` and then `deepseek.reasoning_effort`
  before prompt dispatch, fails closed on either rejection, and records the
  selected identity only after every requested write succeeds. Catalog reads use
  the connected adapter without creating a session or model request; selection
  is session-local and never writes normal `DSH_HOME` settings.
- Read intents stay distinct: a normal load may serve a valid cache or discover,
  a cache-only read never discovers and reports cache-unavailable, and an
  explicit refresh forces fresh discovery.
- A normal load reports whether the cache it served has aged past the bridge's
  freshness window, and the client then refreshes it in the background: the
  options stay on screen and usable, with no loading state, and simply change if
  the backend's answer did. The failure fallback never reports staleness, so a
  failed refresh is not retried at once.
- One background refresh runs per selection, and an explicit refresh joins it
  rather than discovering twice. It joins only a refresh that can still deliver:
  one belonging to a superseded selection, or to options the user has since
  edited, is left behind and the press starts its own.
- A choice made while a background refresh runs outranks it. The refresh was
  resolved against the agent, model, variant, and staged command as they stood
  when it started, so it is dropped rather than reverting the user.
- The refresh action stays on screen for as long as the press it started is
  still running, and the line explaining where the options came from keeps
  describing the options still on screen. It spins only while the answers on
  screen are unsettled: the harness chooser stays live during a refresh, so a
  press abandoned for another harness must not leave a spinner over that
  harness's settled options.
- It is one action under one name in every state. Whether a press repeats
  harness discovery, the project check, or the options themselves is decided
  behind it; the surface never names that split, because the user cannot act on
  it and the line above the composer already says what is missing.
- Concurrent requests coalesce; an incomplete observation never replaces a
  complete cached one, and a moved project invalidates its entries. Rejected-selection
  invalidation keeps its epoch checks before serving or committing, so a retained
  snapshot invalidated during discovery is not served once.
- Backend notifications use scoped event domains: Codex skill changes emit a
  command-catalog invalidation rather than project activity, while MCP startup
  changes remain MCP-tool events.
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
- Send immediately replaces the composer with detail-shaped launch status while
  the unresolved URI remains `/projects/<projectId>/sessions/new`. Duplicate Send
  is blocked. Back leaves creation running, and success replaces the route only
  when that launch route is still current and the returned session is durable.
- A creation failure on the still-current route restores the exact submitted
  text/voice spans, command intent, and memory-only attachment identities once,
  and warns that manual resend can duplicate a session because response loss
  cannot prove the bridge did not commit. It never auto-resends. Failure after
  leaving the route does not repopulate shared composer state.
- Attachment-bearing creation yields incrementally while encoding attachment
  base64, inner request JSON, and outer relay-envelope JSON/UTF-8. Maximum-size
  input preserves the exact wire payload without copying attachment buffers to
  an isolate or blocking launch rendering.
- A backend creation title may appear in the initial response; otherwise the
  title stays missing until generated metadata succeeds. Generated title is a
  conditional bridge-owned update delivered through the existing
  `session.updated` event. User rename or deletion wins, and plugin rename
  failure does not remove the locally committed generated title.
- Generated metadata may also rename a root dedicated session's still-current
  initial branch when it has no upstream or matching remote ref. The worktree
  directory and plugin working path remain unchanged. Generated refs are validated, collisions use a
  bounded secure suffix, durable and current branch facts commit together, and
  the existing `session.updated` event reports the result without claiming a
  title change. Switched, detached, published, invalid, and failed refinements
  retain the usable initial branch; persistence failure attempts Git rollback.
- Graceful shutdown fences new create routes, aborts and drains accepted metadata
  work, drains session operations and local mutations, then closes normalized
  event delivery and its remaining tails.
- OMP discovers modes, commands, every advertised provider/model, and model-specific
  thinking levels in a project-scoped scratch session. Large catalogs from multiple
  logged-in providers remain complete so they can replace an older complete cache.
  Model values remain exact even when the model ID contains slashes, and the configured
  pre-sweep model remains the default. A rejected or partially applied selection fails
  before prompting.
- Pi likewise discovers every advertised model and its available thinking levels within
  the existing total probe deadline, so catalog size alone never makes a healthy refresh
  partial or leaves an older complete cache in place.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, representative plugin: a session is created with a first prompt and has attribution and a working directory. |
| L2 Routine | Headless bridge, representative plugin: options return agents, models, commands, and the last successful plugin-scoped creation selection; explicit refresh forces discovery; cache-only reports unavailable without discovering; a cache past the freshness window is served at once and reported stale; dedicated mode produces a local lowercase `color-animal` branch, worktree, and baseline; a gated metadata request does not gate a queryable create response; eligible generated branch refinement preserves the worktree path and publishes the updated session. |
| L3 Release | Client end to end (phone), every supporting production plugin: Send immediately renders launch status at the unresolved route, blocks duplicate submit, and replaces with the durable session; Back leaves creation running; each declared option scope is honored and usable; chosen agent, model, and variant apply; slash-command start dispatches without rendering bridge context; generated title and eligible branch refinement arrive through `session.updated`; a stale-reported cache refreshes in the background with no loading state while the refresh action spins in place rather than vanishing; pickers, plugin chooser, detail loading, and no-harness states render. |
| L4 Extended | Client end to end and live plugin, every supporting production plugin: definitive rejection and response-loss/timeout restore the exact in-route draft with duplicate-risk warning, reconnect/options refresh cannot erase it, and background failure does not restore an abandoned draft; occupied branch/path pairs are skipped and pair exhaustion uses a suffix; non-git, empty-repository, worktree-failure, metadata-failure, plugin-title-rename-failure, switched/detached/published branch, invalid generated ref, local/remote collision exhaustion, persistence failure, and shutdown cases retain a usable session; user rename/deletion wins over late title; failure with a retained cache still serves options while failure without one errors; concurrent requests coalesce; automatic refresh does not start a stopped plugin; a moved project invalidates its options. |
| L5 Full | Client end to end, every supporting production plugin: cache expiry and an undecodable entry recover without wrong options; creation is refused for a non-routable plugin and an unknown project; attachment creation works only where declared; unattributed payloads resolve to the historical identity. |

## Exploration Guidance

Vary plugin choice, warm cache versus fresh discovery, dedicated versus in-place
mode, prompt versus command start, default versus explicit options, and fresh,
collision-prone, or non-git projects. Also vary fast, slow, failed, and
shutdown-aborted metadata, plus user rename/deletion while title generation is
in flight. For dedicated sessions, vary untouched, switched, detached, upstream,
matching-remote, colliding, and rollback-failing branches while confirming the
directory stays fixed and title application does not wait for branch refinement.
For launch behavior, vary in-route versus background completion, success versus
definitive rejection versus response loss, navigation before completion, and
reconnect or option refresh while restoration is pending.

## Failure Signals

- Options are empty or stale where a discovery failure should be an explicit
  error, or a partial observation overwrites a complete cache.
- A successful creation does not become the next per-plugin prefill, a failed
  creation replaces it, one plugin's selection leaks into another, or a removed
  saved value prevents current catalog defaults from loading.
- A cache-only read starts a backend, or automatic refresh wakes a stopped one.
- The refresh action disappears while its own load runs, gives no sign it was
  pressed, or renames itself after which load it happens to be repeating.
- A background refresh of a stale cache blocks the composer, shows a loading
  state, runs twice, reverts a choice made while it ran, or leaves an explicit
  refresh waiting on work that can no longer apply.
- Recorded worktree, branch, base branch, or base commit disagrees with git.
- A dedicated workspace name comes from generated metadata, is not lowercase
  `color-animal` form, or collides with an existing branch or path.
- Bridge-owned context renders as the user's own message or command arguments.
- A DeepSeek catalog loses sound providers because one provider failed, parses
  an opaque model ID, dispatches before both requested config writes settle, or
  records a partially applied selection as successful.
- Creation succeeds for a non-routable plugin or unknown project.
- Metadata completion delays the create response, creates an unqueryable session,
  overwrites a user title, resurrects a deletion, or loses the local title when
  backend rename fails.
- Generated branch refinement moves the worktree directory, renames a switched,
  upstream, or matching-remote branch, overwrites a newer current-branch
  observation, delays title application, persists facts that disagree with Git,
  or misses its session update.
- Launch status waits for network metadata, changes the route before a durable
  response, permits duplicate Send, hijacks a later route, loses background work,
  auto-resends, or restores an incomplete/abandoned draft without the
  duplicate-risk warning.

## Known Limitations

- Client end-to-end coverage is phone-only; the desktop shell cannot create.
- Prompt attachments are capability-gated, so absence is expected, not failure.
- Only plugins registered in the build under test count.

## Sources

- Bridge: `bridge/app/lib/src/api/sesori_server_api.dart`,
  `bridge/app/lib/src/repositories/session_metadata_repository.dart`,
  `bridge/app/lib/src/services/` (session creation, mutation, events,
  options, worktree), the create-session and options handlers, and their tests
- OMP: `bridge/sesori_plugin_omp/lib/src/services/` and package tests
- DeepSeek: `bridge/sesori_plugin_deepseek/lib/src/repositories/`,
  `lib/src/services/`, and package tests
- Contract:
  `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart`
- Client: `client/module_core/lib/src/services/new_session_options_service.dart`
- Plans (discovery only): `.plan/completed/multi-plugin-release-prep`,
  `setup-aware-plugin-lifecycle`
