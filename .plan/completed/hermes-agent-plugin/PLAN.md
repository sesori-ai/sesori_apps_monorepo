# Hermes Agent Harness Plugin

## Status

- **Plan slug:** `hermes-agent-plugin`
- **Status:** complete; Steps 1-8 merged (#895, #915, #916, #917, #919, #921, #927, #929, extended by #955 and #965), Step 9 retires the plan with owner-accepted reduction
- **Plan date:** 2026-08-13
- **Owner review:** started 2026-08-15; the contributor-authored plan was not previously approved
- **Implementation base:** current `origin/main`
- **Delivery:** nine PRs total; Steps 7-9 are revised by this review while preserving the published step count

## Goal

Add Hermes Agent as a monitored and controllable coding backend through its ACP
v1 stdio server. Sesori supports Hermes ACP sessions: users can import persisted
ACP sessions, create and continue sessions, stream turns and tools, answer
permission requests, replay history, abort work, and send supported images.

This does not claim visibility into ordinary Hermes CLI, TUI, or gateway
sessions. Hermes `session/list` exposes persisted rows whose source is `acp`.

## Authoritative Upstream Facts

Reviewed against Hermes Agent 0.20.1 (`v2026.8.13`, commit
`f80f453ae0679347e38abc917c7f94f717bf96c5`):

- `hermes acp` is the stdio server and negotiates ACP wire protocol version 1.
- `hermes acp --version` prints the Hermes package version, not an ACP adapter
  or Python SDK version. Hermes 0.20.0 remains Sesori's conservative supported
  floor because that is the earliest release validated for this integration;
  it is not claimed to be the first Hermes release with ACP support.
- Initialize advertises load, list, resume, and fork session capabilities plus
  image prompts. Hermes does not advertise session close.
- Hermes implements standard model and mode state plus `session/set_model`,
  `session/set_mode`, and `session/set_config_option`. Sesori v1 intentionally
  uses the model/provider configured in Hermes and does not expose a Hermes
  model or mode picker until the shared ACP surface supports those contracts.
- A configured provider authentication method is advertised before the
  terminal `hermes-setup` method. A fresh install can advertise only terminal
  setup; the headless bridge must not invoke or accept that as authentication.
- `hermes status` reports configured model/provider labels but does not prove
  credentials are usable. It is a best-effort configuration probe; the ACP
  initialize/authenticate handshake is the runtime authentication authority.
- Permission requests carry a session id. Hermes permission scope is
  backend-defined; its session-level option can be presented through Sesori's
  existing "always" affordance as documented by the shared permission contract.
- Prompt images are accepted by ACP, but successful vision behavior still
  depends on the selected Hermes model/provider.

Sources:

- <https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.13>
- `acp_adapter/entry.py`, `acp_adapter/server.py`, `acp_adapter/auth.py`,
  `acp_adapter/session.py`, and `acp_adapter/permissions.py` at the commit above

## Architecture And Scope

```
client <-> relay <-> bridge <-> sesori_plugin_hermes <-> hermes acp
```

- `sesori_plugin_hermes` owns every Hermes-specific executable, identity,
  setup, authentication-selection, launch, and capability decision.
- `sesori_plugin_acp` owns standard ACP transport, sessions, turns, events,
  approvals, and history replay.
- Bridge app code knows Hermes only at the supported plugin registry
  composition point.
- Hermes is direct CLI only. Sesori never installs or updates Hermes and adds
  no managed runtime state.
- Setup resolves PATH or authoritative `--hermes-bin`, checks the Hermes package
  version, and inspects configuration without starting the ACP server.
  `ensureRuntime` revalidates either executable immediately before start.
- Runtime authentication selects the first non-terminal method. Terminal-only
  setup remains authentication-required with local CLI guidance.
- External ACP sessions enter the durable catalog only through explicit Hermes
  import. Normal project/session reads remain database-only and never start a
  plugin.
- Synced transcript reads remain bridge-authoritative. `session/load` is used
  for first backfill or a stale reread, not every reopen.
- Hermes has no close/delete ACP method. Sesori deletion removes its own row and
  transcript and retains the normal plugin-scoped tombstone so import cannot
  resurrect it. The Hermes ACP row can remain in Hermes storage; direct private
  database mutation is out of scope without a supported upstream API.

### Client Branding Exception

The owner explicitly approved custom Hermes branding on 2026-08-15, including
the supplied NousResearch artwork. Step 6 therefore extends the existing
`PregoBrandLogo` built-in mapping despite the general preference for opaque
plugin ids. This is a presentation-only exception: behavior stays plugin-owned,
the wire id remains a string, and unknown ids retain the generic icon/raw-id
fallback. A future backend-neutral presentation contract is not introduced for
one consumer.

### Compatibility

- No client/bridge wire shape changes. Plugin ids remain strings.
- Older clients connected to a Hermes-capable bridge show the generic icon and
  bridge-provided display name.
- Newer clients connected to an older bridge receive no Hermes entry.
- No migration, legacy route, compatibility shim, or persisted-data default is
  needed.

### Complexity Budget And Cleanup

- New persistent mutable state: none.
- New in-memory coordination: none beyond the existing ACP plugin instance.
- No runtime downloader, credential store, backend database reader, session
  registry, or client capability transport is added.
- Step 7 folds version parsing into the descriptor rather than retaining a
  one-consumer runtime-manifest abstraction.
- No existing production field, cache, watcher, or database column becomes
  obsolete.

## Delivery Steps

| Step | PR title | State and scope |
|---|---|---|
| 1/9 | `🌱 [hermes-plugin] docs: plan Hermes Agent harness support [step 1/9]` | Merged as #895; contributor-authored plan, corrected in Step 7. |
| 2/9 | `🌱 [hermes-agent-plugin] feat(hermes): scaffold the ACP plugin package [step 2/9]` | Merged as #915. |
| 3/9 | `⚙️ [hermes-agent-plugin] feat(hermes): add the ACP plugin core [step 3/9]` | Merged as #916. |
| 4/9 | `⚙️ [hermes-agent-plugin] feat(hermes): add descriptor, runtime probe, and setup [step 4/9]` | Merged as #917. |
| 5/9 | `⚙️ [hermes-agent-plugin] feat(hermes): register the plugin in the bridge [step 5/9]` | Merged as #919. |
| 6/9 | `⚙️ [hermes-agent-plugin] feat(client): brand the Hermes harness [step 6/9]` | Merged as #921; corrected supplied artwork and asset contract. |
| 7/9 | `🚧 [hermes-agent-plugin] fix(hermes): correct runtime and ACP assumptions [step 7/9]` | Merged as #927: auth selection, version semantics, executable revalidation, setup failure classification, null activation retry, exact registry test, plan/docs correction. |
| 8/9 | `🚧 [hermes-agent-plugin] test(hermes): verify production ACP behavior [step 8/9]` | Merged as #929, extended by the 2026-08-18 iOS client E2E run recorded in `TRACKER.md` (#955) and the session-option documentation (#965). Session creation, tools and file changes, images, history and recovery, and deletion now pass; `Plugin setup and lifecycle` (L4 idle respawn), `Session turns` (reasoning streaming), `Questions and permissions`, `Projects and sessions` (failed/cancelled import), and `Compatibility` remain blocked. |
| 9/9 | `🌱 [hermes-agent-plugin] docs: retire the plan [step 9/9]` | Done; retires the plan under the owner-accepted reduction recorded below. |

## Regression And Retirement Matrix

Step 8 records the exact Hermes version, bridge/app build, client platform,
host platform, privacy-safe evidence, cleanup, and Pass/Fail/Blocked result for
each row. Required scope is the Hermes addition through L3, plus the named
targeted L4 recovery checks; unchanged plugins retain their existing coverage.

| Feature document | Required Hermes evidence | Boundary |
|---|---|---|
| `plugin-setup-and-lifecycle.md` | Missing/pre-ACP/old/current PATH and explicit binaries; unconfigured terminal-only auth; configured start; disable/enable/restart; targeted L4 idle respawn | Headless bridge + client E2E + live plugin |
| `projects-and-sessions.md` | Explicit Hermes import only; normal catalog reads do not start Hermes; failed/cancelled import leaves the committed catalog intact | Headless bridge + live plugin |
| `session-creation-and-options.md` | Create with configured defaults; no false model/mode picker claim; stable Hermes identity | Client E2E + live plugin |
| `session-turns.md` | Text, reasoning, tool and status streaming; abort; concurrent sessions; no unadvertised close/form/config call | Client E2E + live plugin |
| `session-history-and-recovery.md` | First `session/load` backfill; synced reopen from bridge storage while stopped; plugin restart and bridge restart converge | Headless bridge + live plugin |
| `questions-and-permissions.md` | Permission once/reject/backend-defined always; explicit session correlation with two active sessions; cleanup on abort | Client E2E + live plugin |
| `attachments-and-images.md` | Supported image reaches a vision-capable configured model; unsupported/model rejection remains visible and bounded | Client E2E + live plugin |
| `tools-and-file-changes.md` | Tool lifecycle and bounded output normalize live and after replay | Client E2E + live plugin |
| `session-archiving-and-deletion.md` | Local deletion purges Sesori state, tombstone prevents re-import, and retained upstream Hermes row is recorded as a limitation | Headless bridge + live plugin |
| Compatibility | Unknown-id fallback on an older client contract and no Hermes entry from an older bridge | Automated + client E2E where presentation is claimed |

Step 9 cannot retire this plan while a required row is unexecuted, partial,
blocked, or failed unless the owner explicitly accepts that reduction here.

**Owner acceptance recorded 2026-08-18:** the owner explicitly accepted
retirement with five rows still Blocked, each on one specific unexercised
item: `Plugin setup and lifecycle` (targeted L4 idle respawn), `Session turns`
(reasoning streaming; no `agent_thought_chunk` observed), `Questions and
permissions` (no ACP permission request was ever emitted), `Projects and
sessions` (failed/cancelled in-flight import), and `Compatibility` (second
build pair). Each gap is also recorded as a removable note in the relevant
feature document under `docs/regression/` so it survives this retirement.
These remain unverified; no future change may cite this plan as evidence that
they pass.

## Risks And Test Focus

- **Upstream schema drift:** Hermes runs the ACP SDK's unstable protocol mode.
  Verify against both the supported floor when available and the current stable
  release; wire protocol `1` alone is not sufficient evidence.
- **Authentication:** terminal setup is not headless authentication. Verify
  terminal-only and configured-provider method lists separately.
- **Configuration:** status labels are not credential proof; runtime handshake
  failure must stay typed and observable.
- **Session scope:** only persisted ACP-source sessions are listed. Do not claim
  ordinary Hermes CLI session discovery.
- **Deletion:** Sesori cannot delete the upstream Hermes row through ACP. The
  tombstone prevents user-visible resurrection but does not claim disk erasure.
- **Images:** capability advertisement does not guarantee the configured model
  supports vision.
- **Privacy:** keep prompts, transcripts, paths, credentials, raw status output,
  and session identifiers out of committed evidence.

## Expected Result

A supported, configured Hermes installation appears as `Hermes Agent`, can be
imported and controlled through the existing relay/bridge path, and degrades
only its own plugin when setup or authentication fails. Product behavior and
regression evidence remain honest about configured model use, ACP-only session
visibility, image-provider dependence, and upstream deletion limits.
