# Harness Runtime Refresh 2026-11

## Status and constraints

- Requested 2026-11-12: "update all harness target versions". Follows
  `.agents/skills/update-backend-runtimes/SKILL.md` and its
  `references/harnesses.md`, under the update-first policy: every harness moves
  to its current stable release, floors stay unchanged, and failed or
  unavailable checks go to follow-up instead of holding a target.
- Built on `main` after the Flutter 3.50.0 dependency update (#2498). The OpenCode
  models were regenerated again on that toolchain and did not change.
- No floor changes. Antigravity keeps its exact-pair policy.
- Owner merges every PR. Agents do not merge, tag or publish.

## Decisions

- **D1 (reused from 2026-10):** Claude Code follows the latest non-prerelease
  release, which is npm `latest`, not the npm `stable` dist-tag.
- **H1 (temporary hold, 2026-11-12):** OMP targets `18.18.8`, not the latest
  `18.19.0`. From `18.18.9` (upstream #18665), ACP `/session delete` starts a
  replacement session before deleting the old file and writes it to disk, so
  every Sesori deletion leaves an empty, untitled session in that project's list.
  A sandboxed probe confirmed it on `18.19.0`; `18.12.6` and `18.18.8` leave
  nothing. **Resolution:** move to the latest release once upstream stops
  persisting the replacement, or once the owner approves an OMP-side filter that
  hides it (see owner decisions). PATH `18.18.9`+ builds already show the
  leftover today.

## Harness inventory

| Harness | Old target | New target | Release identity | Floor (unchanged) | Hash evidence |
|---|---|---|---|---|---|
| OpenCode | 2.1.4 | **2.2.7** | tag v2.2.7 `fedc6f208aa2bd54c1019227214568083f6380ad`; npm `@opencode/cli` latest | PATH 1.14.0; v2 2.0.11 | 6 tarballs, npm integrity |
| Antigravity | 1.4.3 | **1.4.5** | registry commit `02b460362cfedf4d43b03df7aad6d79a353fe064` | exact pair | 6 zips, registry SHA-256 |
| Codex | 0.164.0 | **0.167.2** | `rust-v0.167.2` `ce21072c90d32c40af7a55b60b2fb35c84a43a6a`; npm agrees | 0.139.0 | 6 packages, SHA256SUMS + GitHub digests |
| Copilot | 1.0.103 | **1.0.109** | `a73dd6977439f238e66e5328a131ef783fee30d4`; npm agrees | 1.0.78 | 6 archives, SHA256SUMS + GitHub digests |
| Cursor | 2026.10.22-27dcf5f | **2026.11.11-b912975** | `cursor.com/install` | date 2026.09.23 | 4 archives, self-computed |
| Claude Code | 2.1.310 | **2.1.322** | `v2.1.322` `6e1e44f6433bfa17d198e932bff53373aa229eea`; npm `latest` (D1) | 2.1.221 | direct CLI |
| Hermes Agent | 0.22.5 | **0.23.1** | `v0.23.1` `3b421578588243f920886e6fe79a6faa87ea026e` | 0.20.0 | direct CLI |
| Pi | 1.4.0 | **1.5.2** | `v1.5.2` `b4afdddf44e059c67ccf5097e5317d913521b470`; npm latest | 0.99.0 | 6 archives, SHA256SUMS + GitHub digests |
| OMP | 18.12.6 | **18.18.8** (H1) | `v18.18.8` `679691a78141de0dd6ba1b7a5d5c1b1d7d967a63` | 17.2.13 | 8 binaries, SHA256SUMS + GitHub digests |
| Grok Build | 1.0.70 | **1.0.77** | `x.ai/cli/stable` | 1.0.5 | direct CLI (no published checksums) |
| DeepSeek | adapter 0.2.1 (dsh 0.2.1-rc.3) | **adapter 0.2.2** (dsh 0.2.2-rc.2, npm `next`) | `v0.2.2` `1d8cc61f3b5d531893c8759b5b6a289947b980fc` | 0.1.5 | 6 archives, checksums.txt + GitHub digests |

All 56 managed assets were downloaded and hashed independently (42 for the first
OMP candidate set, 8 for `18.18.8` and 6 for DeepSeek 0.2.2); every published checksum list, GitHub
digest, npm integrity value and registry hash agrees with the computed value.

## Findings that shape implementation

Required with the new targets (implemented in Steps 2 and 3):

- **OpenCode 2.2.7:** v2 models and the event manifest regenerated against
  v2.2.7 (no event change). The generator now dedupes union guards and picks a
  selected parent for shared union members. v2 `serve` reads `OPENCODE_PASSWORD`
  before `OPENCODE_SERVER_PASSWORD`, so an inherited value could override the
  bridge password: the spawn now strips both and stops re-inheriting the parent
  environment. v2 always requires auth, so `--opencode-no-password` is documented
  as v1-only (the code-side choice is an owner decision).
- **Codex 0.166.0+:** a thread started with a `modelProvider` other than the
  configured one rejects every turn (`modelProviderMismatch`, confirmed by a
  sandboxed probe). Sesori now sends only `model` on `thread/start`.
- **OMP 18.18.3+ forms:** the built-in `ask` tool sends HTML-form elicitations
  with `number`/`integer` fields. The shared ACP mapper declined the whole form,
  which aborted the turn. It now maps them to parsed free-text answers.
- **Hermes 0.22.6 to 0.23.1:** new failure copy (stream-lifetime cap,
  first-attempt rate limits, data-policy refusals, revised content-policy wording,
  automation-interrupted row) is classified. Discovery cleanup now accepts the
  real `No session '<id>'. Run: hermes sessions list to find the id.` message,
  which it had never matched.
- **Antigravity 1.4.5, Copilot, Cursor, Claude, Pi, Grok:** pin-only. Reference
  facts refreshed (Cursor Windows zips exist, Antigravity 1.4.5 adds JetBrains
  Air to the gate, Copilot cache isolation, Claude/Hermes/Grok source facts).

Not adopted; listed under owner decisions below.

## Steps

See `TRACKER.md` for status.

- **Step 1:** publish this plan.
- **Step 2:** OpenCode 2.2.7: pin, regenerated v2 models, generator fix,
  password environment fix, OpenCode docs.
- **Step 3 (stacked on Step 2):** the other nine targets with the Codex, ACP
  forms and Hermes fixes, the OMP hold, capability matrix, regression and
  reference updates.
- **Step 4:** DeepSeek consumer pin to adapter v0.2.2 once
  `sesori-deepseek-acp` #24 is merged and tag `v0.2.2` has published the six
  archives and `checksums.txt`: version, six hashes, the DeepSeek regression row.
  The adapter's protocol stays v2, so nothing else changes. Retire this plan in
  the same PR.

## Verification

Sandbox for native probes: macOS arm64, `sandbox-exec` with outbound network
denied (loopback allowed), reads under `/Users` denied, writes only under the
probe root, explicit environment, no credentials. Production managed installs
ran with network and normal reads, because they download.

| Check | Result |
|---|---|
| Production managed install (`installRuntime`, digest sentinel) | Passed: OpenCode, Antigravity (with initialize-only validation), Codex, Copilot, Cursor, Pi, OMP 18.19.0 and 18.18.8 |
| Version identity | Passed for all seven managed targets |
| OpenCode `serve` | Authenticated `/api/info` 2.2.7; unauthenticated reads refused, also when started without a password |
| Codex app-server | stdio and WebSocket initialize plus `thread/list` passed; provider-mismatch probe as above |
| Copilot, Cursor, OMP ACP initialize; Pi RPC `get_state` | Passed |
| DeepSeek adapter 0.2.2 (Step 4) | Six archives match `checksums.txt` and the GitHub digests; production install passed; sandboxed `check`, ACP initialize (harness 0.2.2-rc.2, protocol v2), `session/new` and `session/list` passed |
| OMP deletion probe | Leftover session on 18.19.0; none on 18.12.6 and 18.18.8 |
| Plugin packages (Flutter 3.50.0) | `dart analyze --fatal-infos` clean; tests pass: OpenCode 777, ACP 378, Antigravity 227, Claude 515, Codex 593, Copilot 18, Cursor 176, Grok 115, Hermes 60, OMP 80, Pi 366 |

Not run: any authenticated session (no credentials by policy), Claude, Hermes
and Grok native launches (direct CLIs; source and release evidence only),
non-macOS hosts, the Pi catalog probe, and a live OMP `ask` form roundtrip.

## Complexity budget

- Step 2: about 970 changed lines, of which 812 are generated models.
- Step 3: about 755 changed lines, mostly pins, tests and docs.
- Step 4: under 50 lines.

## Risks

- OpenCode regenerated unions: covered by model round-trip and API tests only.
- Codex users who relied on a per-session provider now get the configured one,
  which is what 0.166.0+ admits anyway.
- Number answers that do not parse become null; a required field then declines
  the form, as an unsupported field did before.

## Owner decisions (pending)

Grouped by harness; none is implemented.

- **OMP:** hide empty, untitled sessions in the OMP listing so the target can
  move past H1 (small to moderate; risk: hides a session created but never
  prompted); adopt `_omp/compaction/*` status (small to moderate); use the new
  tool-call `name` (small).
- **OpenCode:** reject or ignore `--opencode-no-password` on v2 (small); catalog
  refresh events for partial `agent.list` (moderate); native archive sync on
  2.1.0+ (moderate); `experimental.job.list` for stop-main-only (moderate); MCP
  OAuth paste (moderate).
- **Codex:** sub-agent `model`/`reasoningEffort` (40 to 80 lines);
  `serverRequest/resolved` for stale cards (small); provider rejection on resume
  (track).
- **Hermes:** duplicate `admitted_turn_failed` notice after every failed turn
  (30 to 60 lines in the shared ACP hook, needs a live check); 0.22.6+ config
  options for effort, service tier and edit policy (moderate); unclassified
  `launch_credentials_unavailable` and `pending_tool_result` copy and the
  content-refused history notice (small, needs the text).
- **Claude:** map `account_on_hold`, `cloud_credential_error` and
  `verification_required` assistant errors (10 to 20 lines).
- **Copilot:** probe with `--no-auto-update --version` so a cached newer package
  cannot answer for the pin (small; a local reproduction was inconclusive);
  `$/cancel_request` for withdrawn permissions (small).
- **Pi:** on Windows, wait for exit after closing stdin before signalling (small,
  needs a Windows host).
- **Cursor:** Windows managed install (moderate).
- **Grok:** probe 1.0.77's undocumented `x.ai/session/turns/list` paged history.
- **Antigravity:** switch to Google's `agy acp` (large, its own plan).
- **DeepSeek:** keep the upstream read-before-edit guard off, as harness
  0.2.2-rc.2 ships it (owner decision 2026-11-12; writes still need approval).
- **Tooling:** `terminal_color_validator.dart` treats `FORCE_COLOR=0` as on.

## Follow-ups

- OMP: rerun the deletion probe on each new release (H1).
- Track only: Antigravity 1.4.5 servers shrank; Codex ships
  `bin/codex-exec-server`; Cursor ACP does not exit on stdin close; OpenCode
  `/api/info` now reports `hostname`; Codex `thread/list` returns `readStates`;
  Pi idle cache warming bumps session modification times.
