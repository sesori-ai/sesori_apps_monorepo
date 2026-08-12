# Phone Harness Install

## Status

- **Plan slug:** `phone-harness-install`
- **Status:** completed
- **Related history:** `.plan/completed/setup-aware-plugin-management` built the
  management transport, snapshots, tokens, and lifecycle commands this plan
  extends.

## Goal

Let a phone install a missing (or too-old) harness runtime with one tap. The
bridge downloads the pinned **managed binary** into the plugin's state
directory — never a global install — then enables the harness, re-inspects
setup, and starts it when ready. The phone shows phase + percent progress while
the install runs.

Login-from-phone is explicitly **out of scope**. Decisions made with login in
mind are marked `login-note:` inline.

## Confirmed Product Decisions

All confirmed with the user:

1. **All three harnesses** (OpenCode, Codex, Cursor) get install support.
   Cursor lands last because it needs new manifest + package machinery.
2. **Install is offered per-harness via a declared capability** — never assumed.
   A harness advertises it only when installable in its current config/platform.
3. **Offered when setup is `runtimeMissing` or `unavailable` (too old)** — the
   managed pinned binary outranks a too-old PATH install in the existing
   provisioning precedence. Not offered on `unknown` probes or when ready.
4. **Progress = phases + percent** (downloading X%, verifying, extracting) via a
   new dedicated SSE event. Terminal success/failure also lands through the
   normal management snapshot flow.
5. **Install implies enable**: after a successful install the bridge persists
   the harness as enabled (if disabled), re-inspects setup, and auto-starts it
   when ready. One tap goes from "not installed" to selectable for new
   sessions — or to "login required".
   `login-note:` the auth-required end state is deliberately left as-is; the
   future phone-login feature picks up exactly there, keyed off the same
   `PluginSetupAuthenticationRequired` state and per-harness capability model.

## User Journey

Harness settings (or new-session picker → settings shortcut) → harness card
shows "Runtime missing" + **Install** button → tap → card shows phase/percent
progress → bridge downloads/verifies/extracts the managed binary → harness is
enabled, re-inspected, auto-started when ready → card flips to ready (or "login
required") and the harness becomes selectable for new sessions. On failure the
card shows a dismissible error and the Install button returns.

## Current Behavior (evidence)

- `RuntimeInstallService` + `ManagedRuntimeCleaner`
  (`bridge/sesori_plugin_runtime/lib/src/provisioning/`) already implement
  download → checksum → extract → place → sentinel and stale-version sweep, but
  have **no production caller** since `ensureRuntime` was made read-only
  (descriptor contract: "must never download"). This plan gives them their
  production caller again.
- `OpenCodeRuntimeManifest` and `CodexRuntimeManifest` pin version, per-platform
  assets, and SHA-256 digests. Cursor has no manifest — only a PATH probe with
  `minVersion`/`targetVersion` constants in `CursorPluginDescriptor`.
- Management plumbing exists end to end: capability sets
  (`PluginControlCapability` → `PluginManagementCapability`), the
  `POST /plugin/:id/command` route with the sealed
  `PluginLifecycleCommandRequest`, per-plugin active-command slots with typed
  conflicts, snapshot tokens + `plugin.management.changed` SSE, and the phone's
  `PluginManagementService`/`PluginManagementCubit`/harness settings screen.
- `PluginLifecycleService._enable` already implements persist-enable →
  re-inspect → start-when-ready; the post-install flow reuses it verbatim.
- Cross-instance startup mutex (`StartupMutexRepository`) serializes runtime
  starts; `RuntimeInstallService`'s doc contract assumes installs run under it.

## Architecture Decisions

### Capability

- Add `PluginControlCapability.install` (interface) and
  `PluginManagementCapability.install` (wire). Old apps deserialize the unknown
  wire value to `unknown` and ignore it — forward-safe.
- Each descriptor decides purely from config + platform whether to advertise it:
  - **OpenCode**: not in attach mode (`no-auto-start`), no explicit
    `--opencode-bin`, and `manifest.assetFor(currentTarget) != null`.
  - **Codex**: no explicit `--codex-bin`, platform supported.
  - **Cursor** (final step): no explicit `--cursor-bin`, non-Windows (no
    published Windows asset ⇒ `assetFor` returns null ⇒ capability absent).
- The phone shows Install only when the capability is present **and** setup
  state is `runtimeMissing` or `unavailable`. An old bridge never advertises
  the capability, so a new app never offers install against it.
  `PluginSetupUnavailable` is broader than "too old" in general ("unsupported
  or otherwise unusable"), but for the installable descriptors it is only
  produced for a too-old binary today (OpenCode/Codex: explicit-bin too old;
  Cursor: CLI below minimum). The explicit-bin cases never advertise the
  capability, so capability ∧ `unavailable` ⇒ installable. Descriptor tests in
  step 2 pin this: while the install capability is advertised,
  `PluginSetupUnavailable` may only be returned for a too-old runtime that the
  managed install resolves.

### Wire contracts (backward/forward compatible, additive only)

- `PluginLifecycleCommandRequest.install()` — new variant on the existing
  sealed request, same `POST /plugin/:id/command` route. Unreachable against
  old bridges by the capability gate above.
- `SesoriSseEvent.pluginInstallProgress` (`"plugin.install.progress"`):
  `pluginId`, `phase` (closed enum with `unknown`: `downloading`, `verifying`,
  `extracting`, `finalizing`, `completed`, `failed`), `percent` (int?, only
  meaningful while downloading with a known total), `message` (String?, only on
  `failed`, sanitized — no paths/raw command output). Old apps skip unknown SSE
  types at the transport boundary already.
- No snapshot schema change: while installing, the harness row's existing
  `workState: busy` plus the active-command conflict machinery cover "busy";
  terminal outcomes surface through the existing snapshot-token invalidation.

### Install execution (bridge)

- `BridgePluginDescriptor.installRuntime(...)` — new seam mirroring
  `inspectSetup`'s inputs (config, processes, environment, stateDirectory,
  abort signal) returning `Stream<RuntimeProvisionProgress>` (the existing
  vocabulary: `ProvisionDownloading/Verifying/Extracting/Ready/Failed`). The
  default implementation emits `ProvisionFailed` (capability gating means it is
  never invoked for non-installable descriptors).
- OpenCode/Codex implement it by composing the existing `RuntimeInstallService`
  with their manifest, then sweeping superseded versions via
  `ManagedRuntimeCleaner` after success. `ensureRuntime` stays read-only.
- `PluginRuntime` gains an install entry point on the slot (descriptor access
  lives there), fenced like `inspectSetup` against generation/revision changes;
  `PluginLifecycleRepository` mirrors it without policy.
- **No lock is acquired for the install.** The serialization that matters
  already exists: install is only offered while the harness is setup-blocked
  (`runtimeMissing`/`unavailable`), and setup-blocked plugins are excluded from
  `startAllowedPluginIds`, so no start of that plugin can run concurrently in
  this bridge; other lifecycle commands on the same plugin are serialized by
  the existing per-plugin active-command slot; cross-process overlap is covered
  by the existing single-live-bridge enforcement; and any residual race is
  self-healing because the sentinel is written last and the binary lands via
  atomic rename. `RuntimeInstallService`'s doc comment (which still describes
  the old startup-mutex caller assumption) is updated in step 3 to state this
  contract.
- `PluginLifecycleService` owns the install command through the existing
  per-plugin active-command slot:
  - **Accepted-immediately semantics**: unlike other lifecycle commands, the
    HTTP response returns the current snapshot right after validation and
    kickoff (a multi-minute blocking response would hit relay timeouts and the
    documented "uncertain mutation" path). The slot stays occupied until the
    terminal outcome, so a duplicate install joins (returns accepted again) and
    any different command conflicts with the existing `transitioning` reason.
  - Flow after `ProvisionReady`: reuse the existing `_enable` flow (persist
    enabled if disabled → re-inspect → start when ready). On `ProvisionFailed`
    or a thrown install error: publish the failed progress event (sanitized
    message), leave setup state as inspected, release the slot.
- The service exposes one broadcast stream of typed install progress that is
  **already coalesced at the producer** (percent changes capped at ~4/s; phase
  changes and terminal events always emit — same structural level as
  `CompletionNotifier`'s debounce). The **Orchestrator alone** maps it to SSE
  with a bare stateless `listen → enqueue`, matching its existing policy-free
  stream wiring.

### Phone (client)

- `PluginApi.command` already serializes any `PluginLifecycleCommandRequest`;
  no new endpoint.
- `PluginManagementService` consumes `pluginInstallProgress` events and exposes
  per-plugin install progress; terminal events clear it and the existing
  snapshot invalidation refreshes the row. `PluginManagementCubit` surfaces it;
  the harness card renders the Install button, phase/percent progress, and a
  dismissible failure banner reusing the existing action-error pattern.
- Analytics: one bounded account-linked event for the authoritative outcome
  (install completed/failed per harness), added via the closed event registry.
  Implementer loads `.opencode/skills/add-analytics/SKILL.md` in that step.
  No progress-level or tap-level tracking.

### Cursor managed runtime (final step)

Cursor's official installer reveals the distribution shape: versioned URL
`https://downloads.cursor.com/lab/<build>/<os>/<arch>/agent-cli-package.tar.gz`
(build like `2026.08.04-aaa8809`), a **multi-file package directory** (not a
single binary), darwin/linux × x64/arm64 only, and **no published checksums**.

- Add a Cursor manifest pinning the build and four per-platform assets, with
  checksums computed by us at pin time; extend the `update-backend-runtimes`
  skill with the Cursor digest workflow. A silently re-published asset then
  fails checksum verification with a clear message — accepted behavior (fail
  closed). Contract note: `RuntimeManifest` typed its versions as
  `SemanticVersion`, which cannot express Cursor's builds. Resolved by
  generalizing the manifest's version contract to a sealed `RuntimeVersion`
  (`SemanticRuntimeVersion` for OpenCode/Codex, `CalendarRuntimeVersion` for
  Cursor), updating OpenCode/Codex in lockstep — internal interface, no shims.
  The pin preserves the publisher's exact string, which doubles as the
  version-directory name and the download URL segment.

  Verified empirically why semver cannot serve Cursor: `2026.06.15-18-00-12-6f5a2cf`
  fails semver parsing entirely (a healthy CLI would read as absent, and the
  post-install probe would reject a correctly installed runtime), and
  `2026.07.16-899851b` sorts *below* the `2026.07.16` floor because semver
  treats the build suffix as a prerelease. `CalendarRuntimeVersion` orders on
  the date and ignores the suffix.
- Extend the runtime install machinery with a package-directory layout (place
  the whole extracted tree into the version dir, mark the entry binary
  executable) alongside the existing single-binary layout, selected by the
  asset/manifest.
- `CursorPluginDescriptor` routes managed resolution through the **same
  `ensureRuntime` + `ManagedRuntimeProvisionService` seam** OpenCode and Codex
  use (PATH → managed precedence stays in the one shared owner), surfacing the
  resolved path via `PluginHost.provisionedRuntimePath` to `start`.
  `inspectSetup` only adds the same managed-path readiness probe the other two
  descriptors already perform. This adds the
  `sesori_plugin_cursor → sesori_plugin_runtime` package dependency (allowed by
  the bridge module order; cursor already sits above runtime's layer). The
  `targetVersion` constant is superseded by the manifest pin (cleanup below).
- If the package layout proves unstable during implementation, this step may be
  deferred without blocking the rest (user-approved fallback: "include, as
  final step").

### Superseded managed runtime (step 5)

When a bridge update pins a newer runtime, the managed path is version-scoped
(`<state>/<runtime>/<version>/<binary>`) and the provision service requires an
exact `bundledVersion` match, so the previously installed copy is simply not
found: setup reports `runtimeMissing` and the harness becomes setup-blocked
until someone installs the new pin. The install capability does not depend on
setup state, so from step 4 onward the phone already offers Install in exactly
that state — the upgrade is one tap.

The remaining gap is honesty of the copy: those descriptors currently say
"Install OpenCode locally, then retry setup detection", pointing at a manual
install when an in-app button now fixes it. Step 5 distinguishes the two cases
in the descriptors' action hints — nothing found at all vs. a superseded
managed runtime — so the phone can say the runtime needs updating and that
Install will do it. Text and a probe of the existing managed directory only; no
new machinery, no change to the resolve-only `ensureRuntime` contract.

`login-note:` the same hint seam will carry the "needs login" case later.

## Delivery Sequence

One open PR at a time; every title exactly as listed.

| Step | PR title | Boundary |
|---|---|---|
| 1/6 | `🌱 [phone-harness-install] Raise the plan [step 1/6]` | This plan + tracker. |
| 2/6 | `⚙️ [phone-harness-install] Install capability, wire contracts, and descriptor install seams [step 2/6]` | Shared: `PluginManagementCapability.install`, `install()` command variant, `plugin.install.progress` SSE event + contract tests; client exhaustive-switch tolerance (same four files as the P03 precedent). Interface: `PluginControlCapability.install`, `installRuntime` descriptor seam. Plugins: OpenCode + Codex `installRuntime` implementations + capability declarations, wired to `RuntimeInstallService`/`ManagedRuntimeCleaner`, with descriptor tests. Inert until step 3 wires the command path (same additive-contract precedent as Stage 12-P02). |
| 3/6 | `🚧 [phone-harness-install] Bridge install command end to end [step 3/6]` | `PluginRuntime` install entry + fencing, repository mirror, `PluginLifecycleService` install command (accepted-immediately, existing serialization — no lock, enable/re-inspect/start on success, sanitized failure), `RuntimeInstallService` doc-contract update, handler mapping for the new variant, Orchestrator SSE emission with throttling. Focused service/runtime/handler/orchestrator tests. |
| 4/6 | `⚙️ [phone-harness-install] Phone install button and progress [step 4/6]` | `PluginManagementService` progress consumption, cubit state, harness-card Install button + progress + failure banner, l10n, bounded analytics event, widget/service tests. |
| 5/6 | `🚧 [phone-harness-install] Cursor managed runtime and install [step 5/6]` | Cursor manifest (pinned build + self-computed checksums), package-directory install layout, `ensureRuntime`-based managed resolution + capability, `sesori_plugin_cursor → sesori_plugin_runtime` dependency, superseded-managed-runtime action hints (below), `update-backend-runtimes` skill extension, tests. |
| 6/6 | `🌱 [phone-harness-install] Retire the plan [step 6/6]` | Move plan to `.plan/completed/`. |

Line-count note: step 2 may exceed the 1,500-line soft cap because Freezed/JSON
codegen for the SSE union and management models is bulky; the source diff is
moderate. Recorded here per policy.

## Verification

- Step 2: `shared/sesori_shared` codegen + tests + analyze; interface,
  OpenCode, Codex plugin tests + `dart analyze --fatal-infos`; affected
  `client/module_core` tests.
- Step 3: bridge `app/` lifecycle/runtime/handler/orchestrator tests +
  `dart analyze --fatal-infos`.
- Step 4: `module_core` service/cubit tests, `client/app` widget tests,
  `dart analyze` per touched module.
- Step 5: cursor + runtime plugin package tests + fatal analysis; manual
  checksum pin verification against the live installer.
- CI supplies the full matrix; do not duplicate it locally.

## Evidence And Accepted Risks

- **Concurrency**: reuses the existing per-plugin active-command slot,
  setup-gated start exclusion, and single-live-bridge enforcement; no new
  locks, registries, or lifecycle owners.
- **Interrupted install** (bridge dies mid-download): already self-healing —
  the sentinel is written last, staging/download paths are fixed and cleaned,
  so the next attempt redoes the install. No resume support; downloads are
  tens of MB — accepted.
- **Progress event loss**: SSE is best-effort; the terminal state always also
  arrives via snapshot invalidation, so a phone can never be stuck on a stale
  progress display beyond one snapshot refresh. Accepted transient.
- **Windows Cursor**: capability simply absent; no error path to build.
- **In-place asset republish (Cursor)**: install fails checksum verification
  with a clear message; user retries after we re-pin. Accepted (fail closed
  beats trusting an unverifiable download).
- No guard is added for flows no caller produces (e.g. install on a plugin
  without the capability is a plain 409 conflict via the existing capability
  check pattern).

## Follow-Up: Automatic Managed Runtime Updates

**Discuss after step 6 merges and this plan is retired — deliberately out of
scope here.**

There is no automatic upgrade of a managed runtime when a bridge update pins a
newer one. `ManagedRuntimeProvisionService` used to download at startup; that
was removed in `4ef55675` (#507), which made `ensureRuntime` strictly
resolve-only ("must never download, install, sweep, or otherwise mutate a
runtime"). The commit body is empty, so the recorded rationale is lost; the
constraint is consistent with startup holding the cross-instance mutex, where a
multi-minute download would stall a healthy bridge. Nothing under
`bridge/app/lib/src/updater/` correlates an installed managed version with a
newly pinned one (the similarly named `managed_runtime_path_service.dart` and
`managed_runtime_manifest_api.dart` concern the bridge's own binary).

After this plan the upgrade costs one deliberate tap per bridge update, per
harness, with honest copy telling the user why. Making it automatic reverses
`4ef55675` and needs, at minimum:

- an explicit owner outside the startup mutex (update-time or post-start
  trigger), since the resolve-only contract must not be weakened;
- a product decision on downloading tens of MB unprompted, including metered
  connections; and
- behavior for a bridge running headless where nobody ever opens the app.

That is a product call plus its own architecture, not an implementation detail
of this plan.

## Review Record

- Architecture plan review (2026-08-08): first version rejected with three
  findings — unowned startup-mutex acquisition (with a self-pid release
  hazard), progress-throttling state placed in the Orchestrator, and Cursor
  managed resolution bypassing the shared `ensureRuntime` seam plus a
  `SemanticVersion`/CalVer manifest mismatch and undeclared package
  dependency. All applied: no lock (existing serialization suffices),
  producer-side coalescing with a stateless Orchestrator listen, and Cursor on
  the shared seam with a generalized opaque version pin and declared
  dependency.

- Architecture implementation review (step 5): rejected with three findings —
  the approved version-pin generalization had been skipped in favour of a
  Cursor-side raw-string fork (leaving two incompatible version authorities),
  `RuntimeAsset.layout` added as an optional defaulted parameter on an internal
  contract, and `RuntimeAsset`'s doc comment absorbed into the new enum's. All
  three applied: sealed `RuntimeVersion` with lockstep OpenCode/Codex updates
  and `CursorPluginDescriptor.minVersion`/`_CalVer` retired in favour of the
  manifest, `layout` made required and declared explicitly on every asset, docs
  restored. The skipped generalization was a genuine implementation error —
  the earlier decision to skip it rested on testing only one Cursor build
  string.

## Cleanup Assessment

- `RuntimeInstallService` and `ManagedRuntimeCleaner` regain production
  callers (they are currently test-only); no code moves needed.
- Cursor's `targetVersion` constant is superseded by the manifest pin and is
  removed in step 5, along with its private `_CalVer` comparator (replaced by
  the shared `CalendarRuntimeVersion`).
- `installDocsUrl` manual-install hints in `ProvisionFailed` messages remain
  valid for headless/CLI users; no removal.
- No other obsolete calculations, fields, transport members, or jobs found.
