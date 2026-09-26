# Session Creation And Options

## Capability

Starting a new session: discovering the options a plugin offers for a project
(agents, providers/models, slash commands), choosing plugin, agent, model,
variant, and worktree mode, and creating the session with its first input.

## Required Behavior

- Desktop's project New session action, the sidebar's New session button and Cmd+N (Ctrl+N on Windows/Linux)
  open the same typed setup route. The button and shortcut use the open project, else the most recently active
  one; with no project yet they open the New project dialog.
  It opens setup rather than creating a backend session, ignores held-key repeats and respects root popup focus.
- On phone and desktop the setup page opens with the heading "What should we work on?" and a project
  selector naming the session's project. The selector opens only when another project exists; choosing one
  replaces the page with that project's setup page, so a session is never created in the project that was
  left, and a draft stays with the project it was typed in. The phone lists projects itself for this and
  names only the current project when that fails. On the phone the header sits above the options and hides
  while the keyboard is open, so the options stay in view while typing.
- The composer shows the agent entry only when the harness advertises more than one selectable agent.
  Claude, Codex, Copilot, Cursor and OMP advertise only their default mode as one agent, so their composer
  shows model and effort alone; OpenCode lists its real agents. A released mode name such as Plan or Ask
  that still arrives is honoured by the plugin, and naming the advertised default returns a session left in
  another mode to the default with its next prompt.
- The agent, model and effort selectors sit in one strip above the input on every surface, each a pill
  with a leading glyph and an unfold caret. A label too long for its pill keeps its end behind a leading
  ellipsis, "…Opus 5" rather than "Claude Op…", and screen readers hear the whole name. On a pointer
  surface the pills size to their labels; on touch they share the width. On either surface a pill whose
  share of the strip is too narrow for a readable label shows only its glyph, keeping the name as its
  tooltip, so a narrow window never overflows the strip. On a pointer surface the attach
  and command buttons are always visible and the box grows with the draft instead of opening an editor
  sheet. It stops at a third of the window and the draft scrolls, so even the minimum window keeps the
  selectors on screen.
- A session that cannot prompt, a sub-agent's page or an archived session, shows what it ran with in the
  composer's place: the same agent, model and effort pills, sized as on that surface, with no caret, no
  press feedback and no picker; screen readers hear values, not buttons. The bridge's prompt defaults
  decide them, else the newest agent reply's agent and model. A value the session cannot know is left out,
  never guessed: the agent shows only where the harness lists more than one, and the effort only where the
  harness reported it (per-harness gaps in `docs/HARNESS_CAPABILITIES.md`). Archiving clears the defaults,
  so an archived session never shows an effort; its options come from the bridge's cache only, never from
  discovery. A harness notice sits above the pills, and with nothing known there is no strip.
- A session with sub-agents shows a pill at the strip's trailing edge. While any sub-agent works it leads
  with a spinner and the running count, then the sub-agent glyph and the total, muted; idle, it shows the
  glyph and the total only. It never claims sub-agents are finished, since an idle one can be resumed.
  It stays while a staged command, the recording hint or the saved-recording actions take the selectors'
  place. Tapping it opens the sub-agent list above the pill, running first, without changing the
  composer's height; a tap elsewhere closes it. With more room below, as under a tall draft in a short
  window, the list opens below instead, and it scrolls rather than leaving the screen. The tooltip and
  screen-reader label read "N sub-agents, M working", and a screen reader can open the list from it.
- Options are discovered per plugin and cached under the plugin's declared
  coherence scope; retention and replacement are bridge-owned.
- Claude's plugin-scoped discovery runs in its host-created state directory,
  never a selected project or the bridge process's launch directory. This keeps
  its global option probe on a valid, stable path when projects move or disappear.
- Claude's catalog drops the CLI's own `default` model entry and names the
  selection instead: Opus is the default model and `high` the default effort, so
  every picker entry states what will actually run.
- Claude stamps assistant and error messages with the catalog picker id and
  effort the turn ran with, so a reopened session keeps its model and variants
  selected. Replayed transcripts and live turns without an explicit selection
  map resolved names (`claude-fable-5-1`) and short family/context aliases
  (`fable[1m]`) through the current catalog; an unknown name stays as recorded.
- No picker offers an unnamed "Default" option. Plugins declare effort variants
  in picker order and may name a default; when switching models, an existing
  compatible variant is kept; otherwise a model that offers variants uses the
  agent's declared variant when valid, then the model's declared default when
  offered, then the first listed. Selecting a variant is therefore a switch
  between named levels, never a reset to unset.
- Every plugin that exposes effort variants lists them strongest first on one
  shared ladder (`ultra`, `max`/`highest`, `xhigh`, `high`, `medium`/`mid`,
  `low`, `minimal`/`min`, then `off`/`none`; unknown names a plugin retains
  follow in backend order) and declares the default separately: the backend's
  own default where it names one (Claude `high`, Codex, DeepSeek, Grok),
  otherwise the variant the backend listed first, so reordering never changes
  what runs. Hermes exposes none, and Claude and Pi drop names outside their
  own closed level sets before ordering.
- Chat and New Session composer effort pickers display that catalog in reverse:
  lowest efforts at the top, strongest efforts (`max`, `xhigh`) at the bottom,
  nearest the trigger. A constrained-height popup opens at the bottom regardless
  of the selected effort; scrolling toward the top reveals the lowest options
  and heading. Selection/checkmarks, declared defaults, and agent/model picker
  ordering are unchanged on mobile and desktop.
- Every plugin ranks Anthropic and OpenAI models strongest first from the model
  id through one shared rule: newest generation first, then Fable, Opus,
  Sonnet, Haiku, or Astra, Sol, Terra, Luna, the bare GPT model, then other
  suffixes such as Mini, then the fuller version. Models of other vendors keep
  the plugin's own order after them: OpenCode newest release first, undated
  last, ties by name; other plugins backend order. DeepSeek model ids are opaque,
  so its models keep DeepSeek's order. The model picker never reorders models:
  it shows each plugin's declared order.
- One rule decides what a selection reconciles to, on every surface. A model the
  backend reports unavailable is treated as absent everywhere: it is neither
  selectable nor a source of variants, whether the screen is New Session or a
  live session, and an agent's declared model is validated against the catalog
  before it is adopted. Hidden agents and sub-agents are never picker entries, a
  withdrawn agent falls back to the first selectable one, and the variant list a
  screen shows always belongs to the model it currently has selected.
- One order decides the model, everywhere. What the caller asked for wins when
  the catalog still offers it: the agent just picked declares one, the bridge
  reported a remembered default, or the selection is simply being revalidated.
  Only when nothing asked for survives does retention apply, and it is what
  keeps a live session usable — the session's own transcript model, or the model
  already on screen, adopted even though the catalog does not list it. Failing
  both, the resolved agent's declared model is used, then the catalog's default.
- Retention is therefore a fallback, never an override: switching to an agent
  that declares an available model does change the model, and an agent declaring
  none leaves the current one alone. A refresh takes no retention at all, since
  adopting the catalog it just fetched is the reason it ran; there a replacement
  agent's declared model outranks the departed agent's.
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
  selected identity only after every requested write succeeds. The session
  header resolves that opaque identity through the loaded provider catalog and
  shows the model name when available. Catalog reads use the connected adapter
  without creating a session or model request; selection is session-local and
  never writes normal `DSH_HOME` settings. The default native catalog includes
  DeepSeek V4.1 Flash (`deepseek-flash`) with image input and reasoning controls.
  Refresh rereads the installed harness's configured catalog, not a live provider
  model endpoint; discovering models added by a newer harness requires updating
  the runtime. Explicit user model configuration remains authoritative.
- Grok exposes one primary agent and one provider group from initialize-owned
  model state. Model IDs and canonical reasoning-effort values remain exact and
  opaque; declared defaults stay distinct from the current selection. Explicit
  refresh uses an initialize-only process, creates no session, and replaces the
  last-good catalog only after a complete valid result. Malformed individual
  models or efforts are filtered without inventing values. Before creation or a
  turn, the complete model/effort tuple is validated against the current catalog
  and applied through Grok's plugin-local `session/set_model` extension; a failed
  write preserves the prior tracked selection and dispatches no prompt. An
  effort-only load waits for the session's exact loaded model before validation.
- Antigravity exposes one primary agent and discovers selectable models before the first chat through one retained,
  hidden, no-prompt native session at `GEMINI_HOME/antigravity-acp/conversations`. Missing-cache reads and refreshes
  coalesce; reuse is inert, refresh resumes the reserved ID, and a restart recovers the first sorted matching ID through
  standard `session/list`, creating only when none exists. List, project, import and metadata recovery hide every session
  in the reserved cwd. Failures create no replacement after a known ID and retain the last-good catalog. Exact paired
  High/Medium/Low ID and label suffixes become variants; ambiguous entries remain raw. Standard ACP configuration gets
  the exact native ID, then mode `default`; tracked live/replay selection uses normalized model plus variant. Connection
  reset clears catalog and attribution state and fences late discovery results while retaining the reserved ID hint.
- GitHub Copilot discovers model, mode, model-specific reasoning, and slash-command
  options through a bounded isolated ACP session while retaining the user's normal
  Copilot configuration for login, settings, and BYOK. The probe closes its own
  session and process. Equivalent probes coalesce, probes for different selected
  models serialize, and only the selected model's returned reasoning catalog can
  validate a turn. A stale model, mode, or reasoning value fails before prompt
  acceptance, invalidates that selection, and refreshes without inventing an
  option Copilot did not advertise. A catalog with no mode remains usable.
- Read intents stay distinct: a normal load may serve a valid cache or discover,
  a cache-only read never discovers and reports cache-unavailable, and an
  explicit refresh forces fresh discovery.
- A normal load reports whether the cache it served has aged past the bridge's
  ten-minute freshness window or was captured before the current bridge process started
  (so an upgraded bridge fills in catalog fields an older build did not map,
  such as fast mode), and the client then refreshes it in the background: the
  options stay on screen and usable, with no loading state, and simply change if
  the backend's answer did. The failure fallback never reports staleness, so a
  failed refresh is not retried at once. Both the New Session screen and a live
  session honor that report; a live session has no refresh control of its own.
- Every committed snapshot announces itself to clients as `session.options_updated`,
  naming the plugin and, for a project-scoped catalog, the project. A plugin-scoped
  catalog names no project because every project shares it. A live session showing
  that plugin re-reads the cache without discovering, and re-validates its selected
  agent, model, and variant against the result, so a withdrawn value is corrected
  before the next send rather than by its rejection. Overlapping re-reads keep the
  newest answer regardless of completion order.
- One background refresh runs per selection, and an explicit refresh joins it
  rather than discovering twice. It joins only a refresh that can still deliver:
  one belonging to a superseded selection, or to options the user has since
  edited, is left behind and the press starts its own.
- A choice made while a background refresh runs outranks it. The refresh was
  resolved against the agent, model, variant, and staged command as they stood
  when it started, so it is dropped rather than reverting the user.
- New Session never waits on options. The composer stays typeable throughout, and a
  session can be created before options arrive: agent, model, and variant are then
  omitted and the harness uses its defaults. Creation still waits for a verified
  bridge, a routable harness, and the project's worktree check.
- The page never describes where options came from. While they load, the agent and
  model pills shimmer at their final height, the harness pill shimmers until
  discovery answers, and the "New worktree" row keeps its height while the project
  is checked, so nothing shifts as answers arrive. When options cannot be loaded,
  one "Retry loading models" button stands in the pills' place; a bridge that can
  load options only by starting the harness offers "Load models" there instead.
  Whether a press repeats harness discovery, the project check, or the options
  themselves is decided behind it.
- Concurrent requests coalesce; an incomplete observation never replaces a
  complete cached one, and a moved project invalidates its entries. Completeness
  decides replacement only at capture time; the stored row holds just the
  catalog payload and its revision, so a payload that no longer decodes is
  discarded by revision and rediscovered instead of blocking discovery.
  Rejected-selection invalidation keeps its epoch checks before serving or
  committing, so a retained snapshot invalidated during discovery is not served
  once.
- Backend notifications use scoped event domains: Codex skill changes invalidate
  the options catalog rather than reporting project activity, while MCP startup
  changes remain MCP-tool events. A backend change that names a session refreshes
  that session's catalog; one that names none refreshes every project the plugin
  already holds a snapshot for, and never discovers for a project it does not.
- A plugin may declare start warm-up work that makes later requests faster.
  The bridge runs it once a generation becomes routable and never waits on it,
  so a slow or failing warm-up neither delays the request that triggered the
  start nor retires a healthy generation. OpenCode uses it to force its command
  catalog to index, because `GET /command` alone blocks on MCP server startup
  and is given a longer read timeout for the same reason.
- Failure with a valid cache still serves it; failure without one is an explicit
  error, never an empty option set. Automatic refresh never starts a stopped
  backend and no-ops for a superseded generation. A backend started only to
  discover options idles out within five minutes unless a session uses it.
- Creation resolves and validates the project handle before checking plugin
  routability, so an unknown project causes no plugin, metadata, git, or session
  persistence effect. Plugin startup, git/worktree preparation, backend creation,
  durable binding, first-input acceptance, and slash-command acceptance remain
  synchronous. Metadata starts only after those gates and does not delay the
  canonical, immediately queryable session response.
- Dedicated mode creates a branch and worktree from the resolved base branch
  using a bridge-generated lowercase `color-animal` name; the branch is
  `sesori/color-animal` and the worktree directory is the bare slug. Generated
  branch refinement keeps the `sesori/` prefix. It checks both branch
  and filesystem-path occupancy across three distinct pairs, then makes bounded
  attempts with a secure hexadecimal suffix. It falls back to the project
  directory when the repository is absent, commitless, or creation fails, and
  records worktree, branch, base branch, and base commit; in-place mode records
  the HEAD commit as baseline.
- Base-branch refresh skips fetching when the repository has no `origin`, so
  local-only Git projects can create dedicated worktrees without a fetch warning.
  A configured origin that cannot be fetched still logs the failure and uses
  existing refs.
- The model and slash-command pickers open as popovers anchored to their
  composer button on phone and desktop, above it, inside the window edge, and
  no taller than 380 px; their rows scroll inside. Each has a search field.
  The model picker groups models under uppercase provider headings, shows each
  provider's representative models until a search reveals the rest, and checks
  the selected model, following a selection or catalog change while open. The
  command picker shows source tags in both themes; long names and tags wrap
  within narrow layouts, descriptions and argument hints remain readable, and
  large catalogs stay lazy. Search matches names,
  descriptions, and hints, including a query entered during loading; clearing
  it restores the catalog. Selecting a row returns that exact model or command
  and closes the popover.
- On desktop the search field takes focus as the picker opens, so typing
  filters at once. Up and Down move one highlight across the options, skipping
  headings and holding at either end; the mouse moves the same highlight.
  Enter picks the highlighted option and Esc closes the picker without a
  choice. On the phone nothing is highlighted and the keyboard stays down
  until the field is tapped.
- Prompt and slash-command starts are exclusive; only user-authored text is
  user-visible, and attachments appear only where declared. The session keys on
  the stable project identifier and carries title, defaults, and worktree facts.
- Send immediately replaces the composer with detail-shaped launch status while
  the unresolved URI remains `/projects/<projectId>/sessions/new`. Duplicate Send
  is blocked. Back leaves creation running, and success replaces the route only
  when that launch route is still current and the returned session is durable.
- Mobile and desktop compose the same new-session view while retaining
  shell-owned routing, DI, connection-banner policy, and platform capabilities.
  Mobile keeps voice capture and keyboard visibility. Desktop is explicitly
  text-first, constructs no voice cubit, uses its native image picker when the
  selected plugin declares attachments, and exposes the same dedicated-workspace
  option rather than substituting a desktop-only creation path.
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
- Hermes discovers its model catalog through a disposable ACP session and settles
  that process before deleting any persisted discovery row. An empty session may
  never be persisted: the CLI's exact not-found response for that session completes
  cleanup with a local diagnostic. Other CLI/database errors retain both output
  streams and follow the existing failed-discovery/fallback policy rather than
  being misclassified as harmless absence.
- OMP discovers modes, commands, every advertised provider/model, and model-specific
  thinking levels in a project-scoped scratch session. Large catalogs from multiple
  logged-in providers remain complete so they can replace an older complete cache.
  Model values remain exact even when the model ID contains slashes, and the configured
  pre-sweep model remains the default. A rejected or partially applied selection fails
  before prompting. Finding no usable model returns project-scoped authentication-required
  state with local login guidance; it does not mark the whole OMP runtime unauthenticated.
- Pi likewise discovers every advertised model and its available thinking levels within
  the existing total probe deadline, so catalog size alone never makes a healthy refresh
  partial or leaves an older complete cache in place. A missing model catalog returns the
  same scoped authentication-required state rather than an empty successful snapshot or
  a global runtime failure. Its bounded action directs the user to Pi's local `/login`;
  provider diagnostics and local paths never enter that guidance.
- Authentication-required discovery preserves any last-good durable options without
  reporting them as a successful refresh. `/session/options` carries the condition as a
  typed response. New Session replaces the composer with a login card
  titled from the selected plugin's display name, carrying the plugin's guidance, "Open
  harness settings", and "Recheck", and creation is blocked. A warning popup adds the same
  guidance only when the login requirement is newly discovered, after the page already had
  usable options for that harness; a requirement known on arrival shows only the card. A session-detail stale-option recovery also shows the bounded
  guidance and parks the prompt instead of retrying with unavailable options.

### Fast mode

- A model advertises fast mode through `ProviderModel.fastMode`. The composer
  shows the ⚡ pill next to the effort pill, in New Session and in session
  detail, only when that support is available or unavailable. An absent or
  unknown value (older bridge, harness without fast mode, a model without it)
  shows no pill.
- Available: the pill's bolt is yellow while on, in both themes, and neutral
  while off. Prompts,
  slash commands, and session creation carry the choice as `fastMode`; a model
  without available fast mode always sends `fastMode: false`, whatever was chosen.
- Unavailable: the pill is dimmed. A tap changes nothing and shows the standard
  error popup with the closed reason (extra usage turned off, not on the plan,
  turned off by the organization, or unknown).
- Switching speed drops the backend's prompt cache. When the session has
  history and the model was last active less than the model's cache lifetime
  ago (Codex 30 minutes, Claude 60 minutes), a confirmation explains the full
  re-read, and in both directions; turning fast mode on also mentions the extra
  usage. A session without history, or one whose cache has expired, switches
  at once. Last activity is the newest assistant message's completion time
  (its start time while it streams), else the session's last update.
- The choice is part of the session's prompt defaults. Reopening the session,
  or a `session.prompt_defaults_changed` event from another surface, restores
  it. New Session remembers the last choice per project and plugin like the
  variant, and seeds it from the plugin's last-used prompt defaults.
- Codex sends the choice as the `priority` service tier (`default` when off) on
  every turn, and on `thread/start` for a session created fast. Claude applies
  it through the `apply_flag_settings` control request before a turn whose
  choice differs from the resident process; the catalog probe opts in first so
  the account's real availability reason is reported. See
  `docs/HARNESS_CAPABILITIES.md` for the harness details.
- Coverage: the toggle calculator's visibility, forced-off, and confirmation
  matrix (including the exact cache-lifetime boundary) and the cubits' send and
  reconciliation paths run as unit tests. The pill's hidden, dimmed, and on
  states and its popup and confirmation dispatch run as widget tests. Release
  coverage (L3) toggles fast mode on a live Codex and Claude session with a
  warm and a cold cache and reopens the session to confirm the choice persists.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, representative plugin: a session is created with a first prompt and has attribution and a working directory. |
| L2 Routine | Headless bridge, representative plugin: options return agents, models, commands, and the last successful plugin-scoped creation selection; explicit refresh forces discovery; cache-only reports unavailable without discovering; a cache past the freshness window or captured before the bridge process started is served at once and reported stale; a committed snapshot emits `session.options_updated` with the right project scope while an uncommitted refresh emits nothing; a session-less backend catalog change refreshes only the plugin's already-cached projects; dedicated mode produces a local lowercase `sesori/color-animal` branch, worktree, and baseline; a gated metadata request does not gate a queryable create response; eligible generated branch refinement preserves the worktree path and publishes the updated session. Hermes discovery accepts only the exact absent scratch ID after process exit; real deletion/database errors remain visible. |
| L3 Release | Client end to end (phone), plus desktop automated/routing coverage, every supporting production plugin: Send immediately renders launch status at the unresolved route, blocks duplicate submit, and replaces with the durable session; Back leaves creation running; each declared option scope is honored and usable; chosen agent, model, and variant apply; slash-command start dispatches without rendering bridge context; generated title and eligible branch refinement arrive through `session.updated`; a stale-reported cache refreshes in the background with no loading state; the composer is typeable and Send works before options arrive; loading keeps the layout with shimmering pills and a failure shows one retry; a New Session options refresh (background, Retry, Load, or Recheck) updates an already-open session's commands, agents, and models for the same plugin and project without reopening it; pickers, plugin chooser, detail loading, and no-harness states render; a sub-agent's page and an archived session show only the run details their harness knows, as read-only pills. Scoped authentication-required discovery replaces the composer with the login card, keeps Recheck available, blocks Create, and presents only plugin-owned bounded guidance without globally blocking the harness. Mobile retains voice capture; desktop remains text-first with voice omitted and its native attachment picker used only where declared. Copilot uses only the model, mode, model-specific reasoning, and command values advertised to the entitled account, including a healthy no-mode catalog. Grok shows its current default, sends exact advertised model/effort values, rejects a stale tuple, refreshes, and preserves the last successful plugin-scoped choice. |
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
reconnect or option refresh while restoration is pending. For Antigravity, vary cold discovery versus reuse, concurrent reads, reserved-session
restart recovery, explicit refresh, account default versus normalized High/Medium/Low selection, malformed catalog
retention, cold reset/residency, and a stale model or mismatched variant rejected before dispatch. For Copilot, vary the
account's default and explicit model/mode/reasoning choices, a model change whose
reasoning catalog differs, no advertised mode, an exact slash command, stale
selection rejection, and authentication failure during discovery. For Grok,
vary default and explicit model/effort tuples, model-only and effort-only
changes, changing catalogs, malformed optional entries, stale rejection,
refresh failure with a last-good catalog, and headless-auth discovery failure.
For composer effort pickers, vary full-height and small/keyboard-constrained
viewports, a selected low effort, and reopening after scrolling: the strongest
options start visible at the bottom, the lowest remain reachable above, and
selection still dispatches the exact variant that was tapped.
For the command picker, vary light/dark mode, narrow widths, large text, long
command names, every source label, missing descriptions/hints, empty/no-match
results, and scrolling a large catalog with the keyboard open. For both
pickers on desktop, vary a trigger near the window edge, keyboard versus mouse
highlight, Enter and Esc.

## Failure Signals

- Options are empty or reported successfully where authentication-required
  discovery should be explicit, a partial observation overwrites a complete
  cache, Create remains enabled, Recheck becomes unavailable, the plugin runtime
  becomes globally blocked, or Pi reports no models without local `/login` guidance.
- Options are stale where a discovery failure should be an explicit error.
- Hermes model discovery falls back solely because an empty, unpersisted scratch
  session cannot be deleted, deletes before the scratch process exits, or hides
  a real CLI/database failure as benign absence.
- An effort popup puts the strongest levels at the top, opens with them hidden
  below the fold, makes the lowest levels unreachable by scrolling toward the
  top, or selects a different level from the tapped row.
- Command rows overflow at larger text sizes, source tags disappear, search
  loses an early query, or the last command cannot be selected.
- A picker opens as a full-screen sheet, detaches from its button, crosses the
  window edge, or grows past its height cap; on desktop, typing does not reach
  the search, the arrows land on a heading, or Esc applies a choice.
- A model the backend reports unavailable is selectable or offers variants on
  one surface but not another, an agent's declared model is adopted without
  being checked against the catalog, or a screen's variant list describes a
  model it no longer has selected.
- A successful creation does not become the next per-plugin prefill, a failed
  creation replaces it, one plugin's selection leaks into another, or a removed
  saved value prevents current catalog defaults from loading.
- A cache-only read starts a backend, or automatic refresh wakes a stopped one.
- The composer or its typing is blocked while options load, sending waits for
  options, the page changes height as options arrive, a status line describes
  the options' origin, or a load failure leaves no retry.
- A known login requirement leaves the composer usable instead of the login
  card, or the popup appears for a requirement already known on arrival.
- A background refresh of a stale cache blocks the composer, shows a loading
  state, runs twice, reverts a choice made while it ran, or leaves an explicit
  refresh waiting on work that can no longer apply.
- A live session keeps serving options the bridge has already replaced, or only
  corrects them when a send is rejected. An options update for another plugin or
  another project changes a session's options, an announcement makes a client
  discover rather than read its cache, an older overlapping re-read undoes a
  newer one, or a background re-read raises a user-facing notice.
- A start warm-up delays or fails a plugin start, runs more than once per
  generation, or a slow first OpenCode command listing fails discovery and
  silently leaves the previous catalog in place.
- Recorded worktree, branch, base branch, or base commit disagrees with git.
- A dedicated workspace name comes from generated metadata, is not lowercase
  `sesori/color-animal` form, or collides with an existing branch or path.
- Bridge-owned context renders as the user's own message or command arguments.
- DeepSeek's default catalog omits V4.1 Flash after installing the target runtime,
  or selecting it sends a different upstream model ID.
- A DeepSeek catalog loses sound providers because one provider failed, parses
  an opaque model ID, exposes a catalog-resolvable opaque ID in the session
  header, dispatches before both requested config writes settle, or records a
  partially applied selection as successful.
- Antigravity creates more than one reserved discovery session during normal reuse/refresh, prompts that session,
  exposes its cwd through catalog/import/recovery, groups an unpaired or ambiguous suffix, sends a normalized ID to ACP,
  loses normalized model/variant attribution live or on replay, replaces a last-good catalog after failure, accepts an
  unknown/stale tuple, retains a catalog after connection reset, applies a mode other than `default`, or prompts after
  failed configuration.
- A Copilot catalog invents an option, validates reasoning against another model,
  overlaps unlike probes, replaces a coherent cache after authentication failure,
  or accepts a stale selection before applying every requested config value.
- A Grok catalog interprets an opaque ID, replaces its last-good state after a
  failed or malformed refresh, creates a session during refresh, conflates
  declared and current effort, validates effort against the wrong model, or
  dispatches after a stale or partially applied selection.
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
- Desktop cannot open the typed new-session route, constructs voice capture,
  hides a supported dedicated-workspace option, or bypasses the shared creation
  view and its restoration/launch semantics.
- A sub-agent's or archived session's run-detail pills open a picker, show a caret or press feedback, name
  a placeholder agent or a guessed effort, or make the harness discover options.
- The ⚡ pill shows for a model without fast-mode support, hides for an
  unavailable one, sends `fastMode: true` for a model that cannot run it, or
  switches without confirmation while the prompt cache is warm; the choice is
  lost on reopen or not synchronized from another surface.

## Known Limitations

- Live client end-to-end coverage remains phone-only. The desktop shell can
  create through the shared view and has automated capability/routing coverage,
  but still needs a live desktop release exercise.
- Prompt attachments are capability-gated, so absence is expected, not failure.
- Only plugins registered in the build under test count.
- Antigravity intentionally retains one Google-owned empty `.db`/`.meta` discovery artifact because the pinned runtime
  has no session deletion capability. Rare older duplicates in the reserved cwd are hidden but not cleaned up.
- Copilot's ACP catalog probe closes its scratch session, but the pinned CLI has
  no deletion method; low-impact upstream history residue can remain in the
  user's normal Copilot home.
- Grok model and reasoning discovery uses its supported CLI's legacy ACP model
  surface. Accounts and custom configurations can legitimately advertise one
  model or no reasoning variants; absence is not a failure.

## Sources

- Bridge: `bridge/app/lib/src/api/sesori_server_api.dart`,
  `bridge/app/lib/src/repositories/session_metadata_repository.dart`,
  `bridge/app/lib/src/services/` (session creation, mutation, events,
  options, worktree), the create-session and options handlers, and their tests
- OMP: `bridge/sesori_plugin_omp/lib/src/services/` and package tests
- DeepSeek: `bridge/sesori_plugin_deepseek/lib/src/repositories/` and
  `bridge/sesori_plugin_deepseek/lib/src/services/`, and package tests
- Copilot: `bridge/sesori_plugin_copilot/lib/src/services/` and
  `bridge/sesori_plugin_copilot/lib/src/repositories/`, and package tests
- Antigravity: `bridge/sesori_plugin_antigravity/lib/src/services/antigravity_session_options_service.dart`,
  its catalog tracker, protocol mapper, composed plugin and tests
- Grok: `bridge/sesori_plugin_grok/lib/src/services/`,
  `bridge/sesori_plugin_grok/lib/src/repositories/`,
  `bridge/sesori_plugin_grok/lib/src/trackers/`, and package tests
- Contracts: `bridge/sesori_plugin_interface/lib/src/models/plugin_session_options.dart`,
  `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart`,
  `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin.dart`, and
  `shared/sesori_shared/lib/src/models/sesori/session_options_error_response.dart`
- Client: `client/module_core/lib/src/services/session_selection_calculator.dart`
  (the single owner of selection reconciliation),
  `client/module_core/lib/src/services/new_session_options_service.dart`,
  `client/module_core/lib/src/services/fast_mode_toggle_calculator.dart`,
  `client/module_app_ui/lib/src/features/session_detail/widgets/agent_model_buttons.dart`,
  `client/module_core/lib/src/services/session_detail_load_service.dart`,
  `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`,
  `client/module_app_ui/lib/src/features/new_session/`,
  `client/app/lib/features/new_session/new_session_screen.dart`, and
  `client/desktop/lib/features/new_session/desktop_new_session_screen.dart`
- Client tests: `client/app/test/core/widgets/agent_model_buttons_test.dart`,
  `client/app/test/features/new_session/new_session_screen_test.dart`,
  `client/desktop/test/features/new_session/desktop_new_session_screen_test.dart`,
  `client/desktop/test/core/routing/desktop_router_test.dart`, and, for read-only run details,
  `client/app/test/features/session_detail/widgets/session_detail_body_test.dart`,
  `client/desktop/test/features/sessions/desktop_session_detail_screen_test.dart` and
  `client/module_core/test/cubits/session_detail/session_detail_resolvers_test.dart`
- Plans (discovery only): `.plan/completed/multi-plugin-release-prep`,
  `setup-aware-plugin-lifecycle`
