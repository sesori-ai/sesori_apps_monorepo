# Sesori Agent Instructions

Slug: `sesori-system-note`.

## Goal

Give every agent session a short, invisible, Sesori-owned instruction through
each harness's own system-prompt or developer-instructions input. The first
instruction tells the agent how the Sesori app resolves the file paths it
writes.

## Why

The app opens file paths that agents write in chat (inline code such as
`lib/a.dart:12` and Markdown links) and resolves a relative one against the
session's directory
(`client/module_core/lib/src/foundation/models/file_reference/file_reference.dart`).
Agents often write paths relative to some other folder, for example a scratch
session pointing at a file in another repository, and the user gets "File not
found". In a 5-day sample of the owner's sessions, 46 of 89 relative links
missed for this reason.

## Decisions

Made by the owner, not reopened here:

- Use each harness's native system prompt or developer instructions. Never
  prepend text to the user's first prompt the way
  `bridge/sesori_bridge_foundation/lib/src/worktree_system_context.dart` does,
  and never touch the user's `AGENTS.md` or `CLAUDE.md`.
- One shared source of the text in the bridge, read by each plugin at its
  launch or start seam. One constant, no registry or configuration. A later
  Sesori instruction is another paragraph in the same constant.
- Keep the note brief.

Made while planning:

- The text lives in `sesori_bridge_foundation` as `sesoriAgentInstructions`,
  beside the worktree note. Plugins already depend on the package, and the
  Claude plugin already imports the worktree helpers from it.
- Codex replaces the user's `developer_instructions` from `config.toml` with a
  `developerInstructions` request field. The bridge therefore reads the
  effective value with `config/read` and sends it followed by the Sesori note,
  which is what Codex's own TUI does for its terminal-surface note
  (`codex-rs/tui/src/terminal_visualization_instructions.rs`).

## Note text

> The user reads this session in the Sesori app, which resolves relative file
> paths in your replies against this session's working directory. Refer to a
> file outside that directory by its absolute path.

## Current behavior

- Claude: `ClaudeLaunchSpec.arguments`
  (`bridge/sesori_plugin_claude/lib/src/api/claude_launch_spec.dart`) builds the
  argument vector for every process, new (`--session-id`) and resumed
  (`--resume`), including idle respawns. The CLI takes
  `--append-system-prompt <text>`. The system prompt is not a transcript
  message: `ClaudeTranscriptRecord` maps only `user`, `assistant` and known
  `system` subtypes and drops other record types, such as `api-request`, as
  `ClaudeUnknownRecord`.
- Claude CLI 2.1.318 records the system prompt once per conversation
  (`--system-prompt-snapshot`, on by default) and reuses that record on every
  later request and resume until the conversation is compacted. A session
  created before this change keeps its old prompt until its next compaction; a
  new session keeps the note for its whole life.
- Codex: `CodexAppServerApi.startThread` and `resumeThread`
  (`bridge/sesori_plugin_codex/lib/src/api/codex_app_server_api.dart`) send
  `thread/start` and `thread/resume`. Both accept `developerInstructions`
  (checked in the schemas of 0.166.0 and of 0.139.0, the plugin's PATH
  floor, which also has `config/read` with `developer_instructions`). The
  app-server maps it to a config override, does not persist it, and re-derives
  it on every resume, so the bridge sends it on both. A resume of an already
  running thread ignores it with a warning, which is harmless.
- Codex writes developer instructions to the rollout as `role: developer`
  messages. `CodexMessageRepository` keeps only `user` and `assistant` messages,
  so they never reach the transcript; no test covers that today. Live
  app-server items have no developer-message variant.
- `config/read {cwd}` returns the effective `developer_instructions`, project
  layers included. A resume has no directory at hand, so it reads without
  `cwd` (user and system layers only).

## Phase 1

Shared note, Claude and Codex.

### Step 1: raise the plan

`🌱 [sesori-system-note] Raise the Sesori agent instructions plan [step 1/3]`.
Plan files only.

### Step 2: shared note, Claude and Codex

`⚙️ [sesori-system-note] Give Claude and Codex sessions a hidden Sesori note [step 2/3]`.

- `sesori_bridge_foundation`: `sesoriAgentInstructions` constant, exported.
- Claude: `ClaudeLaunchSpec.arguments` adds
  `--append-system-prompt <sesoriAgentInstructions>` for new and resumed
  launches.
- Codex: `CodexAppServerApi.readConfig({cwd})` sends `config/read` and
  returns a Freezed response DTO; `CodexThreadRepository.readDeveloperInstructions`
  maps it to the user's value or null. `startThread` / `resumeThread` on both
  layers take a required `developerInstructions`. `CodexSessionService` owns
  the join (user text first, blank line, note) before each start and resume.
- Tests:
  - Claude launch spec: the flag and note appear on both launch variants.
  - Codex: `thread/start` (with `cwd`) and `thread/resume` (without) carry the
    joined text, with and without a configured user value.
  - Codex: a `role: developer` rollout message is absent from the mapped
    messages.
  - Existing Codex fakes answer `config/read`; method-order assertions add it.
- Docs: a `docs/HARNESS_CAPABILITIES.md` section listing every harness's
  status, and a `docs/regression/file-previews.md` bullet with its L1/L3
  coverage.

### Step 3: verify and retire

`🌱 [sesori-system-note] Record the verification and retire the plan [step 3/3]`.
Record the results below and move the plan to `.plan/completed/`.

## Verification

- L1: the step 2 unit tests; `dart analyze --fatal-infos` and `dart format`
  for the touched packages.
- L3, local bridge from the step 2 branch (`sesori-local-testing`): start a
  Claude session and a Codex session, ask each agent what Sesori told it about
  file paths, confirm it quotes the note, confirm the note is absent from the
  session's transcript in the bridge API, resume each once (Claude: idle
  respawn or bridge restart; Codex: bridge restart) and ask again, then delete
  the test sessions. Any app UI check runs only on a headless iOS simulator
  booted with `xcrun simctl boot`, on the device the local testing setup
  assigns.

## Complexity budget

New mutable state: none. One constant, one extra request before each Codex
thread start or resume. Not added: a registry, configuration, per-session
note variants, caching of `config/read`, or migration of the worktree note.

## Cleanup assessment

No relevant cleanup found. The worktree note stays a first-prompt prepend:
it is per-session and only applies when the bridge created a worktree, so it
cannot become a constant, and moving it is a later phase.

## Risks

- `config/read` runs before every Codex thread start and resume, so a failure
  there fails the start. Accepted: it is a core app-server request, present
  since before the PATH floor, and reads the same config the thread itself
  needs.

- A Codex user's project-level `developer_instructions` is replaced by the
  user-level value on a resume. Accepted: project-level developer instructions
  are rare, and the start of a thread uses the project value.
- `--system-prompt-snapshot` keeps old Claude sessions on their recorded
  prompt until compaction. Accepted: new sessions are what matter, and the
  note is advisory.

## Plan review

`architecture-plan-review` approved with three findings, all applied: the Api
returns the `config/read` DTO, the service owns the join, and support in Codex
0.139.0 is recorded above.

## Harness survey

Checked on 2026-11-07 against the installed binaries and the plugin code.

| Harness | Native input | Phase |
|---|---|---|
| Claude Code | `--append-system-prompt` on every launch | 1 |
| Codex | `developerInstructions` on `thread/start` and `thread/resume` | 1 |
| Pi (1.5.0), OMP (18.16.0) | `--append-system-prompt` on every launch, but a CLI value replaces the user's discovered `APPEND_SYSTEM.md` | 2 |
| Grok | ACP `session/new` `_meta.rules`, appended to the system prompt; behavior on load unverified | 3 |
| DeepSeek | None in the Sesori adapter yet; the harness has native system-prompt sections | 3 |
| OpenCode | v1: `system` on each prompt body. v2 (2.2.5): only an experimental per-session instruction-entry route | 4 |
| Copilot | `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`, extra instruction-file directories | 4 |
| Cursor, Hermes, Antigravity | None found | Not supported |

## Later phases

- Phase 2, Pi and OMP: pass the note with `--append-system-prompt`, together
  with the user's own `APPEND_SYSTEM.md`, which the flag would otherwise drop.
  Both harnesses pick that file with a project-trust rule the bridge would
  have to mirror, which is why they are not in phase 1.
- Phase 3, Grok and DeepSeek: the ACP base plugin gains a per-plugin `_meta`
  hook for `session/new`, `session/load` and `session/resume`. Grok sends the
  note as `rules`; the Sesori-owned DeepSeek adapter learns to register it as
  a system-prompt section.
- Phase 4, OpenCode and Copilot: OpenCode v1 sends `system` with each prompt
  and v2 needs the experimental instruction-entry route behind a version
  check; Copilot points its instruction-directory variable at a bridge-owned
  directory, once it is confirmed to add to the user's instructions rather
  than replace them.
- Cursor, Hermes and Antigravity expose no native input. They stay
  unsupported in `docs/HARNESS_CAPABILITIES.md` until upstream adds one.
