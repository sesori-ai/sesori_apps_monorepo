---
name: update-codex-harness
description: >-
  Audit and update Sesori's Codex harness target while finding app-server
  protocol capabilities, event changes, and simplifications worth integrating.
  Use when refreshing the Codex runtime pin or reviewing a new Codex release.
metadata:
  audience: maintainers
  workflow: github
---

# Update the Codex Harness Target

Refresh the Codex plugin against the latest stable release of
[`openai/codex`](https://github.com/openai/codex). Treat a target bump as a
protocol audit, not a version-only edit. Find useful upstream capabilities and
small simplifications, distinguish app-server wire behavior from internal/TUI
behavior, and obtain approval before changing production code.

This is the Codex counterpart of `.agents/skills/update-pi-harness/SKILL.md`,
not a Pi RPC recipe. It is intentionally Codex-only. For a multi-harness refresh,
read `.opencode/skills/update-backend-runtimes/SKILL.md` from the repository
root; stop and report a missing handoff if absent. Use the current Codex manifest
as the asset-layout authority: older instructions may describe obsolete bare
CLI archives. Do not substitute those for canonical package archives.

## Scope and invariants

Read `bridge/AGENTS.md` before production edits. Inspect:

- `bridge/sesori_plugin_codex/lib/src/runtime/codex_runtime_manifest.dart`
- `bridge/sesori_plugin_codex/lib/src/runtime/codex_plugin_descriptor.dart`
- `bridge/sesori_plugin_codex/lib/src/runtime/codex_managed_api.dart`
- `bridge/sesori_plugin_codex/lib/src/runtime/codex_runtime_policy.dart`
- `bridge/sesori_plugin_codex/lib/src/codex_plugin_impl.dart`
- `bridge/sesori_plugin_codex/lib/src/codex_app_server_client.dart`
- `bridge/sesori_plugin_codex/lib/src/codex_stdio_app_server_client.dart`
- `bridge/sesori_plugin_codex/lib/src/api/codex_app_server_api.dart`
- `bridge/sesori_plugin_codex/lib/src/api/models/`
- `bridge/sesori_plugin_codex/lib/src/codex_event_mapper.dart`
- `bridge/sesori_plugin_codex/lib/src/services/`
- `bridge/sesori_plugin_codex/test/runtime/codex_runtime_manifest_test.dart`
- `bridge/sesori_plugin_codex/test/runtime/codex_plugin_descriptor_setup_test.dart`
- `bridge/app/lib/src/runtime/plugin_registry.dart`

Preserve these invariants:

- Keep the `minPathVersion` backing declaration byte-for-byte unchanged unless
  the user separately approves a higher compatibility floor.
- Keep all six canonical package-directory archives, including Windows tar.gz.
  Preserve `bin/codex` / `bin/codex.exe`, `codex-code-mode-host`, and resources
  in their original relative positions. Never flatten to a lone executable.
- Preserve request-ID correlation, server-request versus response separation,
  capability negotiation, and each production transport's handshake. Stdio sends
  `initialized` after `initialize`; the current WebSocket client does not.
  Verify upstream requirements before proposing a handshake change.
- Distinguish request acceptance from completion. Verify `turn/completed`,
  item finalization, interrupt, steering, and queued-work semantics from source;
  do not import Pi's `agent_settled` or `get_state` assumptions.
- Preserve production user profiles, credential sources, settings, approval
  and sandbox policy. Credential-free probes must not replace production policy.
- Never put secrets, prompts, transcripts, user/project/local filesystem paths,
  account identifiers, or raw provider errors in audit reports or commits.
  Public upstream source paths and immutable links are useful evidence.
- Keep Codex concepts inside its plugin; never hand-edit generated Dart files.
- Use the caller's dedicated worktree. Do not create another worktree or checkout
  when prohibited. Use a temporary bare object store under the existing worktree
  for upstream source, never Sesori's shared Git database or shallow metadata.
  Never execute upstream build code there.

## Phase 1 — Establish the candidate

1. Record current target, PATH minimum, descriptor registration, manifest wiring,
   and package layout from source and tests before touching anything.
2. Fetch stable GitHub release metadata and, when available, npm's stable version:

   ```bash
   gh api repos/openai/codex/releases/latest
   npm view @openai/codex version
   ```

   Process the response into a bounded report: tag, date, draft/prerelease flags,
   release notes, and relevant asset names/digests/sizes. Require a stable
   `rust-vX.Y.Z` tag; store only `X.Y.Z` in the manifest. Require npm agreement
   when npm is available; report unavailable evidence or channel disagreement,
   never silently choose `main`, an alpha, or a different distribution.
3. Require exactly one of each managed asset with a non-null `sha256:` digest:

   - `codex-package-aarch64-apple-darwin.tar.gz`
   - `codex-package-x86_64-apple-darwin.tar.gz`
   - `codex-package-aarch64-unknown-linux-musl.tar.gz`
   - `codex-package-x86_64-unknown-linux-musl.tar.gz`
   - `codex-package-aarch64-pc-windows-msvc.tar.gz`
   - `codex-package-x86_64-pc-windows-msvc.tar.gz`

   Other release assets are allowed, but cannot replace these six. Download
   `codex-package_SHA256SUMS` when present, verify its own GitHub digest, and
   require each managed asset line to agree with GitHub. Metadata agreement is
   not downloaded-archive verification. Do not guess renamed/missing mappings
   or execute installers.
4. Resolve current and candidate tags to full immutable commit SHAs through
   `repos/openai/codex/commits/rust-v<version>`. Record both before diffing or
   downloading. Re-resolve both tags before using a diff and immediately before
   approval; require exact equality. A moved, missing, or ambiguous tag requires
   stopping and restarting the audit. Use recorded SHAs, not tags, afterward.
5. Verify source-to-artifact provenance for every managed archive. Inspect the
   designated release workflow and published provenance at the recorded SHA.
   Accept an attestation only after a trusted verifier cryptographically checks
   it, enforcing an allowlisted issuer, exact `openai/codex` repository and
   designated release-workflow identity, audited commit, and artifact digest.
   Matching unverified fields or a self-signed statement are insufficient.
   Otherwise reproduce every archive from the recorded SHA in a disposable
   container/VM/restricted account with no secrets or sensitive mounts and
   tightly constrained outbound access; compare normalized contents and digest.
   If neither path is available, mark provenance unverified and pinning blocked.
   A GitHub digest, platform code signature, or benign probe alone does not prove
   that the audited source produced the archive.

## Phase 2 — Audit the aggregate release diff

Compare recorded old/new SHAs directly using
`repos/openai/codex/compare/<oldSha>...<newSha>` before individual commits.
Check comparison status, total/returned commits, file count, pagination/Link
metadata, and truncation indicators. Paginate where advertised. GitHub caps
compare-file lists; a 300-file response is not a complete inventory. An absent
patch is not proof of an unchanged surface.

If completeness cannot be established, obtain exact source-only objects and
use a complete Git diff. Create a disposable bare object store under the current
worktree, not another checkout or working directory. Keep every upstream Git
command bound to that store: `--no-write-fetch-head` alone does not isolate
objects or `.git/shallow` from Sesori's shared repository. Stop on any command
failure and retain partial evidence until the interruption is recorded.

```bash
# Set these to the recorded full 40-hex SHAs; never substitute mutable tags.
set -e
audit_git_dir="$(mktemp -d "$PWD/.codex-audit-git.XXXXXX")"
git init --bare "$audit_git_dir"
audit_git() { git --git-dir="$audit_git_dir" "$@"; }
audit_git fetch --no-tags --no-write-fetch-head --depth=1 https://github.com/openai/codex.git "$old_commit_sha"
audit_git fetch --no-tags --no-write-fetch-head --depth=1 https://github.com/openai/codex.git "$new_commit_sha"
audit_git cat-file -e "$old_commit_sha^{commit}"
audit_git cat-file -e "$new_commit_sha^{commit}"
audit_git diff --name-status "$old_commit_sha" "$new_commit_sha"
audit_git diff --stat "$old_commit_sha" "$new_commit_sha"
audit_git diff --no-ext-diff --no-textconv "$old_commit_sha" "$new_commit_sha" -- > "$audit_git_dir/release.patch"
```

Retain the store and patch until all changed paths have been inspected, or record
interruption/incompleteness; do not delete them in an early EXIT trap. Inspect
every changed area, including release workflows, package builders, dependencies,
schemas, and launch wrappers. Use
`git --git-dir="$audit_git_dir" show <recordedSha>:<path>` for source without
checking it out. Summarize large patches in code; do not dump raw JSON or full
patches into conversation. After consuming the evidence, explicitly remove only
this audit's temporary store with `rm -rf -- "$audit_git_dir"`; never clean,
prune, or rewrite Sesori's shared Git metadata as part of this recipe.

For nontrivial delegated reasoning, inspect available agents/models and prefer
registered `openai-codex/gpt-5.6-luna` with maximum thinking when selectable.
If unavailable, use the current model/effort or another available selector and
record the fallback. Keep lightweight inventory separate from synthesis; do not
let a delegate edit production files or create another worktree.

Inspect source at both SHAs, aggregate patches, intermediate stable release
notes, and checked-in generated schemas. Search these surfaces:

- `codex-rs/app-server-protocol/`, `codex-rs/app-server/`, their tests and schemas;
- initialization, experimental capabilities, connection authentication and
  attestation requests, WebSocket versus stdio behavior, field casing/types;
- `thread/*` and `turn/*` lifecycle, list/read/resume/fork/archive/rollback,
  steering, interrupts, compaction, queue ownership and completion ordering;
- `item/*` deltas and final items, tools/code mode, subagents, images, files,
  tool-result persistence and rollout/history representation;
- server-originated approval, permissions, user-input, dynamic-tool and auth
  requests; matching replies, cancellation and resolution;
- model/provider/account discovery, login/rate-limit notifications, skills,
  collaboration modes, launch flags, and package/helper/resource changes.

For each candidate capability record immutable upstream source links, exact
wire names/types/casing, ordering/acceptance/completion semantics, capability or
experimental gates, transport visibility, and the smallest concrete Sesori flow
that benefits. A Rust enum, core event, TUI feature, or `codex exec --json` record
is not automatically an app-server v2 notification: trace serialization and
forwarding through the app-server protocol and processor. Schema presence alone
does not prove emission or ordering; release-note silence does not prove absence.

Classify findings:

- **Adopt now:** stable, observable, fixes a demonstrated limitation or removes
  an existing workaround; still subject to approval and live validation.
- **Probe first:** authenticated, experimental, platform-specific, a new launch
  surface, or ordering not yet demonstrated.
- **Track only:** internal/TUI/exec-only, unrelated, or no current consumer.
- **Reject:** speculative defenses, unneeded compatibility, or broad refactors.

Prefer one tolerant implementation for supported older PATH runtimes: ignore
unknown events appropriately, permit legitimately omitted new fields, and retain
existing behavior. Do not add version branches merely because shapes differ.
For genuinely incompatible semantics, evaluate a narrow interface with two
version-specific implementations inside the plugin. Select only from validated
runtime version/provenance or an explicitly verified handshake identity, never
an incidental event or an assumed PATH binary version. State branch retirement
and minimum version. Never weaken approval or sandbox semantics to accommodate
an older runtime.

## Phase 3 — Safe current-host probe

Verify the downloaded SHA-256 of all six managed archives as opaque bytes;
checksum validation does not require extracting or launching them. Run the
installation and live probes below only for the archive matching the current
host OS and architecture. Other platforms do not need installation or launch
probes to approve a target refresh; report them as untested, not validated by
the host result. Record the tested asset and digest, OS/architecture, disposable
boundary, production extraction/placement, exact version, stdio handshake, and
WebSocket handshake results. Both current-host transports must be checked.

1. Establish a current-host disposable VM/container/restricted OS account before
   parsing archive contents. No sensitive mounts; block outbound network access
   (local loopback may be allowed for WebSocket probes). Temporary HOME or
   environment filtering alone is not a sandbox. If no boundary is available,
   do not inspect, extract, or execute the host archive; report the current-host
   probe as blocked.
2. Download the current-host archive inside that boundary, or transfer opaque
   bytes into it. Verify its SHA-256 before parsing. Keep other archives opaque
   unless an optional platform-specific check is warranted.
   Inspect `CodexPluginDescriptor.installRuntime()`
   for production wiring, but do not call it for a newer candidate: it hard-codes
   the current manifest. Start at `ManagedRuntimeComposition.createInstaller()`
   with a temporary candidate manifest and matching asset resolver, then exercise
   `ManagedRuntimeInstallService.install()`, `RuntimeInstallService.install()`,
   and `ArchiveExtractor.extract()` inside the boundary. Inspect:

   - `bridge/sesori_plugin_runtime/lib/src/composition/managed_runtime_composition.dart`
   - `bridge/sesori_plugin_runtime/lib/src/provisioning/managed_runtime_install_service.dart`
   - `bridge/sesori_plugin_runtime/lib/src/provisioning/runtime_install_service.dart`
   - `bridge/sesori_bridge_foundation/lib/src/archive_extractor.dart`

   Supply only disposable state roots and candidate manifest data in the probe;
   do not edit the production pin to run it. Strip GitHub's `sha256:` prefix and
   require a 64-character hexadecimal digest for each temporary candidate asset.
   Assert the final managed path is `<stateDirectory>/codex/<version>/bin/codex`
   (Windows: `bin/codex.exe`). Compare the complete placed archive payload with
   the extracted package, including helper and resource files, excluding only
   installer metadata `RuntimeInstallService.sentinelFileName`. Separately assert
   that `.sesori-runtime-sha256` contains the candidate's bare digest. Generic
   tar extraction or a lone executable check is not a substitute. Apply production
   traversal/link rejection, including rejection of all extracted symlinks.
   Failure to run this chain blocks the current-host probe.
3. Resolve the extracted entrypoint to an absolute path inside the package.
   Never use bare PATH `codex`, copy the CLI away from its helpers, or launch
   the user's Codex Desktop app or existing app-server.
4. Create empty temporary project, HOME, `CODEX_HOME`, config/cache/temp roots;
   on Windows also isolate `USERPROFILE`, `APPDATA`, and `LOCALAPPDATA`.
   Construct an allowlisted child environment with only required system/locale
   variables and safe runtime paths. Exclude API keys, tokens, cloud credentials,
   `SSH_AUTH_SOCK`, credential helpers, and user/project config or MCP servers.
   Do not authenticate, submit prompts, or read existing sessions. Authenticated
   probes require a separately authorized procedure and approved credentials.
5. Run the exact entrypoint's `--version`, bounded to 10 seconds. Assert it
   identifies the candidate version exactly, not merely exit success. Use the
   same process-tree cleanup guarantee as below even for this short process.
6. Launch that entrypoint with `app-server --listen stdio://` from the empty cwd.
   Confirm these fields against the candidate source and production client; send
   newline-delimited requests without adding a `jsonrpc` field by assumption:

   ```json
   {"id":"probe-init","method":"initialize","params":{"clientInfo":{"name":"sesori_runtime_probe","title":"Sesori Bridge","version":"0.0.0"}}}
   ```

   Within 10 seconds require matching ID, no `error`, and object `result` with
   required typed identity fields from `CodexInitializeResult` (inspect current
   source). Do not print returned local paths or identity details. Then send:

   ```json
   {"method":"initialized"}
   {"id":"probe-list","method":"thread/list","params":{"limit":1}}
   ```

   Require a matching successful result with array `data` and the candidate's
   pagination shape; the isolated profile should contain no user threads.
   Drain unrelated notifications; a server-originated request with `method`
   plus `id` is never a response. Fail on malformed JSON, unexpected matching
   response, startup failure, or timeout. Keep this production stdio probe free
   of experimental capabilities; test experimental surfaces separately.
7. Probe managed WebSocket separately, using `codex_runtime_policy.dart` launch
   arguments (`app-server --listen ws://127.0.0.1:<port>`) and the client composed
   in `codex_plugin_impl.dart`. Bind only loopback with a fresh available port.
   Send each object below as its own WebSocket text frame, not an NDJSON stream:

   ```json
   {"jsonrpc":"2.0","id":"probe-init","method":"initialize","params":{"clientInfo":{"name":"sesori_runtime_probe","title":null,"version":"0.0.0"},"capabilities":{"experimentalApi":true,"requestAttestation":false,"optOutNotificationMethods":null}}}
   ```

   Require the same correlated typed initialization result within 10 seconds.
   The current production WebSocket client sends no `initialized` notification;
   reproduce that behavior and verify candidate source accepts it. If it does
   not, report a compatibility regression rather than silently adding the frame
   to make the probe pass. After successful initialization, send:

   ```json
   {"jsonrpc":"2.0","id":"probe-list","method":"thread/list","params":{"limit":1}}
   ```

   Apply the same 10-second deadline, result-shape checks, malformed-frame and
   server-request separation rules as stdio. Preserve production capabilities
   and reject unexpected listener/authentication changes. Do not reuse stdio
   envelopes or treat stdio success as validation of the WebSocket connection.
8. Put every launch and assertion inside `try/finally`. Close stdin/socket, wait
   at most 2 seconds, then terminate the complete process tree. POSIX: dedicated
   process group/session, SIGTERM then SIGKILL if needed. Windows: kill-on-close
   Job Object or recursive descendant termination with re-enumeration; killing
   only the parent is insufficient. Keep cleanup bounded. Remove probe files,
   logs and sandbox only after descendants are gone, on success or failure.
9. Run focused probes for every proposed changed surface, including ordering,
   capability gates, and required helpers. Schema generation inside the same
   boundary can supplement probes, not replace live protocol checks.

Skipped or failed provenance, current-host extraction, version, or required
current-host transport checks block the target refresh. Missing install/launch
results for other platforms do not block it. Optional platform checks may be
added for a concrete release change or regression; report any observed failure.
All six archive digests and source-to-artifact verification remain required.
Never mix old digests with a new shared release URL. Continue source-only audit
and report useful findings even when pinning is blocked; label them unprobed.

## Phase 4 — Report and approval gate

Before editing target or protocol code report:

- old target, candidate stable version/date, npm agreement, unchanged minimum;
- recorded old/new SHAs, tag recheck, six asset names/sizes/digests, explicitly
  separating published metadata, checksum-list agreement, and downloaded hashes;
- source-to-artifact evidence or blocker; complete diff size/coverage;
- high/medium findings with immutable links and actual app-server visibility;
- current-host OS/architecture, extraction, version, stdio and WebSocket results;
  list other platforms as untested unless optionally checked;
- proposed version-only edits versus capabilities, simplifications, follow-ups;
- tolerant-path versus justified version-selected implementation strategy and
  compatibility retirement thresholds.

Ask approval for proposed production scope only after stating blockers.
Approval does not turn missing verification into passing evidence. A requested
skill-only documentation PR may proceed while production changes stay gated.
Do not raise the minimum implicitly. If separately approved, remove obsolete
compatibility branches, tests and docs below the new floor rather than retaining
internal shims. Apply repository architecture-review rules only to approved
architecture-bearing production work, not this skill or a target-only edit.

## Phase 5 — Implement only after approval and passing gates

Require all six archive digests, source-to-artifact verification, successful
current-host install/version/transport probes, and user approval. Other
platforms do not require installation or launch probes; their untested status
does not block the complete six-asset target update.

1. Update `CodexRuntimeManifest.targetVersion`, six matching digests, and
   target-specific manifest comments. Strip GitHub's `sha256:` prefix: manifest
   `sha256` values must contain only the validated 64-character hexadecimal hash.
   Keep bundled version derived, minimum unchanged, and every archive
   format/layout/entrypoint intact.
2. Update target-specific test assertions, URLs and managed-path fixtures.
   Preserve historical behavior and compatibility-floor fixtures.
3. For approved capabilities, use typed wire models and plugin-local mapping.
   Test exact casing, correlation, ordering, unknown-field degradation and
   failure behavior. Preserve server-request responses and security policy.
   Prove Sesori admission-queue versus Codex queue ownership before replacing
   existing interruption, teardown, retry, or completion behavior.
4. For retained version-specific fields/branches read current product version
   from `bridge/app/pubspec.yaml` immediately before adding a concrete marker
   directly above the field/branch, never above its enclosing declaration:

   ```dart
   // COMPATIBILITY YYYY-MM-DD (vX.Y.Z): Codex <= <old> omits <behavior>; remove
   // this fallback when CodexRuntimeManifest.minPathVersion is raised to <new>.
   ```

   Replace all placeholders, use product version not library version, and give
   exact older behavior and retirement minimum. Prefer no branch when one
   tolerant path works.
5. Update `docs/regression/` for materially changed behavior or compatibility
   floors, not target-only tombstones. Update `docs/HARNESS_CAPABILITIES.md` for
   verified capability gaps or lifted limitations. Keep other harnesses' code
   untouched in this explicitly Codex-scoped audit.
6. Format changed Dart source; regenerate, never hand-edit generated outputs.

## Verification and delivery

For production changes run focused tests and analyze the owning package:

```bash
(cd bridge/sesori_plugin_codex && dart test && dart analyze --fatal-infos)
git status --short
git diff HEAD --check
git diff HEAD -- bridge/sesori_plugin_codex
```

Also inspect staged and untracked files explicitly; `git diff HEAD` omits
untracked files. Run shared foundation/runtime tests only if those primitives
changed. Do not repeat unchanged passing commands. For skill/docs-only changes,
validate frontmatter, referenced local paths, protocol examples, Markdown and
diff hygiene; do not run Dart/Flutter suites.

Keep the requested skill/documentation change in its own PR, separate from
runtime/protocol implementation. Commit and push when ready, using real multiline
Markdown via `--body-file`/stdin with `## Complexity`, `## What`, `## Why`,
`## Risk and test focus`, `## Expected result`, and `## Verification`. Use the
repository's implementation-complexity emoji prefix and series title convention
when applicable. State no user-visible/database impact for documentation-only
work. Load `monitor-pr` and start `pr_monitor` immediately after opening a PR;
never enable auto-merge or invent polling loops if monitoring is unavailable.

Final report: old/new target, unchanged minimum, six digest statuses,
adopted/deferred findings, provenance/probe blockers, tests, PR link, remaining
upstream/platform risks. An audit stopped at approval is not an implemented bump.
