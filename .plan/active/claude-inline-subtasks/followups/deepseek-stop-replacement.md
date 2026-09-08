# DeepSeek scoped-stop replacement

PR #1356 is closed without merge; its source is preserved at `58bbe71384a7d5f71b00cad3e573995e4fbb587a`.
Replacement step 4/5 merged as #1363 at `b13d197d51`; step 5/5 is implemented locally pending review and user-owned E2E.
Each replacement targets at most 1,500 changed lines including generated code, tests, fixtures, and documentation.
The adapter checkout is read-only evidence: v0.1.4 is already released, with no new native release planned.

## Step 4/5 — native contract and ordered input

Production changes stay in `bridge/sesori_plugin_deepseek/`:

- `lib/src/api/models/deepseek_protocol_dto.dart`: typed stop session/child union, stop response, input-cancel request,
  and empty acknowledgment. Regenerate `.freezed.dart` and `.g.dart` from this source.
- `lib/src/api/deepseek_acp_api.dart`: strict native payload parsing/validation, not stop-policy orchestration.
- `lib/src/deepseek_approval_registry.dart`: `DeepSeekApprovalRegistry.handleExtensionRequest` consumes
  `deepseek/input/cancel` on the existing ordered request path, cancels only that session's pending input,
  then ACKs `{}`.
- `lib/src/repositories/deepseek_session_repository.dart`: map validated initialize metadata to `SemanticVersion`.
- `lib/src/services/deepseek_session_service.dart`: enforce the injected minimum; `lib/src/deepseek_plugin_impl.dart`
  delegates initialize validation to this existing service. No new service or registry is needed.
- `lib/src/runtime/deepseek_plugin_descriptor.dart` and `deepseek_runtime_manifest.dart`: require/target 0.1.4 and pin
  its six verified archive names/digests. Automatic runtime installation/upgrades remain separate work.
- `test/fixtures/protocol/scoped-stop/v1/`: byte-identical native schema/valid/invalid corpus plus source manifest;
  existing `protocol/v1/` and `protocol/v2/` bytes remain unchanged.

Native input flows through `AcpStdioClient.serverRequests -> AcpPlugin._handleAgentServerRequest ->
DeepSeekApprovalRegistry -> DeepSeekAcpApi` parsing and the existing pending-input owner. The same prompt-write buffer
orders old input, cancellation, and later input, including reused question IDs.
This makes the 0.1.4 pin safe independently.
`deepseek/session/stop` is outbound, not unsolicited: this slice has no production caller for it. Current
`supportsScopedStop`/direct-parent cancellation, bridge/public contracts, and clients remain unchanged.

## Step 5/5 — one complete ACP-owned stop

Public model source: `shared/sesori_shared/lib/src/models/sesori/abort_session_request.dart` plus generated siblings:
add request `useAtomicStop` and response `subAgentsHandled`, each defaulting false only at the public wire boundary.
Use dated compatibility comments with the current product version. Internal APIs take required semantics.

Bridge flow retains its current owners:

1. `bridge/app/lib/src/routing/abort_session_handler.dart` parses the opt-in and serializes the typed ACK/409 result.
2. Existing `services/session_abort_service.dart` retains its `SessionOperationDispatcher` family operation, streams,
   and injection. Actual `workKept` still decides completion-push suppression.
3. `repositories/session_repository.dart` resolves the named binding and recursive persisted descendants once before
   calling the plugin. Pass backend `knownSubAgentSessionIds` and opt-in;
   `repositories/models/session_abort_result.dart`
   carries one acknowledgment Boolean, not residual coverage models.
   These paths are under `bridge/app/lib/src/`.
4. `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart` and `models/plugin_abort.dart` declare those required
   inputs and accepted-result ACK. Update ACP/Claude/Codex/OpenCode/Pi implementations and fakes together, without
   changing unrelated harness policy. Non-authoritative results conservatively acknowledge false.
5. `bridge/sesori_plugin_acp/lib/src/acp_plugin.dart` owns scope selection, request-time queue cleanup, and dispatch.
   Reuse `_residentSessions` plus `repositories/trackers/acp_child_session_tracker.dart` ancestry; add only a cohesive
   tracker query if needed. A sealed session-vs-direct-parent/child target in `lib/src/models/acp_scoped_stop.dart`
   is exported through `lib/acp_plugin.dart`; generic ACP never imports a DeepSeek DTO.
6. The DeepSeek hook follows existing `deepseek_plugin_impl.dart -> services/deepseek_session_service.dart ->
   repositories/deepseek_session_repository.dart -> api/deepseek_acp_api.dart` under its `lib/src/`.
   Repository maps the ACP target to the native DTO and response to `workKept`; API sends `deepseek/session/stop`.
   Preserve original causes.

Capture every independently resident descendant root, including nested roots and those whose own prompt settled while
background descendants remain. Do not substitute pending/in-flight counts for residency. For a nonresident named
retained child use exact direct-parent authority. Clear queued-only children locally without invented native targets.
Partition ownership before `keep` checks: foreground work beneath an independent root does not invalidate the requested
root's main-only stop. `confirm` and unsupported `keep` remain side-effect-free.
Construct all native STOP futures before awaiting any; await all, OR successful `workKept` values,
and report any failure rather than unfinished work to the UI.
No response-time cleanup, synthetic lifecycle settlement, new lock, registry, timer, epoch, or stop-lifetime state.

Client flow stays in `client/module_core/lib/src/api/session_api.dart`, `repositories/session_repository.dart`, and
`cubits/session_detail/session_detail_cubit.dart`: API opts in and parses the response; repository maps ACK to
`ApiResponse<bool>` while retaining typed failures. Cubit skips descendant fanout after true ACK. Otherwise prefer
refreshed visible busy statuses, falling back to a request-local snapshot during reload; `keep` never fans out.
Do not port #1356's client `SessionAbortService`, DI, residual-ID contracts, or service-only tests.
The existing **bridge** abort service stays. No phone/desktop/shared-UI production composition change is planned.

Public baseline is v1.8.3 (`d962a1c50910fe028d2fe6c596a5325d61579d45`), not internal/prerelease builds:

- New client/new bridge: `useAtomicStop: true`, complete ACP handling, `subAgentsHandled: true`, no client fanout.
- Released client/new bridge: omitted opt-in preserves named-session cancellation plus the old client's own fanout.
- New client/released bridge: ignored opt-in and `{}` response mean false ACK and legacy fallback; no version polling.

## Evidence and completion gates

Step 4 tests cover native conformance/hash identity, version/digests, malformed-cancel isolation, and buffered reused-ID
ordering. Step 5 covers delayed admission, settled/nested independent roots, retained children, queued-only/pending
loads, keep/confirm, partial failure, frames before responses, later-work survival, reset/close, mixed public versions,
and legacy reload fallback. Run relevant bridge/client and impacted mobile title-hydration/split-pane tests,
not the old DI fix.
Final phone/desktop feature E2E remains user-owned and separate from package/CI checks. Finish DeepSeek before Codex.
