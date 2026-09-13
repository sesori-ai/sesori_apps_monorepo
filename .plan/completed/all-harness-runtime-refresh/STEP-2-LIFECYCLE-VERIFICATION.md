# Step 2 — Supplemental lifecycle verification

Date: 2026-09-12. Follow-up to
[PR #1455](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1455).

## Why this follow-up exists

The first Step 2 report established startup, integrity, installation, and
focused package checks, but did not establish all Pi/Claude lifecycle gates
named in the plan. Review caught that gap. The owner chose to complete the
additional checks, not weaken the requirements. PR #1455 merged while those
review threads were still open; this accepted follow-up closes that evidence
gap after merge. The merge itself was not a gate waiver.

Both candidates now pass the additional gates below on **macOS ARM64**. The
actual candidate runtimes ran against controlled loopback model responses;
no Pi RPC or Claude control/stream events were fabricated. No real credentials,
live account/profile, external provider network, or production source changes
were needed. This is not a live-provider authentication or model-quality claim.

## Pi 0.85.1

Used the verified installed candidate through
`PiPlugin -> PiSessionService -> PiSessionProcessRepository -> PiRpcClient`.
Public production calls covered catalog/options refresh, session creation,
prompting, the native `compact` command, `abortSession`, history, and shutdown.

| Required observation | Result |
|---|---|
| Native settlement | `agent_start -> agent_end -> agent_settled`; production consumes settlement, then emits idle status and `BridgeSseSessionIdle` |
| Manual compaction entry | Native `compaction_start` and a production running `compact` tool part after ten synthetic history messages |
| Abort during held provider request | Native `compaction_end(aborted: true, willRetry: false)`; no successful-compaction event |
| Production cleanup ordering | Running compact part -> compaction message removal -> idle status -> session idle, at event indexes 87–90 |
| Post-abort state/history | Idle work/session state; no compact tool entry retained |
| Reuse | A follow-up on the same production session ID launches the normal resumed-session process and settles successfully |
| Automatic teardown | Production idle reap and shutdown observed all four owned candidate exits; fixture also stopped and exited |

Disposable project compaction retention was reduced so the small synthetic
history entered real compaction. The held fixture response was released after
abort was requested; native cancellation, not a fabricated provider abort
event, determined the outcome. Successful compaction output, automatic retry,
and real-provider behavior were not tested.

`PiLaunchSpec` already supplies `--approve` for its RPC launches. The probe used
that existing production project-trust policy; this refresh adds no launch
flag or permission-policy change.

## Claude Code 2.1.269

The real candidate used the `ClaudeLaunchSpec` launch vector under normal
manual permission policy. Captured native frames were parsed with production
`ClaudeStreamMessage` types. `ClaudeEventDispatcher.mapPromptReplay`,
`ClaudeTranscriptApi`, `ClaudeTranscriptCatalogRepository`, and
`ClaudeHistoryMapper` processed the actual replay/history evidence. This does
not claim a full `ClaudeSessionService`/approval-registry integration run.

| Required observation | Result |
|---|---|
| Stdio permission allow | Correlated native `can_use_tool`; allowed harmless owned-project action created its marker and completed |
| Stdio permission deny | Correlated denial; one permission denial reported and denied marker absent |
| Resident reuse | Two completed turns on the same candidate process |
| Persisted resume/history | Seed turn persisted; `--resume` continued the session; native records and production history both ordered user/assistant/user/assistant |
| Replay/correlation | Current-user replay echo preceded resumed assistant output; production replay mapping preserved prompt correlation |
| Active interrupt | Partial output preceded the request; correlated interrupt ACK preceded distinct terminal `error_during_execution` / `aborted_streaming` |
| No late admission | No late permission request or action marker after interrupt |
| Reuse after interrupt | Normal resumed-session follow-up completed successfully |
| Teardown | All owned candidate/fixture handles reaped; final owned-process scan empty |

The replay echo is the current submitted prompt, not a claim that old transcript
history is replayed over stdio. Persisted history was checked separately through
the native transcript and production history mapper. The resumed provider
request contained three messages versus one for the seed request.

## Bounds and evidence

Fresh synthetic profiles/projects, allowlisted environments, and restrictive
macOS sandboxes prevented access to user data and external network. Candidate
network access was confined to the owned loopback fixture. Trusted controllers
outside the candidate sandbox owned process groups, bounded operations, and
performed automatic cleanup; no denied in-sandbox presence check was used as
proof of exit.

All observed scenarios completed within the 120-second controller budget.
Pi's production/native event sequence occupied about 1.55 seconds, followed by
about 2.32 seconds of automatic cleanup; Claude scenarios took approximately
0.97, 1.17, and 1.41 seconds. Deadline-expiry fault injection was not tested;
Pi's outer `Future.timeout` is a wait budget, not cancellation of its underlying
future. The reported passing evidence includes actual process exits and cleanup,
not an inference from that timeout.

Local authoritative artifacts, relative to `.dart_tool/runtime-refresh-validation/`:

- `pi/LIFECYCLE-REPORT.md`
- `pi/lifecycle/run-1789233459476/{result,production-events,native-events}.json`
- `pi/lifecycle/lifecycle_driver.dart` and `fixture_server.dart`
- `claude/LIFECYCLE-REPORT.md`
- `claude/lifecycle/runs/gate-validation.json`
- `claude/lifecycle/runs/{permission,replay,interrupt}/summary.json`
- `claude/lifecycle/run_lifecycle.py`, `fixture_server.py`, and `production_seam_probe.dart`

The worktree advanced from `fd2d4d8` to merged `ba3264ea` during verification;
Pi/Claude and their relevant runtime/shared/toolchain inputs did not change.
Earlier successful asset/install checks and the 349 post-pin tests were not
rerun. Codex/OMP blockers and all later target/feature gates remain unchanged.
