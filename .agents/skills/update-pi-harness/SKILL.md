---
name: update-pi-harness
description: >-
  Audit and update Sesori's Pi Agent Harness target while finding protocol
  capabilities, event changes, and simplifications worth integrating. Use when
  refreshing the Pi runtime pin or reviewing a new Pi release.
compatibility: opencode
metadata:
  audience: maintainers
  workflow: github
---

# Update the Pi Harness Target

This repository skill lives under `.agents/skills/` so the agent harness can
load it alongside the other repository skills.

Refresh the Sesori Pi plugin against the latest stable release of
[`earendil-works/pi`](https://github.com/earendil-works/pi), but treat a target
bump as a protocol audit rather than a version-only edit. The outcome should
identify useful upstream capabilities, distinguish externally observable RPC
behavior from extension-only behavior, and propose the smallest Sesori changes
that improve or simplify the integration.

This skill is intentionally Pi-only. Use `update-backend-runtimes` for a
multi-harness refresh.

## Scope and invariants

Relevant production files normally include:

- `bridge/sesori_plugin_pi/lib/src/runtime/pi_runtime_manifest.dart`
- `bridge/sesori_plugin_pi/lib/src/api/models/pi_event.dart`
- `bridge/sesori_plugin_pi/lib/src/api/models/pi_assistant_delta.dart`
- `bridge/sesori_plugin_pi/lib/src/api/models/pi_rpc_frame.dart`
- `bridge/sesori_plugin_pi/lib/src/models/pi_rpc_command.dart`
- `bridge/sesori_plugin_pi/lib/src/repositories/pi_session_process_repository.dart`
- `bridge/sesori_plugin_pi/lib/src/services/pi_event_dispatcher.dart`
- `bridge/sesori_plugin_pi/lib/src/services/pi_session_service.dart`
- `bridge/sesori_plugin_pi/test/pi_runtime_manifest_test.dart`
- `bridge/sesori_plugin_pi/test/pi_plugin_descriptor_test.dart`

Preserve these invariants unless the user explicitly approves a separate
compatibility change:

- Keep `PiRuntimeManifest.minPathVersion` byte-for-byte unchanged.
- Keep Pi's complete package-directory archive layout. Unix archives contain a
  `pi/` package tree; Windows archives are a package tree with `pi.exe`.
- Keep strict JSONL framing, request-ID correlation, delta-only message updates,
  and `message_end` as final message authority.
- Preserve the user's Pi profile, credential sources, and runtime settings.
  Never put secrets, prompts, transcripts, paths, or raw provider errors in
  reports or commits.
- Never hand-edit generated Dart files.

## Phase 1 — Establish the candidate

1. Read the current target and minimum from `PiRuntimeManifest`, its tests, and
   the registered plugin list. Verify the Pi descriptor/registry seam in
   `bridge/app/lib/src/runtime/plugin_registry.dart`, including the descriptor
   registration and manifest wiring. Record both values before touching
   anything.
2. Query the latest GitHub release, not an arbitrary `main` commit:

   ```bash
   gh api repos/earendil-works/pi/releases/latest --jq \
     '{tag: .tag_name, prerelease: .prerelease, draft: .draft,
       published_at: .published_at, assets: [.assets[] | {name, digest, size}]}'
   ```

   Ignore drafts and prereleases. The target is the stable `vX.Y.Z` release
   tag. Do not silently select an unreleased commit because it contains a
   promising feature.
3. Require exactly these six managed assets, with non-null GitHub `sha256:`
   digests:

   - `pi-darwin-arm64.tar.gz`
   - `pi-darwin-x64.tar.gz`
   - `pi-linux-arm64.tar.gz`
   - `pi-linux-x64.tar.gz`
   - `pi-windows-arm64.zip`
   - `pi-windows-x64.zip`

   Download `SHA256SUMS` when present and confirm every line agrees with the
   GitHub asset digest. Do not guess mappings, accept a missing digest, flatten
   an archive, or invoke Pi's installer scripts.

## Phase 2 — Audit the release diff in aggregate

Compare the release commits directly before reading individual commits:

```bash
gh api repos/earendil-works/pi/compare/v<old>...v<new>
```

Treat the compare response as a bounded API result, not proof of completeness.
Check its status, `total_commits`, returned commit count, returned file count,
`Link`/pagination metadata, and any API truncation indication. Use
`gh api --paginate` where pagination is advertised and aggregate the pages. If
those checks cannot prove that the changed-file list is complete (GitHub can
cap compare-file results), do not classify protocol changes from it; use a
local tag-diff fallback instead:

```bash
tmp_repo="$(mktemp -d)"
trap 'rm -rf "$tmp_repo"' EXIT
git clone --filter=blob:none --no-checkout --quiet \
  https://github.com/earendil-works/pi.git "$tmp_repo/pi"
git -C "$tmp_repo/pi" fetch --quiet --no-tags origin \
  refs/tags/v<old>:refs/tags/v<old> refs/tags/v<new>:refs/tags/v<new>
git -C "$tmp_repo/pi" diff --name-status v<old> v<new>
git -C "$tmp_repo/pi" diff v<old> v<new> -- packages/
git -C "$tmp_repo/pi" diff --stat v<old> v<new>
```

The fallback must include the complete tag diff (or a separately paginated
per-commit inventory) before a capability is marked absent. Remove the
temporary clone after the audit. Prefer a derived summary of commit titles,
changed paths, additions/deletions,
and selected patches over dumping the full JSON response. A complete
commit-by-commit deep read is optional; when the range is large, a lightweight
scout/delegate may inventory every commit title and changed area, while the
main review uses the aggregate tag diff for evidence. Do not let an agent edit
the Sesori worktree or create another worktree.

For any nontrivial subagent reasoning or synthesis, use the exact registered
model `openai-codex/gpt-5.6-luna` with maximum thinking effort (after checking
the available model registry). Keep lightweight inventory work separate from
smart review work.

Search the aggregate diff, release changelogs, and source at both tags for:

- top-level JSONL/RPC event names and field changes;
- `agent_start`, `agent_end`, `agent_settled`, `turn_start`, `turn_end`, and
  tool execution lifecycle semantics;
- `extension_ui_request`, `ui_prompt_start`, `ui_prompt_end`, and other
  extension/UI events;
- `session_compact_failed`, compaction/retry ordering, queue behavior, and
  session-file/history changes;
- RPC commands/responses, exact field casing, acceptance versus completion,
  and new cancellation/queue controls;
- `message_update` delta shape, tool-call metadata, message persistence, image
  support, and new tool names;
- model/provider/auth discovery, launch flags, bundled runtime behavior, and
  package/archive changes.

Inspect source, not only release notes. For each candidate capability, record:

1. the upstream tag/commit and exact source path;
2. the wire shape and field types/casing;
3. ordering and completion semantics;
4. whether it is emitted by `session.subscribe()`/`toJsonEvent()` in RPC mode,
   by the extension event bus only, or through a separate request frame; and
5. the smallest concrete Sesori flow that would benefit.

### Do not confuse extension events with RPC events

An event being accepted by `pi.on(...)` does not mean an external RPC client
can observe it. Verify that it belongs to the serialized `AgentSessionEvent`
union and that `rpc-mode.ts` forwards it. For example, `ui_prompt_start` and
`ui_prompt_end` may describe blocking `ctx.ui.*` waits and may be extension-bus
only; in RPC mode the observable equivalent can instead be an
`extension_ui_request`. State this distinction explicitly rather than adding a
parser for an event the wire never emits.

Likewise, `agent_end` is a low-level loop boundary and may be followed by retry,
compaction, or queued work. Use `agent_settled` as the final user-visible
completion signal unless current source proves otherwise. Treat
`turn_start`/`turn_end` as per-turn boundaries and tool execution events as
per-tool boundaries.

Classify findings:

- **Adopt now:** directly observable, stable, and fixes a demonstrated Sesori
  limitation or removes existing workaround code.
- **Probe first:** promising but dependent on authenticated behavior, a new
  package entrypoint, platform-specific assets, or an untested ordering.
- **Track only:** extension-only, interactive-TUI-only, provider-specific, or
  unrelated to the current bridge contract.
- **Reject:** speculative defenses or compatibility machinery without a real
  caller and meaningful damage.

### Choose a compatibility shape deliberately

For a real version difference, first try one tolerant implementation: preserve
unknown frames, make newly introduced transport fields optional where an older
Pi can legitimately omit them, and degrade to the existing behavior. Do not
add version branches merely because an API technically permits them.

If the semantics are genuinely incompatible and the compatibility code is large
or hard to reason about, explicitly evaluate a narrow shared interface with two
Pi-version-specific implementations. Select the implementation only from a
validated runtime version/provenance (the managed manifest or a validated PATH
probe); Pi has no handshake, so never infer a version from an event or silently
assume the binary behind `PATH`. Keep both implementations inside the Pi plugin
and do not leak Pi-specific concepts into `bridge/app/` or client contracts.

For every retained compatibility branch, comment the exact older Pi behavior it
preserves and the first minimum Pi version that no longer needs the branch. Use
this marker directly above the retained field/branch:

```dart
// COMPATIBILITY YYYY-MM-DD (v1.8.3): Pi <= <old> omits <behavior>; remove this
// fallback when PiRuntimeManifest.minPathVersion is raised to <new>.
```

Use the current product version in the marker, not a package version. If a
single tolerant path is sufficient, prefer it over the two-implementation
interface; if neither path has a concrete caller and meaningful damage, reject
both as speculative machinery.

## Phase 3 — Run a safe current-host probe

Before changing the target, validate the candidate archive on the current host
in a temporary directory:

1. Download the matching official archive and verify its SHA-256.
2. Inspect/extract it without changing the repository. Confirm the package tree
   and platform-specific entrypoint remain intact. Resolve that entrypoint to
   an absolute path and invoke that path for every check; never invoke a bare
   PATH-installed `pi`. If a temporary PATH wrapper is more convenient, put
   only a symlink/copy to the extracted entrypoint first and assert that
   `command -v pi` (or the Windows equivalent) resolves inside the probe root.
3. Create an empty temporary project cwd and isolated temporary `HOME`, Pi
   data/session roots, and host-specific config/cache roots. Explicitly set
   `PI_CODING_AGENT_DIR` and `PI_CODING_AGENT_SESSION_DIR` to temporary
   directories (or unset them while proving the defaults also resolve inside
   the probe root); do not inherit the user's values. On Windows also isolate
   `USERPROFILE`, `APPDATA`, and `LOCALAPPDATA` as applicable. Do not read or
   mutate the user's normal profile.
4. Verify the absolute entrypoint's `--version` output identifies exactly the
   candidate release, rather than merely returning success. Preserve the
   normal environment policy in the production launch design.
5. Launch the extracted entrypoint with exactly these arguments:

   ```text
   --mode rpc --no-session --approve
   ```

   Inject `PI_SKIP_VERSION_CHECK=1` using the host's environment syntax (`env`
   on POSIX, `$env:PI_SKIP_VERSION_CHECK = '1'` before `& $entrypoint` in
   PowerShell), and keep the empty temporary cwd as the process working
   directory. Do not use a PATH-installed binary.

6. Write this exact newline-delimited request to the child stdin:

   ```json
   {"id":"probe-1","type":"get_state"}
   ```

   Within a bounded 10-second read timeout, parse stdout records until the
   matching response and assert `id == "probe-1"`, `type == "response"`,
   `command == "get_state"`, `success == true`, and `data` is an object. Reject
   malformed JSON, an unexpected matching response, or a timeout; unrelated
   event records may be drained but must not be mistaken for the response.
   After the assertion, close stdin, wait up to 2 seconds for clean exit, then
   send SIGTERM and finally SIGKILL only if needed. Always remove the temporary
   archive, extraction root, profile roots, project cwd, and probe logs with a
   cleanup trap/finally block.
7. If the release changes a command/event surface that Sesori may adopt, run a
   focused additional probe for that surface. Stop on a startup, framing,
   response-correlation, package-layout, isolation, or required-surface
   regression. Do not pin a candidate based on a version output alone.

Keep probe output redacted and bounded. Do not retain raw frames, credentials,
transcripts, prompts, project paths, or provider/account identifiers.

## Phase 4 — Report and approval gate

Before editing the runtime target or production protocol code, report:

- current target and candidate stable release/date;
- unchanged PATH minimum;
- all six asset names, sizes, and verified SHA-256 values;
- aggregate diff size and the high/medium findings with source links;
- which findings are truly visible on JSONL/RPC stdout;
- probe results and any platform limitations;
- proposed Sesori edits, explicitly separating version-only changes from
  capability changes, simplifications, and follow-up work;
- the compatibility strategy: tolerant single path versus a justified
  version-selected interface with two implementations, including each
  branch's retirement/minimum version.

Ask the user to approve the proposed production changes. A release audit is
not permission to expand scope, raise the compatibility floor, or implement
interesting but unverified upstream behavior. The skill-only documentation PR
may proceed when explicitly requested, while the runtime/capability PR remains
behind this gate.

## Phase 5 — Implement only after approval

For an approved target refresh:

1. Update only `PiRuntimeManifest.targetVersion` and the six corresponding
   digests. Keep `bundledVersion` derived from the target and preserve all
   archive formats/layouts.
2. Update target-specific URLs, assertions, and managed-path fixtures. Preserve
   old-version fixtures that test the compatibility floor or historical behavior.
3. For an approved capability, add typed command/event models at the wire
   boundary, map them through the owning Pi plugin, and add focused tests for
   exact field casing, ordering, unknown-field degradation, and failure paths.
   Prefer one tolerant implementation. If a real incompatible semantic
   difference makes the change substantial, document why a narrow shared
   interface with two version-specific implementations is warranted, how the
   validated runtime version selects it, and when each branch can be removed.
   Do not expose Pi concepts in bridge `app/` or client layers unless an
   existing backend-neutral contract already supports them.
4. Put a dated `COMPATIBILITY` comment directly above every retained
   version-specific field or branch. State the older Pi behavior being kept and
   the minimum Pi version at which that code is no longer needed; do not leave
   an unexplained fallback or use a package version in the marker.
5. For queue/cancellation changes, prove which work is owned by Sesori's
   admission queue versus Pi's internal steering/follow-up queue before
   replacing the existing teardown or retry behavior.
6. Update `docs/regression/` only when supported behavior materially changes or
   a compatibility floor changes. A target-only refresh does not justify a new
   regression tombstone.
7. Run `dart format` on changed Dart files; never edit generated outputs.

## Verification and delivery

Run focused verification for the changed package and inspect the diff:

```bash
(cd bridge/sesori_plugin_pi && dart test && dart analyze --fatal-infos)
git diff --check
git diff -- bridge/sesori_plugin_pi
# Stage the documentation file first, or use `git diff --no-index /dev/null ...`
# while it is untracked, so the skill itself is reviewed too.
git diff HEAD -- .agents/skills/update-pi-harness/SKILL.md
```

If the change affects shared runtime primitives, also run the owning foundation
or runtime package tests. Do not rerun unchanged suites without a concrete
reason.

Keep the skill/documentation change in its own reviewable PR when requested;
do not mix it with the Pi runtime or protocol implementation PR. Use a real
multiline PR body with these sections:

- `## Complexity`
- `## What`
- `## Why`
- `## Risk and test focus`
- `## Expected result`
- `## Verification`

Use the repository's implementation-complexity emoji prefix, commit and push
when the task is ready for review, open the PR, and start the PR monitor
immediately. Never enable auto-merge; the user merges.

The final implementation report must state the old/new target, unchanged
minimum, six digest status, adopted/deferred findings, probe result, tests,
and any remaining upstream or platform risks.
